{ CrossDragDropWin

  The Win32 half of CrossDragDrop: OLE drag and drop.  A source runs
  DoDragDrop with a shell data object that holds Unicode text and an HDROP
  file list, and a snapshot of the control as the drag image.  A target is
  an IDropTarget registered on the control's window.  The fade and the
  highlight are drawn after the window's own paint, through a window
  subclass.  The unit is empty on other widgetsets.

  Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.
}
unit CrossDragDropWin;

{$mode objfpc}{$H+}

interface

implementation

{$IFDEF LCLWIN32}

uses
  Windows, ActiveX, ShlObj, ShellAPI, CommCtrl, Classes, SysUtils, Types,
  Controls, Forms, Graphics, URIParser, CrossDragDropHelpers, CrossDragDropData;

const
  CLSID_DragDropHelper: TGUID = '{4657278A-411B-11D2-839A-00C04FD918D0}';

type
  // Not in the FPC shell units.
  IDragSourceHelper = interface(IUnknown)
    ['{DE5BF786-477A-11D2-839D-00C04FD918D0}']
    function InitializeFromBitmap(pshdi: PSHDRAGIMAGE; pDataObject: IDataObject): HResult; stdcall;
    function InitializeFromWindow(hwnd: HWND; ppt: PPoint; pDataObject: IDataObject): HResult; stdcall;
  end;

  IDropTargetHelper = interface(IUnknown)
    ['{4657278B-411B-11D2-839A-00C04FD918D0}']
    function DragEnter(hwndTarget: HWND; pDataObject: IDataObject; ppt: PPoint; dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function DragOver(ppt: PPoint; dwEffect: DWORD): HResult; stdcall;
    function Drop(pDataObject: IDataObject; ppt: PPoint; dwEffect: DWORD): HResult; stdcall;
    function Show(fShow: BOOL): HResult; stdcall;
  end;

  { TWinHook

    The control's window, its subclass and the effect drawn over it.  Owned
    by the source or target below.  When the window is destroyed the
    helper lets go and attaches again to the next one. }

  TWinHook = class
  private
    FOwner: TCrossDragDropNative;
    FWnd: HWND;
    FDead, FEffect, FRegistered: boolean;
    procedure Paint;
    procedure Gone;
    procedure LostLater(Data: PtrInt);
  public
    constructor Create(AOwner: TCrossDragDropNative);
    destructor Destroy; override;
    procedure SetEffect(Visible: boolean);
    // The control's area in the window's client coordinates.
    function Area: TRect;
    // A copy of the control as it looks now, for the drag image.
    function Snapshot(out Image: TSHDragImage): boolean;
    property Wnd: HWND read FWnd;
    property Dead: boolean read FDead;
    // True while an IDropTarget is registered; revoked before the window goes.
    property Registered: boolean read FRegistered write FRegistered;
  end;

  { TWinDropSource: Escape cancels, releasing the button drops. }

  TWinDropSource = class(TInterfacedObject, IDropSource)
  private
    FEscaped: boolean;
  public
    function QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: DWORD): HResult; stdcall;
    function GiveFeedback(dwEffect: DWORD): HResult; stdcall;
    property Escaped: boolean read FEscaped;
  end;

  { TWinSource }

  TWinSource = class(TCrossDragDropNativeSource)
  private
    FHook: TWinHook;
    function Source: TCrossDragDropSource;
    function MakeData: IDataObject;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    function Start: boolean; override;
    function PastThreshold(const From, Current: TPoint): boolean; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

  TWinTarget = class;

  { TWinDropTarget

    The COM object OLE calls.  OLE may hold it a little longer than the
    target lives, so it reaches the target only through FOwner, which the
    target clears when it goes. }

  TWinDropTarget = class(TInterfacedObject, IDropTarget)
  private
    FOwner: TWinTarget;
    FData: IDataObject;
    FImages: IDropTargetHelper;
    function Decide(const pt: TPoint; var dwEffect: DWORD; out Chosen: TCrossDragDropFormat): boolean;
  public
    function DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
  end;

  { TWinTarget }

  TWinTarget = class(TCrossDragDropNativeTarget)
  private
    FHook: TWinHook;
    FDropTarget: TWinDropTarget;
    FDropTargetRef: IDropTarget;
    function Target: TCrossDragDropTarget;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

