{ CrossDragDropHelpers

  Native drag and drop for existing Lazarus controls.  Put a
  TCrossDragDropSource on the form, point its Control at a button, a label,
  an image or any other control, and hand over text or files in OnGetText
  or OnGetFiles.  Put a TCrossDragDropTarget on the form, point it at a
  control, and receive what other programs drop in OnDropText or
  OnDropFiles.  The widgetset units supply the native part; this unit holds
  the gesture, the data snapshot, the events and the lifetime rules.

  Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.
}
unit CrossDragDropHelpers;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Forms, Graphics, LMessages, LCLType,
  CrossDragDropData;

type
  ECrossDragDrop = class(Exception);

  // How a drag that this program started came to an end.
  TCrossDragDropOutcome = (cdoDropped, cdoCanceled, cdoRejected, cdoFailed);

  TCrossDragDropGetTextEvent = procedure(Sender: TObject; out AText: string) of object;
  TCrossDragDropGetFilesEvent = procedure(Sender: TObject; Files: TStrings) of object;
  TCrossDragDropEndEvent = procedure(Sender: TObject; Outcome: TCrossDragDropOutcome) of object;
  TCrossDragDropErrorEvent = procedure(Sender: TObject; const Message: string) of object;
  TCrossDragDropOverEvent = procedure(Sender: TObject; Formats: TCrossDragDropFormats; X, Y: integer; var Accept: boolean) of object;
  TCrossDragDropTextEvent = procedure(Sender: TObject; const AText: string; X, Y: integer) of object;
  TCrossDragDropFilesEvent = procedure(Sender: TObject; Files: TStrings; X, Y: integer) of object;

  TCrossDragDropHelper = class;

  { TCrossDragDropNative

    The widgetset's half of one attached helper.  A widgetset unit
    descends from the source and target classes below and stores its
    classes in NativeSourceClass and NativeTargetClass.  The constructor
    raises ECrossDragDrop when the control cannot be hooked. }

  TCrossDragDropNative = class
  protected
    FHelper: TCrossDragDropHelper;
  public
    constructor Create(AHelper: TCrossDragDropHelper); virtual;
    // Draw the helper's effect over the control, or stop drawing it.
    procedure ShowEffect(Visible: boolean); virtual; abstract;
    property Helper: TCrossDragDropHelper read FHelper;
  end;

  TCrossDragDropNativeSource = class(TCrossDragDropNative)
  public
    // Start the native drag from the input event being handled now.
    function Start: boolean; virtual; abstract;
    // False when the widgetset unit feeds the gesture itself through
    // TCrossDragDropSource.Gesture instead of the control's WindowProc.
    function UsesWindowProc: boolean; virtual;
    // The desktop's own threshold where the toolkit has one.
    function PastThreshold(const From, Current: TPoint): boolean; virtual;
  end;

  TCrossDragDropNativeTarget = class(TCrossDragDropNative)
  end;

  TCrossDragDropNativeSourceClass = class of TCrossDragDropNativeSource;
  TCrossDragDropNativeTargetClass = class of TCrossDragDropNativeTarget;

  { TCrossDragDropHelper

    What a source and a target share: the control, the attachment to its
    native window and error reporting. }

  TCrossDragDropHelper = class(TComponent)
  private
    FControl: TControl;
    FEnabled: boolean;
    FEffectShowing: boolean;
    FLastError: string;
    FNative: TCrossDragDropNative;
    FOnError: TCrossDragDropErrorEvent;
    function GetAttached: boolean;
    function GetSupported: boolean;
    procedure SetControl(AValue: TControl);
    procedure SetEnabled(AValue: boolean);
    procedure AttachLater(Data: PtrInt);
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function Wanted: boolean;
    procedure Attach; virtual;
    procedure Detach; virtual;
    procedure Fail(const Message: string);
    procedure SetEffect(Visible: boolean);
    function MakeNative: TCrossDragDropNative; virtual; abstract;
    property Native: TCrossDragDropNative read FNative;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // The control that owns the native window: Control itself, or its
    // parent when Control has no window of its own.
    function NativeControl: TWinControl;
    // Where Control is, in NativeControl's client coordinates.
    function ControlRect: TRect;
    // The widgetset unit calls this when the native window went away.
    // The helper attaches again when a new one exists.
    procedure NativeLost;
    // True while the native hooks are in place.
    property Attached: boolean read GetAttached;
    // True when a widgetset unit for this build exists at all.
    property Supported: boolean read GetSupported;
    // Why the last attach, drag or drop did not happen; empty when it did.
    property LastError: string read FLastError;
    // True while the fade or the highlight is drawn.
    property EffectShowing: boolean read FEffectShowing;
    // The control this helper works for. Nothing happens while it is empty.
    property Control: TControl read FControl write SetControl;
    // False takes the native hooks off the control; the control itself
    // stays enabled.
    property Enabled: boolean read FEnabled write SetEnabled default True;
    // Something went wrong: a second helper on the same control, a bad file
    // list, a widgetset without support. Message says what. No dialog.
    property OnError: TCrossDragDropErrorEvent read FOnError write FOnError;
  end;

  { TCrossDragDropSource }

  TCrossDragDropSource = class(TCrossDragDropHelper)
  private
    FFade: boolean;
    FPressed: boolean;
    FDragging: boolean;
    FStart: TPoint;
    FHasText, FHasFiles: boolean;
    FText, FURIs: string;
    FHooked: TWinControl;
    FOldProc: TWndMethod;
    FOnGetText: TCrossDragDropGetTextEvent;
    FOnGetFiles: TCrossDragDropGetFilesEvent;
    FOnDragBegin: TNotifyEvent;
    FOnDragEnd: TCrossDragDropEndEvent;
    procedure Hooked(var Msg: TLMessage);
    function StartNative: boolean;
  protected
    function MakeNative: TCrossDragDropNative; override;
    // Asks OnGetText and OnGetFiles for the drag's data; False when they
    // offer nothing.
    function Prepare: boolean;
    procedure Attach; override;
    procedure Detach; override;
  public
    constructor Create(AOwner: TComponent); override;
    // A widgetset unit that reads the mouse itself hands the messages
    // here: LM_LBUTTONDOWN, LM_MOUSEMOVE, LM_LBUTTONUP in NativeControl
    // client coordinates, Keys with MK_LBUTTON while the button is down.
    procedure Gesture(var Msg: TLMessage);
    // The widgetset unit reports the native drag's begin and end here.
    procedure NativeBegan;
    procedure NativeEnded(Outcome: TCrossDragDropOutcome);
    // The snapshot taken when the drag started.
    property HasText: boolean read FHasText;
    property HasFiles: boolean read FHasFiles;
    property Text: string read FText;
    property URIs: string read FURIs;
    // True from the native begin to the native end.
    property IsDragging: boolean read FDragging;
    // Where the mouse went down, in NativeControl client coordinates.
    property PressPoint: TPoint read FStart;
  published
    // The control to drag from: any control, windowed or not. Nothing
    // happens while it is empty.
    property Control;
    // False stops this control from starting drags; the control itself
    // stays enabled.
    property Enabled;
    // True fades the control while its drag is in progress.
    property Fade: boolean read FFade write FFade default True;
    // The text to offer, asked for when a drag starts. Leave AText empty
    // to offer no text, for example when no list item is under the mouse.
    property OnGetText: TCrossDragDropGetTextEvent read FOnGetText write FOnGetText;
    // Add full paths of existing files to Files when a drag starts. An
    // empty list offers no files. With nothing offered, no drag starts.
    property OnGetFiles: TCrossDragDropGetFilesEvent read FOnGetFiles write FOnGetFiles;
    // The native drag has started. Nothing has been dropped yet.
    property OnDragBegin: TNotifyEvent read FOnDragBegin write FOnDragBegin;
    // The drag is over. Outcome says whether anything took the data.
    property OnDragEnd: TCrossDragDropEndEvent read FOnDragEnd write FOnDragEnd;
    // A drag could not start: a second source on the control, a file that
    // does not exist, a desktop without support. Message says what.
    property OnError;
  end;

  { TCrossDragDropTarget }

  TCrossDragDropTarget = class(TCrossDragDropHelper)
  private
    FAcceptedFormats: TCrossDragDropFormats;
    FHighlight: boolean;
    FHighlightColor: TColor;
    FRejected: boolean;
    FOnDragOver: TCrossDragDropOverEvent;
    FOnDropText: TCrossDragDropTextEvent;
    FOnDropFiles: TCrossDragDropFilesEvent;
    function Handled: TCrossDragDropFormats;
    function Local(X, Y: integer; out P: TPoint): boolean;
  protected
    function MakeNative: TCrossDragDropNative; override;
  public
    constructor Create(AOwner: TComponent); override;
    // Inside OnDropText or OnDropFiles: the data could not be used, so the
    // other side hears that the drop failed.
    procedure RejectDrop(const Reason: string = '');
    // The widgetset unit asks whether the offer at X, Y (NativeControl
    // client coordinates) is wanted, and which format to fetch.
    function Accepts(Offered: TCrossDragDropFormats; CopyAllowed: boolean; X, Y: integer; out Chosen: TCrossDragDropFormat): boolean;
    // The widgetset unit hands over what arrived. False means the drop
    // was not used.
    function DeliverText(const AText: string; X, Y: integer): boolean;
    function DeliverURIs(const AURIs: string; X, Y: integer): boolean;
    // The pointer left, or the session ended: highlight off.
    procedure Leave;
  published
    // The control that takes drops: any control. A label or an image uses
    // its parent's window, so only one target fits per parent.
    property Control;
    // False stops this control from taking drops; the control itself
    // stays enabled.
    property Enabled;
    // Which kinds of data this target takes. A kind also needs its drop
    // event assigned.
    property AcceptedFormats: TCrossDragDropFormats read FAcceptedFormats write FAcceptedFormats default [cdfText, cdfFiles];
    // True draws a frame in HighlightColor over the control while a drop
    // it would take is over it.
    property Highlight: boolean read FHighlight write FHighlight default True;
    // The color of that frame. The default follows the desktop theme.
    property HighlightColor: TColor read FHighlightColor write FHighlightColor default clHighlight;
    // Decide about an offer before it is dropped. X and Y are inside the
    // control. Accept starts True when the formats and events fit.
    property OnDragOver: TCrossDragDropOverEvent read FOnDragOver write FOnDragOver;
    // Text was dropped at X, Y. Call RejectDrop when it cannot be used.
    property OnDropText: TCrossDragDropTextEvent read FOnDropText write FOnDropText;
    // Existing files were dropped at X, Y, as full paths. Files is only
    // valid during the event. Call RejectDrop when they cannot be used.
    property OnDropFiles: TCrossDragDropFilesEvent read FOnDropFiles write FOnDropFiles;
    // A drop could not be used: a second target on the control, a bad
    // file list, a reason given to RejectDrop. Message says what.
    property OnError;
  end;

