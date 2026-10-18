{ CrossDragDropQt

  The Qt5 and Qt6 half of CrossDragDrop: QDrag from the control's widget,
  the gesture and the drop events caught by an event filter before the
  LCL's own handling, the fade and the highlight as a picture on a label
  that mouse and drop events pass through, and a grab of the control as
  the drag pixmap.  The unit is empty on other widgetsets.

  Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.
}
unit CrossDragDropQt;

{$mode objfpc}{$H+}

interface

implementation

{$IF DEFINED(LCLQT5) OR DEFINED(LCLQT6)}

uses
  Classes, SysUtils, Types, Controls, Forms, Graphics, LCLType, LMessages,
  QtWidgets, {$IFDEF LCLQT6}Qt6{$ELSE}Qt5{$ENDIF},
  CrossDragDropHelpers, CrossDragDropData;

type
  TQtNativeEvent = function(Sender: QObjectH; Event: QEventH): boolean of object;

  { TQtHook

    The control's widget, the event filter, the overlay that draws the
    effect, and the destroyed signal that tells the helper to let go. }

  TQtHook = class
  private
    FOwner: TCrossDragDropNative;
    FWidget, FClient: QWidgetH;
    FHook, FClientHook: QObject_hookH;
    FOverlay: QLabelH;
    FOnEvent: TQtNativeEvent;
    FDead, FEffect: boolean;
    function Filter(Sender: QObjectH; Event: QEventH): boolean; cdecl;
    procedure Destroyed; cdecl;
    procedure LostLater(Data: PtrInt);
    procedure PlaceOverlay;
    function Render: QPixmapH;
  public
    constructor Create(AOwner: TCrossDragDropNative; OnEvent: TQtNativeEvent);
    destructor Destroy; override;
    procedure SetEffect(Visible: boolean);
    // The control's area in FClient coordinates.
    function Area: TRect;
    property Widget: QWidgetH read FWidget;
    property Client: QWidgetH read FClient;
    property Dead: boolean read FDead;
  end;

  { TQtSource }

  TQtSource = class(TCrossDragDropNativeSource)
  private
    FHook: TQtHook;
    FStarted: boolean;
    function Source: TCrossDragDropSource;
    function OnEvent(Sender: QObjectH; Event: QEventH): boolean;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    function Start: boolean; override;
    function UsesWindowProc: boolean; override;
    function PastThreshold(const From, Current: TPoint): boolean; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

  { TQtTarget }

  TQtTarget = class(TCrossDragDropNativeTarget)
  private
    FHook: TQtHook;
    FAcceptedBefore, FClientAcceptedBefore: boolean;
    function Target: TCrossDragDropTarget;
    function Offered(Mime: QMimeDataH): TCrossDragDropFormats;
    function OnEvent(Sender: QObjectH; Event: QEventH): boolean;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

var
  // Sources alive right now; a drag runs a nested loop, so Start checks
  // afterwards that its own object was not freed meanwhile.
  LiveSources: TFPList;

const
  URIListType: WideString = 'text/uri-list';

function QtColor(Color: TColor; Alpha: byte): TQColor;
begin
  Color := ColorToRGB(Color);
  Result.ColorSpec := 1;
  Result.Alpha := Alpha * 257;
  Result.r := (Color and $FF) * 257;
  Result.g := ((Color shr 8) and $FF) * 257;
  Result.b := ((Color shr 16) and $FF) * 257;
  Result.Pad := 0;
end;

{ TQtHook }

constructor TQtHook.Create(AOwner: TCrossDragDropNative; OnEvent: TQtNativeEvent);
var
  Native: TQtWidget;
begin
  inherited Create;
  FOwner := AOwner;
  FOnEvent := OnEvent;
  Native := TQtWidget(AOwner.Helper.NativeControl.Handle);
  FWidget := Native.Widget;
  FClient := Native.GetContainerWidget;
  if FClient = nil then FClient := FWidget;
  FHook := QObject_hook_Create(FWidget);
  QObject_hook_hook_events(FHook, @Filter);
  QObject_hook_hook_destroyed(FHook, @Destroyed);
  if FClient <> FWidget then
  begin
    FClientHook := QObject_hook_Create(FClient);
    QObject_hook_hook_events(FClientHook, @Filter);
  end;
  // The overlay is a label that stays in place, see-through and transparent
  // to the mouse. Showing or hiding a child while Qt starts a drag stalls
  // the drag, and painting one from an event filter upsets Qt's painting,
  // so the effect is a picture given to the label and taken away again.
  FOverlay := QLabel_Create(FClient);
  QWidget_setAttribute(FOverlay, QtWA_TransparentForMouseEvents, True);
  QWidget_setAttribute(FOverlay, QtWA_NoSystemBackground, True);
  PlaceOverlay;
  QWidget_show(FOverlay);