var
  // Sources alive right now; DoDragDrop runs a loop of its own, so Start
  // checks afterwards that its own object was not freed meanwhile.
  LiveSources: TFPList;

// The shell's data object stores any format given to SetData, which the
// drag image helper relies on.
function SHCreateDataObject(pidlFolder: PItemIDList; cidl: UINT; apidl: Pointer; pdtInner: IDataObject;
  const riid: TGUID; out ppv): HResult; stdcall; external 'shell32.dll' Name 'SHCreateDataObject';
function GdiAlphaBlend(hdcDest: HDC; xDest, yDest, wDest, hDest: integer; hdcSrc: HDC;
  xSrc, ySrc, wSrc, hSrc: integer; ftn: TBlendFunction): BOOL; stdcall; external 'gdi32.dll' Name 'GdiAlphaBlend';

function Subclass(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM; Id: UINT_PTR; Ref: DWORD_PTR): LRESULT; stdcall;
var
  Hook: TWinHook;
begin
  Hook := TWinHook(Ref);
  case Msg of
    WM_PAINT:
    begin
      Result := DefSubclassProc(Wnd, Msg, WParam, LParam);
      if Hook.FEffect then
        try
          Hook.Paint;
        except
          Application.HandleException(nil);
        end;
      Exit;
    end;
    WM_DESTROY:
      if Hook.FRegistered then
      begin
        RevokeDragDrop(Wnd);
        Hook.FRegistered := False;
      end;
    WM_NCDESTROY: Hook.Gone;
  end;
  Result := DefSubclassProc(Wnd, Msg, WParam, LParam);
end;

function FormatEtc(Format: word): TFormatEtc;
begin
  Result.CfFormat := Format;
  Result.Ptd := nil;
  Result.dwAspect := DVASPECT_CONTENT;
  Result.lindex := -1;
  Result.tymed := TYMED_HGLOBAL;
end;

function HasFormat(Data: IDataObject; Format: word): boolean;
var
  Etc: TFormatEtc;
begin
  Etc := FormatEtc(Format);
  Result := Data.QueryGetData(Etc) = S_OK;
end;

// Hands a block of memory to the data object, which frees it.
function PutData(Data: IDataObject; Format: word; const Bytes; Size: PtrUInt): boolean;
var
  Etc: TFormatEtc;
  Medium: TStgMedium;
  Memory: HGLOBAL;
begin
  Result := False;
  Memory := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, Size);
  if Memory = 0 then Exit;
  Move(Bytes, GlobalLock(Memory)^, Size);
  GlobalUnlock(Memory);
  Etc := FormatEtc(Format);
  FillChar(Medium, SizeOf(Medium), 0);
  Medium.Tymed := TYMED_HGLOBAL;
  Medium.HGLOBAL := Memory;
  Result := Data.SetData(Etc, Medium, True) = S_OK;
  if not Result then GlobalFree(Memory);
end;

// Unicode text, or the ANSI text that older programs offer.
function ReadText(Data: IDataObject; out Text: string): boolean;
var
  Etc: TFormatEtc;
  Medium: TStgMedium;
  Memory: Pointer;
  Wide: WideString;
  Ansi: RawByteString;
begin
  Text := '';
  Etc := FormatEtc(CF_UNICODETEXT);
  if Data.GetData(Etc, Medium) <> S_OK then
  begin
    Etc := FormatEtc(CF_TEXT);
    if Data.GetData(Etc, Medium) <> S_OK then Exit(False);
  end;
  try
    Memory := GlobalLock(Medium.HGLOBAL);
    Result := Memory <> nil;
    if not Result then Exit;
    if Etc.CfFormat = CF_UNICODETEXT then
    begin
      SetString(Wide, PWideChar(Memory), StrLen(PWideChar(Memory)));
      Text := UTF8Encode(Wide);
    end
    else
    begin
      SetString(Ansi, PAnsiChar(Memory), StrLen(PAnsiChar(Memory)));
      SetCodePage(Ansi, CP_ACP, False);
      SetCodePage(Ansi, CP_UTF8, True);
      Text := Ansi;
    end;
    GlobalUnlock(Medium.HGLOBAL);
  finally
    ReleaseStgMedium(@Medium);
  end;