var
  NativeSourceClass: TCrossDragDropNativeSourceClass = nil;
  NativeTargetClass: TCrossDragDropNativeTargetClass = nil;

implementation

{$IF DEFINED(LCLGTK2) OR DEFINED(LCLGTK3)}
uses
  CrossDragDropGtk;
{$ELSEIF DEFINED(LCLQT5) OR DEFINED(LCLQT6)}
uses
  CrossDragDropQt;
{$ENDIF}

var
  // Every attached helper, so a second one on the same native window is
  // refused instead of silently taking the first one's hooks.
  AttachedHelpers: TFPList;

  { TCrossDragDropNative }

constructor TCrossDragDropNative.Create(AHelper: TCrossDragDropHelper);
begin
  inherited Create;
  FHelper := AHelper;
end;

{ TCrossDragDropNativeSource }

function TCrossDragDropNativeSource.PastThreshold(const From, Current: TPoint): boolean;
begin
  Result := (Abs(Current.X - From.X) >= Mouse.DragThreshold) or (Abs(Current.Y - From.Y) >= Mouse.DragThreshold);
end;

function TCrossDragDropNativeSource.UsesWindowProc: boolean;
begin
  Result := True;
end;

{ TCrossDragDropHelper }

constructor TCrossDragDropHelper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
end;