end;

procedure TQtHook.PlaceOverlay;
var
  R: TRect;
begin
  if (FOverlay = nil) or FDead then Exit;
  R := Area;
  QWidget_setGeometry(FOverlay, R.Left, R.Top, R.Width, R.Height);
  QWidget_raise(FOverlay);
end;

destructor TQtHook.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if (FOverlay <> nil) and not FDead then QWidget_Destroy(FOverlay);
  if FClientHook <> nil then QObject_hook_Destroy(FClientHook);
  QObject_hook_Destroy(FHook);
  inherited Destroy;
end;

function TQtHook.Filter(Sender: QObjectH; Event: QEventH): boolean; cdecl;
begin
  Result := False;
  try
    if (QEvent_type(Event) = QEventResize) and (Sender = QObjectH(FClient)) then PlaceOverlay;
    if Assigned(FOnEvent) then Result := FOnEvent(Sender, Event);
  except
    Application.HandleException(nil);
  end;
end;

procedure TQtHook.Destroyed; cdecl;
begin
  // The widget is going; its children, the overlay among them, go with it.
  FDead := True;
  FOverlay := nil;
  Application.QueueAsyncCall(@LostLater, 0);
end;

procedure TQtHook.LostLater(Data: PtrInt);
begin
  // Frees the owner and this hook.
  FOwner.Helper.NativeLost;
end;

function TQtHook.Area: TRect;
begin
  if FOwner.Helper.Control is TWinControl then
    QWidget_rect(FClient, @Result)
  else
    Result := FOwner.Helper.ControlRect;
end;

procedure TQtHook.SetEffect(Visible: boolean);
var
  Picture: QPixmapH;
begin
  if (FEffect = Visible) or FDead or (FOverlay = nil) then Exit;
  FEffect := Visible;
  if Visible then
  begin
    PlaceOverlay;
    Picture := Render;
    try
      QLabel_setPixmap(FOverlay, Picture);
    finally
      QPixmap_Destroy(Picture);
    end;
  end
  else
    QLabel_clear(FOverlay);
end;

function TQtHook.Render: QPixmapH;
var
  Image: QImageH;
  Painter: QPainterH;
  Brush: QBrushH;
  Pen: QPenH;
  Color: TQColor;
  R: TRect;
begin
  R := Area;
  Image := QImage_Create(R.Width, R.Height, QImageFormat_ARGB32_Premultiplied);
  try
    QImage_fill(Image, 0);
    Painter := QPainter_Create(QPaintDeviceH(Image));
    try
      if FOwner is TQtSource then
      begin
        // Lifted away: the control fades under the window color, a dashed
        // line keeps its outline.
        Color := QtColor(clForm, 150);
        Brush := QBrush_Create(@Color);
        QPainter_fillRect(Painter, 0, 0, R.Width, R.Height, Brush);
        QBrush_Destroy(Brush);
        Color := QtColor(clWindowText, 128);
        Pen := QPen_Create(@Color);
        QPen_setStyle(Pen, QtDashLine);
        QPainter_setPen(Painter, Pen);
        QPainter_setBrush(Painter, QtNoBrush);
        QPainter_drawRect(Painter, 0, 0, R.Width - 1, R.Height - 1);
        QPen_Destroy(Pen);
      end
      else
      begin
        Color := QtColor(TCrossDragDropTarget(FOwner.Helper).HighlightColor, 40);
        Brush := QBrush_Create(@Color);
        QPainter_fillRect(Painter, 0, 0, R.Width, R.Height, Brush);
        QBrush_Destroy(Brush);
        Color := QtColor(TCrossDragDropTarget(FOwner.Helper).HighlightColor, 230);
        Pen := QPen_Create(@Color);
        QPen_setWidth(Pen, 2);
        QPainter_setPen(Painter, Pen);
        QPainter_setBrush(Painter, QtNoBrush);
        QPainter_drawRect(Painter, 1, 1, R.Width - 2, R.Height - 2);
        QPen_Destroy(Pen);
      end;
    finally
      QPainter_Destroy(Painter);
    end;
    Result := QPixmap_Create;
    QPixmap_fromImage(Result, Image);
  finally
    QImage_Destroy(Image);
  end;