end;

// The dropped paths as a URI list, which DeliverURIs checks and decodes.
function ReadFiles(Data: IDataObject; out URIs: string): boolean;
var
  Etc: TFormatEtc;
  Medium: TStgMedium;
  Drop: HDROP;
  I, Count: integer;
  Size: UINT;
  Path: WideString;
begin
  URIs := '';
  Etc := FormatEtc(CF_HDROP);
  Result := Data.GetData(Etc, Medium) = S_OK;
  if not Result then Exit;
  try
    Drop := HDROP(Medium.HGLOBAL);
    Count := DragQueryFileW(Drop, $FFFFFFFF, nil, 0);
    for I := 0 to Count - 1 do
    begin
      Size := DragQueryFileW(Drop, I, nil, 0);
      SetLength(Path, Size);
      DragQueryFileW(Drop, I, PWideChar(Path), Size + 1);
      URIs := URIs + FilenameToURI(UTF8Encode(Path)) + #13#10;
    end;
  finally
    ReleaseStgMedium(@Medium);
  end;
end;

{ TWinHook }

constructor TWinHook.Create(AOwner: TCrossDragDropNative);
begin
  inherited Create;
  FOwner := AOwner;
  FWnd := AOwner.Helper.NativeControl.Handle;
  if not SetWindowSubclass(FWnd, @Subclass, UINT_PTR(Self), DWORD_PTR(Self)) then
    raise ECrossDragDrop.Create('The window of ' + AOwner.Helper.Control.Name + ' could not be hooked.');
end;

destructor TWinHook.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if not FDead then
  begin
    RemoveWindowSubclass(FWnd, @Subclass, UINT_PTR(Self));
    if FEffect then InvalidateRect(FWnd, nil, True);
  end;
  inherited Destroy;
end;

procedure TWinHook.Gone;
begin
  RemoveWindowSubclass(FWnd, @Subclass, UINT_PTR(Self));
  FDead := True;
  Application.QueueAsyncCall(@LostLater, 0);
end;

procedure TWinHook.LostLater(Data: PtrInt);
begin
  // Frees the owner and this hook.
  FOwner.Helper.NativeLost;
end;

function TWinHook.Area: TRect;
var
  P: TPoint;
  Control: TControl;
begin
  Control := FOwner.Helper.Control;
  if Control is TWinControl then
    Windows.GetClientRect(FWnd, Result)
  else
  begin
    // The LCL may place a parent's client area inside its window, so go
    // through the screen.
    P := Control.ClientToScreen(Point(0, 0));
    Windows.ScreenToClient(FWnd, P);
    Result := Bounds(P.X, P.Y, Control.Width, Control.Height);
  end;
end;

procedure TWinHook.SetEffect(Visible: boolean);
var
  R: TRect;
begin
  if (FEffect = Visible) or FDead then Exit;
  FEffect := Visible;
  R := Area;
  RedrawWindow(FWnd, @R, 0, RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN or RDW_UPDATENOW);
end;

procedure TWinHook.Paint;
var
  DC, Mem: HDC;
  Bitmap, OldBitmap: HBITMAP;
  Pen, OldPen: HPEN;
  OldBrush: HBRUSH;
  Blend: TBlendFunction;
  R: TRect;
  Fill, Line: TColor;
  Alpha: byte;
begin
  R := Area;
  if FOwner is TWinSource then
  begin
    // Lifted away: the control fades under the window color, a dotted
    // line keeps its outline.
    Fill := ColorToRGB(clForm);
    Alpha := 153;
    Line := ColorToRGB(clGrayText);
    Pen := CreatePen(PS_DOT, 1, Line);
  end
  else
  begin
    Fill := ColorToRGB(TCrossDragDropTarget(FOwner.Helper).HighlightColor);
    Alpha := 38;
    Pen := CreatePen(PS_INSIDEFRAME, 2, Fill);
  end;
  DC := GetDC(FWnd);
  try
    Mem := CreateCompatibleDC(DC);
    Bitmap := CreateCompatibleBitmap(DC, 1, 1);
    OldBitmap := SelectObject(Mem, Bitmap);
    SetPixel(Mem, 0, 0, Fill);
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := Alpha;
    Blend.AlphaFormat := 0;
    GdiAlphaBlend(DC, R.Left, R.Top, R.Width, R.Height, Mem, 0, 0, 1, 1, Blend);
    SelectObject(Mem, OldBitmap);
    DeleteObject(Bitmap);
    DeleteDC(Mem);
    OldPen := SelectObject(DC, Pen);
    OldBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));
    Windows.Rectangle(DC, R.Left, R.Top, R.Right, R.Bottom);
    SelectObject(DC, OldBrush);
    SelectObject(DC, OldPen);
  finally
    ReleaseDC(FWnd, DC);
    DeleteObject(Pen);
  end;