destructor TCrossDragDropHelper.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  Detach;
  inherited Destroy;
end;

function TCrossDragDropHelper.GetAttached: boolean;
begin
  Result := FNative <> nil;
end;

function TCrossDragDropHelper.GetSupported: boolean;
begin
  if Self is TCrossDragDropSource then
    Result := NativeSourceClass <> nil
  else
    Result := NativeTargetClass <> nil;
end;

procedure TCrossDragDropHelper.SetControl(AValue: TControl);
begin
  if FControl = AValue then Exit;
  Detach;
  if FControl <> nil then FControl.RemoveFreeNotification(Self);
  FControl := AValue;
  if FControl <> nil then FControl.FreeNotification(Self);
  Attach;
end;

procedure TCrossDragDropHelper.SetEnabled(AValue: boolean);
begin
  if FEnabled = AValue then Exit;
  FEnabled := AValue;
  if FEnabled then Attach
  else
    Detach;
end;

procedure TCrossDragDropHelper.Loaded;
begin
  inherited Loaded;
  // The form is still being built; attach once it has settled.
  Application.QueueAsyncCall(@AttachLater, 0);
end;

procedure TCrossDragDropHelper.AttachLater(Data: PtrInt);
begin
  if not (csDestroying in ComponentState) then Attach;