end;

{ TQtSource }

constructor TQtSource.Create(AHelper: TCrossDragDropHelper);
begin
  inherited Create(AHelper);
  FHook := TQtHook.Create(Self, @OnEvent);
  LiveSources.Add(Self);
end;

destructor TQtSource.Destroy;
begin
  LiveSources.Remove(Self);
  // The drag object belongs to the widget and goes with it.
  FHook.Free;
  inherited Destroy;
end;

function TQtSource.Source: TCrossDragDropSource;
begin
  Result := TCrossDragDropSource(Helper);
end;

function TQtSource.UsesWindowProc: boolean;
begin
  Result := False;
end;

// The gesture is read here, before the LCL handles the mouse event, as
// Qt expects a drag to start from inside the event that moves the mouse.
// A started drag swallows that event.
function TQtSource.OnEvent(Sender: QObjectH; Event: QEventH): boolean;
var
  Kind: QEventType;
  Msg: TLMMouse;
  Mouse: QMouseEventH;
begin
  Result := False;
  Kind := QEvent_type(Event);
  if (Kind <> QEventMouseButtonPress) and (Kind <> QEventMouseMove) and
    (Kind <> QEventMouseButtonRelease) then Exit;
  if Sender <> QObjectH(FHook.Widget) then Exit;
  Mouse := QMouseEventH(Event);
  FillChar(Msg, SizeOf(Msg), 0);
  case Kind of
    QEventMouseButtonPress:
      if QMouseEvent_button(Mouse) = QtLeftButton then Msg.Msg := LM_LBUTTONDOWN
      else
        Exit;
    QEventMouseButtonRelease: Msg.Msg := LM_LBUTTONUP;
    else
      Msg.Msg := LM_MOUSEMOVE;
  end;
  if QMouseEvent_buttons(Mouse) and QtLeftButton <> 0 then Msg.Keys := MK_LBUTTON;
  Msg.XPos := QMouseEvent_x(Mouse);
  Msg.YPos := QMouseEvent_y(Mouse);
  FStarted := False;
  Source.Gesture(TLMessage(Msg));
  Result := FStarted;
end;

function TQtSource.PastThreshold(const From, Current: TPoint): boolean;
var
  D: integer;
begin
  D := QApplication_startDragDistance;
  Result := (Abs(Current.X - From.X) >= D) or (Abs(Current.Y - From.Y) >= D);
end;

procedure TQtSource.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

function TQtSource.Start: boolean;
var
  Drag: QDragH;
  Mime: QMimeDataH;
  Bytes: QByteArrayH;
  Text: WideString;
  Pixmap: QPixmapH;
  R: TRect;
  Hot: TQtPoint;
  Me: TQtSource;
  Outcome: TCrossDragDropOutcome;
begin
  Result := False;
  // Qt runs the drag in a loop of its own; without a button down it
  // would wait for a release that never comes.
  if FHook.Dead or (QGuiApplication_mouseButtons and QtLeftButton = 0) then Exit;
  // A new drag object every time, owned by the widget and freed with it.
  // Qt keeps referring to a finished drag: deleting it, or running it a
  // second time, stalls the next drag.
  FStarted := True;
  Drag := QDrag_Create(FHook.Widget);
  Mime := QMimeData_Create;
  QDrag_setMimeData(Drag, Mime);
  if Source.HasText then
  begin
    Text := UTF8Decode(Source.Text);
    QMimeData_setText(Mime, @Text);
  end;
  if Source.HasFiles then
  begin
    Bytes := QByteArray_Create(PAnsiChar(Source.URIs), Length(Source.URIs));
    try
      QMimeData_setData(Mime, @URIListType, Bytes);
    finally
      QByteArray_Destroy(Bytes);
    end;
  end;
  R := FHook.Area;
  Pixmap := QPixmap_Create;
  try
    QWidget_grab(FHook.Client, Pixmap, @R);
    if not QPixmap_isNull(Pixmap) then
    begin
      Hot.X := Source.PressPoint.X - Helper.ControlRect.Left;
      Hot.Y := Source.PressPoint.Y - Helper.ControlRect.Top;
      if (Hot.X < 0) or (Hot.X >= R.Width) then Hot.X := R.Width div 2;
      if (Hot.Y < 0) or (Hot.Y >= R.Height) then Hot.Y := R.Height div 2;
      QDrag_setPixmap(Drag, Pixmap);
      QDrag_setHotSpot(Drag, @Hot);
    end;
  finally
    QPixmap_Destroy(Pixmap);
  end;
  // A button never sees the release that the drag swallows.
  if QObject_inherits(FHook.Widget, 'QAbstractButton') then
    QAbstractButton_setDown(QAbstractButtonH(FHook.Widget), False);
  Me := Self;
  Source.NativeBegan;
  if QDrag_exec(Drag, QtCopyAction, QtCopyAction) = QtCopyAction then
    Outcome := cdoDropped
  else
    Outcome := cdoRejected;
  Result := True;
  if LiveSources.IndexOf(Me) < 0 then Exit;
  Source.NativeEnded(Outcome);