end;

function TWinHook.Snapshot(out Image: TSHDragImage): boolean;
var
  Info: TBitmapInfo;
  Bits: PByte;
  DC, Mem: HDC;
  Old: HGDIOBJ;
  R: TRect;
  P: TPoint;
  I: integer;
begin
  Result := False;
  R := Area;
  if (R.Width <= 0) or (R.Height <= 0) then Exit;
  FillChar(Info, SizeOf(Info), 0);
  Info.bmiHeader.biSize := SizeOf(Info.bmiHeader);
  Info.bmiHeader.biWidth := R.Width;
  Info.bmiHeader.biHeight := -R.Height;
  Info.bmiHeader.biPlanes := 1;
  Info.bmiHeader.biBitCount := 32;
  Info.bmiHeader.biCompression := BI_RGB;
  Image.hbmpDragImage := CreateDIBSection(0, Info, DIB_RGB_COLORS, Pointer(Bits), 0, 0);
  if Image.hbmpDragImage = 0 then Exit;
  DC := GetDC(FWnd);
  Mem := CreateCompatibleDC(DC);
  Old := SelectObject(Mem, Image.hbmpDragImage);
  BitBlt(Mem, 0, 0, R.Width, R.Height, DC, R.Left, R.Top, SRCCOPY);
  SelectObject(Mem, Old);
  DeleteDC(Mem);
  ReleaseDC(FWnd, DC);
  GdiFlush;
  // The copy has no alpha of its own; make every pixel opaque.
  for I := 0 to R.Width * R.Height - 1 do Bits[I * 4 + 3] := 255;
  Image.sizeDragImage.cx := R.Width;
  Image.sizeDragImage.cy := R.Height;
  P := TCrossDragDropSource(FOwner.Helper).PressPoint;
  Image.ptOffset.X := P.X - FOwner.Helper.ControlRect.Left;
  Image.ptOffset.Y := P.Y - FOwner.Helper.ControlRect.Top;
  if (Image.ptOffset.X < 0) or (Image.ptOffset.X >= R.Width) then Image.ptOffset.X := R.Width div 2;
  if (Image.ptOffset.Y < 0) or (Image.ptOffset.Y >= R.Height) then Image.ptOffset.Y := R.Height div 2;
  Image.crColorKey := CLR_NONE;
  Result := True;
end;

{ TWinDropSource }

function TWinDropSource.QueryContinueDrag(fEscapePressed: BOOL; grfKeyState: DWORD): HResult; stdcall;
begin
  if fEscapePressed then
  begin
    FEscaped := True;
    Result := DRAGDROP_S_CANCEL;
  end
  else if grfKeyState and MK_LBUTTON = 0 then
    Result := DRAGDROP_S_DROP
  else
    Result := S_OK;
end;

function TWinDropSource.GiveFeedback(dwEffect: DWORD): HResult; stdcall;
begin
  Result := DRAGDROP_S_USEDEFAULTCURSORS;
end;

{ TWinSource }

constructor TWinSource.Create(AHelper: TCrossDragDropHelper);
begin
  inherited Create(AHelper);
  FHook := TWinHook.Create(Self);
  LiveSources.Add(Self);
end;

destructor TWinSource.Destroy;
begin
  LiveSources.Remove(Self);
  FHook.Free;
  inherited Destroy;
end;

function TWinSource.Source: TCrossDragDropSource;
begin
  Result := TCrossDragDropSource(Helper);
end;

function TWinSource.PastThreshold(const From, Current: TPoint): boolean;
begin
  Result := (Abs(Current.X - From.X) >= GetSystemMetrics(SM_CXDRAG)) or
    (Abs(Current.Y - From.Y) >= GetSystemMetrics(SM_CYDRAG));