end;

procedure TCrossDragDropHelper.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FControl) then
  begin
    Detach;
    FControl := nil;
  end;
end;

function TCrossDragDropHelper.Wanted: boolean;
begin
  Result := FEnabled and (FControl <> nil) and (ComponentState * [csDesigning, csLoading, csDestroying] = []);
end;

function TCrossDragDropHelper.NativeControl: TWinControl;
begin
  if FControl is TWinControl then Result := TWinControl(FControl)
  else if FControl <> nil then Result := FControl.Parent
  else
    Result := nil;
end;

function TCrossDragDropHelper.ControlRect: TRect;
begin
  if FControl is TWinControl then Result := FControl.ClientRect
  else
    Result := FControl.BoundsRect;
end;

procedure TCrossDragDropHelper.Attach;
var
  Window: TWinControl;
  I: integer;
  Other: TCrossDragDropHelper;
begin
  if (FNative <> nil) or not Wanted then Exit;
  Window := NativeControl;
  if Window = nil then Exit;
  if not Supported then
  begin
    Fail('Native drag and drop is not available on this widgetset yet.');
    Exit;
  end;
  for I := 0 to AttachedHelpers.Count - 1 do
  begin
    Other := TCrossDragDropHelper(AttachedHelpers[I]);
    if ((Other is TCrossDragDropSource) = (Self is TCrossDragDropSource)) and (Other.NativeControl = Window) then
    begin
      if Other.Control = FControl then
        Fail(FControl.Name + ' already has a ' + ClassName)
      else
        Fail(FControl.Name + ' shares its window with ' + Other.Control.Name + ', which already has a ' + ClassName);
      Exit;
    end;
  end;
  try
    if not Window.HandleAllocated then Window.HandleNeeded;
    FNative := MakeNative;
    AttachedHelpers.Add(Self);
    FLastError := '';
  except
    on E: ECrossDragDrop do Fail(E.Message);
  end;
end;

procedure TCrossDragDropHelper.Detach;
begin
  if FNative = nil then Exit;
  AttachedHelpers.Remove(Self);
  FEffectShowing := False;
  FreeAndNil(FNative);