end;

{ TQtTarget }

constructor TQtTarget.Create(AHelper: TCrossDragDropHelper);
begin
  inherited Create(AHelper);
  FHook := TQtHook.Create(Self, @OnEvent);
  FAcceptedBefore := QWidget_acceptDrops(FHook.Widget);
  QWidget_setAcceptDrops(FHook.Widget, True);
  if FHook.Client <> FHook.Widget then
  begin
    FClientAcceptedBefore := QWidget_acceptDrops(FHook.Client);
    QWidget_setAcceptDrops(FHook.Client, True);
  end;
end;

destructor TQtTarget.Destroy;
begin
  if not FHook.Dead then
  begin
    QWidget_setAcceptDrops(FHook.Widget, FAcceptedBefore);
    if FHook.Client <> FHook.Widget then
      QWidget_setAcceptDrops(FHook.Client, FClientAcceptedBefore);
  end;
  FHook.Free;
  inherited Destroy;
end;

function TQtTarget.Target: TCrossDragDropTarget;
begin
  Result := TCrossDragDropTarget(Helper);
end;

procedure TQtTarget.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

function TQtTarget.Offered(Mime: QMimeDataH): TCrossDragDropFormats;
begin
  Result := [];
  if QMimeData_hasText(Mime) then Include(Result, cdfText);
  if QMimeData_hasFormat(Mime, @URIListType) then Include(Result, cdfFiles);
end;

function TQtTarget.OnEvent(Sender: QObjectH; Event: QEventH): boolean;
var
  Kind: QEventType;
  Drop: QDropEventH;
  Mime: QMimeDataH;
  P: TQtPoint;
  Chosen: TCrossDragDropFormat;
  Ok: boolean;
  Text: WideString;
  Bytes: QByteArrayH;
  Value: string;
begin
  Result := False;
  Kind := QEvent_type(Event);
  if Kind = QEventDragLeave then
  begin
    Target.Leave;
    Exit;
  end;
  if (Kind <> QEventDragEnter) and (Kind <> QEventDragMove) and (Kind <> QEventDrop) then Exit;
  Result := True;
  Drop := QDropEventH(Event);
  Mime := QDropEvent_mimeData(Drop);
  QDropEvent_pos(Drop, @P);
  Ok := Target.Accepts(Offered(Mime), QDropEvent_possibleActions(Drop) and QtCopyAction <> 0,
    P.X, P.Y, Chosen);
  if Ok and (Kind = QEventDrop) then
    if Chosen = cdfText then
    begin
      QMimeData_text(Mime, @Text);
      Ok := Target.DeliverText(UTF8Encode(Text), P.X, P.Y);
    end
    else
    begin
      Bytes := QByteArray_Create;
      try
        QMimeData_data(Mime, Bytes, @URIListType);
        SetString(Value, QByteArray_constData(Bytes), QByteArray_size(Bytes));
      finally
        QByteArray_Destroy(Bytes);
      end;
      Ok := Target.DeliverURIs(Value, P.X, P.Y);
    end;
  if Ok then
  begin
    QDropEvent_setDropAction(Drop, QtCopyAction);
    QEvent_accept(Event);
  end
  else
    QEvent_ignore(Event);
end;

initialization
  LiveSources := TFPList.Create;
  NativeSourceClass := TQtSource;
  NativeTargetClass := TQtTarget;

finalization
  LiveSources.Free;

{$ENDIF}

end.