end;

procedure TWinSource.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

function TWinSource.MakeData: IDataObject;
var
  Wide: WideString;
  Files: TStringList;
  Error: string;
  Header: TDropFiles;
  List: WideString;
  Block: array of byte;
  I: integer;
begin
  Result := nil;
  if SHCreateDataObject(nil, 0, nil, nil, IDataObject, Result) <> S_OK then Exit(nil);
  if Source.HasText then
  begin
    Wide := UTF8Decode(Source.Text);
    if not PutData(Result, CF_UNICODETEXT, PWideChar(Wide)^, (Length(Wide) + 1) * SizeOf(WideChar)) then Exit(nil);
  end;
  if Source.HasFiles then
  begin
    Files := TStringList.Create;
    try
      if not CrossDragDropURIsToFiles(Source.URIs, Files, Error) then Exit(nil);
      // DROPFILES, then each path ending in a null, then one more null.
      List := '';
      for I := 0 to Files.Count - 1 do List := List + UTF8Decode(Files[I]) + #0;
      List := List + #0;
    finally
      Files.Free;
    end;
    FillChar(Header, SizeOf(Header), 0);
    Header.pFiles := SizeOf(Header);
    Header.fWide := True;
    SetLength(Block, SizeOf(Header) + Length(List) * SizeOf(WideChar));
    Move(Header, Block[0], SizeOf(Header));
    Move(PWideChar(List)^, Block[SizeOf(Header)], Length(List) * SizeOf(WideChar));
    if not PutData(Result, CF_HDROP, Block[0], Length(Block)) then Exit(nil);
  end;
end;

function TWinSource.Start: boolean;
var
  Data: IDataObject;
  Feedback: TWinDropSource;
  DropSource: IDropSource;
  Images: IDragSourceHelper;
  Image: TSHDragImage;
  Effect: DWORD;
  Res: HResult;
  Me: TWinSource;
  Outcome: TCrossDragDropOutcome;
begin
  Result := False;
  // DoDragDrop ends at once without the button down.
  if FHook.Dead or (GetKeyState(VK_LBUTTON) >= 0) then Exit;
  Data := MakeData;
  if Data = nil then Exit;
  // The snapshot is taken before the fade is drawn. The helper owns the
  // bitmap once it accepts it.
  if (CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER, IDragSourceHelper, Images) = S_OK) and
    FHook.Snapshot(Image) then
    if Images.InitializeFromBitmap(@Image, Data) <> S_OK then DeleteObject(Image.hbmpDragImage);
  Feedback := TWinDropSource.Create;
  DropSource := Feedback;
  // DoDragDrop takes the mouse capture; a button pressed by this press
  // would otherwise stay down.
  ReleaseCapture;
  Me := Self;
  Source.NativeBegan;
  Effect := DROPEFFECT_NONE;
  Res := DoDragDrop(Data, DropSource, DROPEFFECT_COPY, @Effect);
  Result := True;
  if LiveSources.IndexOf(Me) < 0 then Exit;
  if (Res = DRAGDROP_S_DROP) and (Effect and DROPEFFECT_COPY <> 0) then Outcome := cdoDropped
  else if Feedback.Escaped then Outcome := cdoCanceled
  else if (Res = DRAGDROP_S_DROP) or (Res = DRAGDROP_S_CANCEL) then Outcome := cdoRejected
  else
    Outcome := cdoFailed;
  Source.NativeEnded(Outcome);
end;

{ TWinDropTarget }

function TWinDropTarget.Decide(const pt: TPoint; var dwEffect: DWORD; out Chosen: TCrossDragDropFormat): boolean;
var
  Offered: TCrossDragDropFormats;
  P: TPoint;
begin
  Result := False;
  Chosen := cdfText;
  if (FOwner <> nil) and (FData <> nil) and not FOwner.FHook.Dead then
  begin
    Offered := [];
    if HasFormat(FData, CF_UNICODETEXT) or HasFormat(FData, CF_TEXT) then Include(Offered, cdfText);
    if HasFormat(FData, CF_HDROP) then Include(Offered, cdfFiles);
    P := FOwner.Helper.NativeControl.ScreenToClient(pt);
    Result := FOwner.Target.Accepts(Offered, dwEffect and DROPEFFECT_COPY <> 0, P.X, P.Y, Chosen);
  end;
  if Result then dwEffect := DROPEFFECT_COPY
  else
    dwEffect := DROPEFFECT_NONE;