end;

procedure TCrossDragDropHelper.NativeLost;
begin
  Detach;
  if Wanted then Application.QueueAsyncCall(@AttachLater, 0);
end;

procedure TCrossDragDropHelper.Fail(const Message: string);
begin
  FLastError := Message;
  if Assigned(FOnError) then FOnError(Self, Message);
end;

procedure TCrossDragDropHelper.SetEffect(Visible: boolean);
begin
  if (FNative = nil) or (FEffectShowing = Visible) then Exit;
  FEffectShowing := Visible;
  FNative.ShowEffect(Visible);
end;

{ TCrossDragDropSource }

constructor TCrossDragDropSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFade := True;
end;

// The gesture is read from the mouse messages of the control's window,
// through its WindowProc chain, which every widgetset feeds.
procedure TCrossDragDropSource.Attach;
begin
  inherited Attach;
  if (FNative = nil) or (FHooked <> nil) or not TCrossDragDropNativeSource(FNative).UsesWindowProc then Exit;
  FHooked := NativeControl;
  FOldProc := FHooked.WindowProc;
  FHooked.WindowProc := @Hooked;
end;

procedure TCrossDragDropSource.Detach;
begin
  if FHooked <> nil then
  begin
    if (TMethod(FHooked.WindowProc).Data = Pointer(Self)) then
      FHooked.WindowProc := FOldProc;
    FHooked := nil;
  end;
  inherited Detach;
end;

procedure TCrossDragDropSource.Hooked(var Msg: TLMessage);
var
  Next: TWndMethod;
begin
  Next := FOldProc;
  case Msg.Msg of
    LM_LBUTTONDOWN, LM_LBUTTONDBLCLK, LM_MOUSEMOVE, LM_LBUTTONUP, LM_CANCELMODE:
      Gesture(Msg);
  end;
  // A drag that ran inside Gesture may have detached this helper.
  Next(Msg);
end;

function TCrossDragDropSource.MakeNative: TCrossDragDropNative;
begin
  Result := NativeSourceClass.Create(Self);
end;

procedure TCrossDragDropSource.Gesture(var Msg: TLMessage);
var
  P: TPoint;
begin
  if (Msg.Msg = LM_LBUTTONUP) or (Msg.Msg = LM_CANCELMODE) then FPressed := False;
  if (FNative = nil) or FDragging then Exit;
  case Msg.Msg of
    LM_LBUTTONDOWN, LM_LBUTTONDBLCLK:
    begin
      FStart := Point(TLMMouse(Msg).XPos, TLMMouse(Msg).YPos);
      FPressed := PtInRect(ControlRect, FStart);
    end;
    LM_MOUSEMOVE:
      if FPressed and (TLMMouseMove(Msg).Keys and MK_LBUTTON <> 0) then
      begin
        P := Point(TLMMouseMove(Msg).XPos, TLMMouseMove(Msg).YPos);
        if TCrossDragDropNativeSource(FNative).PastThreshold(FStart, P) then
        begin
          FPressed := False;
          if Prepare then StartNative;
        end;
      end;
  end;
end;

function TCrossDragDropSource.Prepare: boolean;
var
  Files: TStringList;
  Error: string;
begin
  Result := False;
  FHasFiles := False;
  FText := '';
  FURIs := '';
  if Assigned(FOnGetText) then FOnGetText(Self, FText);
  FHasText := FText <> '';
  if Assigned(FOnGetFiles) then
  begin
    Files := TStringList.Create;
    try
      FOnGetFiles(Self, Files);
      if Files.Count > 0 then
      begin
        if not CrossDragDropFilesToURIs(Files, FURIs, Error) then
        begin
          Fail(Error);
          Exit;
        end;
        FHasFiles := True;
      end;
    finally
      Files.Free;
    end;
  end;
  Result := FHasText or FHasFiles;
end;

function TCrossDragDropSource.StartNative: boolean;
begin
  // Let go of the LCL's capture and pressed state before the native grab.
  FControl.Perform(LM_CANCELMODE, 0, 0);
  Result := TCrossDragDropNativeSource(FNative).Start;
  if not Result then Fail('The native drag did not start.');
end;

procedure TCrossDragDropSource.NativeBegan;
begin
  FPressed := False;
  FDragging := True;
  // The press that became a drag must not also count as a click.
  if FControl <> nil then FControl.ControlState := FControl.ControlState - [csClicked];
  if FFade then SetEffect(True);
  if Assigned(FOnDragBegin) then FOnDragBegin(Self);
end;

procedure TCrossDragDropSource.NativeEnded(Outcome: TCrossDragDropOutcome);
begin
  FDragging := False;
  SetEffect(False);
  FText := '';
  FURIs := '';
  if Assigned(FOnDragEnd) then FOnDragEnd(Self, Outcome);
end;

{ TCrossDragDropTarget }

constructor TCrossDragDropTarget.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAcceptedFormats := [cdfText, cdfFiles];
  FHighlight := True;
  FHighlightColor := clHighlight;
end;

function TCrossDragDropTarget.MakeNative: TCrossDragDropNative;
begin
  Result := NativeTargetClass.Create(Self);
end;

function TCrossDragDropTarget.Handled: TCrossDragDropFormats;
begin
  Result := [];
  if Assigned(FOnDropText) then Include(Result, cdfText);
  if Assigned(FOnDropFiles) then Include(Result, cdfFiles);
end;

function TCrossDragDropTarget.Local(X, Y: integer; out P: TPoint): boolean;
var
  R: TRect;
begin
  R := ControlRect;
  P := Point(X - R.Left, Y - R.Top);
  Result := (FControl is TWinControl) or PtInRect(R, Point(X, Y));
end;

procedure TCrossDragDropTarget.RejectDrop(const Reason: string);
begin
  FRejected := True;
  if Reason <> '' then Fail(Reason);
end;

function TCrossDragDropTarget.Accepts(Offered: TCrossDragDropFormats; CopyAllowed: boolean; X, Y: integer; out Chosen: TCrossDragDropFormat): boolean;
var
  P: TPoint;
begin
  Result := (FNative <> nil) and Local(X, Y, P) and CrossDragDropChooseFormat(Offered, FAcceptedFormats, Handled, CopyAllowed, Chosen);
  if Result and Assigned(FOnDragOver) then
    FOnDragOver(Self, Offered * FAcceptedFormats * Handled, P.X, P.Y, Result);
  if FHighlight then SetEffect(Result)
  else
    SetEffect(False);
end;

function TCrossDragDropTarget.DeliverText(const AText: string; X, Y: integer): boolean;
var
  P: TPoint;
begin
  Result := False;
  FRejected := False;
  if (FNative <> nil) and Local(X, Y, P) and Assigned(FOnDropText) then
  begin
    FOnDropText(Self, AText, P.X, P.Y);
    Result := not FRejected;
  end;
  Leave;
end;

function TCrossDragDropTarget.DeliverURIs(const AURIs: string; X, Y: integer): boolean;
var
  Files: TStringList;
  P: TPoint;
  Error: string;
begin
  Result := False;
  FRejected := False;
  Files := TStringList.Create;
  try
    if (FNative <> nil) and Local(X, Y, P) and Assigned(FOnDropFiles) then
      if CrossDragDropURIsToFiles(AURIs, Files, Error) then
      begin
        FOnDropFiles(Self, Files, P.X, P.Y);
        Result := not FRejected;
      end
      else
        Fail(Error);
  finally
    Files.Free;
    Leave;
  end;
end;

procedure TCrossDragDropTarget.Leave;
begin
  SetEffect(False);
end;

initialization
  AttachedHelpers := TFPList.Create;

finalization
  AttachedHelpers.Free;
end.