end;

function TWinDropTarget.DragEnter(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
var
  Chosen: TCrossDragDropFormat;
begin
  Result := S_OK;
  try
    FData := dataObj;
    Decide(pt, dwEffect, Chosen);
    if (FOwner <> nil) and (CoCreateInstance(CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER,
      IDropTargetHelper, FImages) = S_OK) then
      FImages.DragEnter(FOwner.FHook.Wnd, dataObj, @pt, dwEffect);
  except
    dwEffect := DROPEFFECT_NONE;
    Application.HandleException(nil);
  end;
end;

function TWinDropTarget.DragOver(grfKeyState: DWORD; pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
var
  Chosen: TCrossDragDropFormat;
begin
  Result := S_OK;
  try
    Decide(pt, dwEffect, Chosen);
    if FImages <> nil then FImages.DragOver(@pt, dwEffect);
  except
    dwEffect := DROPEFFECT_NONE;
    Application.HandleException(nil);
  end;
end;

function TWinDropTarget.DragLeave: HResult; stdcall;
begin
  Result := S_OK;
  try
    if FImages <> nil then FImages.DragLeave;
    FImages := nil;
    FData := nil;
    if FOwner <> nil then FOwner.Target.Leave;
  except
    Application.HandleException(nil);
  end;
end;

function TWinDropTarget.Drop(const dataObj: IDataObject; grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
var
  Chosen: TCrossDragDropFormat;
  P: TPoint;
  Value: string;
  Done: boolean;
begin
  Result := S_OK;
  try
    FData := dataObj;
    Done := False;
    if Decide(pt, dwEffect, Chosen) then
    begin
      P := FOwner.Helper.NativeControl.ScreenToClient(pt);
      if Chosen = cdfText then
        Done := ReadText(dataObj, Value) and FOwner.Target.DeliverText(Value, P.X, P.Y)
      else
        Done := ReadFiles(dataObj, Value) and FOwner.Target.DeliverURIs(Value, P.X, P.Y);
    end;
    // A drop event may have freed the target.
    if FOwner <> nil then FOwner.Target.Leave;
    if Done then dwEffect := DROPEFFECT_COPY
    else
      dwEffect := DROPEFFECT_NONE;
    if FImages <> nil then FImages.Drop(dataObj, @pt, dwEffect);
  except
    dwEffect := DROPEFFECT_NONE;
    Application.HandleException(nil);
  end;
  FImages := nil;
  FData := nil;
end;

{ TWinTarget }

constructor TWinTarget.Create(AHelper: TCrossDragDropHelper);
var
  Res: HResult;
begin
  inherited Create(AHelper);
  FHook := TWinHook.Create(Self);
  FDropTarget := TWinDropTarget.Create;
  FDropTarget.FOwner := Self;
  FDropTargetRef := FDropTarget;
  Res := RegisterDragDrop(FHook.Wnd, FDropTargetRef);
  // The destructor cleans up after a raise.
  if Res <> S_OK then
    if Res = DRAGDROP_E_ALREADYREGISTERED then
      raise ECrossDragDrop.Create('The window of ' + AHelper.Control.Name + ' already takes drops from other code.')
    else
      raise ECrossDragDrop.Create('The window of ' + AHelper.Control.Name + ' could not take drops: ' +
        SysErrorMessage(Res));
  FHook.Registered := True;
end;

destructor TWinTarget.Destroy;
begin
  if FDropTarget <> nil then FDropTarget.FOwner := nil;
  if (FHook <> nil) and FHook.Registered then RevokeDragDrop(FHook.Wnd);
  FHook.Free;
  FDropTargetRef := nil;
  inherited Destroy;
end;

function TWinTarget.Target: TCrossDragDropTarget;
begin
  Result := TCrossDragDropTarget(Helper);
end;

procedure TWinTarget.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

initialization
  LiveSources := TFPList.Create;
  NativeSourceClass := TWinSource;
  NativeTargetClass := TWinTarget;

finalization
  LiveSources.Free;

{$ENDIF}

end.
