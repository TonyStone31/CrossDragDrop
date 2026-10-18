{ CrossDragDropGtk

  The GTK2 and GTK3 half of CrossDragDrop: native drag sources and drop
  targets on the control's own widget, the fade and the highlight drawn
  after the widget's own paint, and a snapshot of the control as the drag
  icon.  Nothing here is used on other widgetsets; the unit is then empty.

  Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.
}
unit CrossDragDropGtk;

{$mode objfpc}{$H+}

interface

implementation

{$IF DEFINED(LCLGTK2) OR DEFINED(LCLGTK3)}

uses
  Classes, SysUtils, Types, Controls, Forms, Graphics, LCLType,
  {$IFDEF LCLGTK2}
  Gtk2, Gdk2, Gdk2Pixbuf, GLib2, Cairo, Gtk2Proc,
  {$ELSE}
  LazGtk3, LazGdk3, LazGLib2, LazGObject2, LazGdkPixbuf2, LazCairo1, Gtk3Widgets,
  {$ENDIF}
  CrossDragDropHelpers, CrossDragDropData;

const
  TextInfo = 1;
  FilesInfo = 2;
  // drag-failed reasons, the same numbers in GTK2 and GTK3
  ResultNoTarget = 1;
  ResultUserCanceled = 2;
  {$IFDEF LCLGTK2}
  CopyAction = GDK_ACTION_COPY;
  NoAction = 0;
  ConnectDefault = 0;
  ConnectAfter = G_CONNECT_AFTER;
  {$ELSE}
  CopyAction: TGdkDragAction = [GDK_ACTION_COPY];
  NoAction: TGdkDragAction = [];
  ConnectDefault: TGConnectFlags = [];
  ConnectAfter: TGConnectFlags = [G_CONNECT_AFTER];
  {$ENDIF}

type
  {$IFDEF LCLGTK2}
  TAtom = TGdkAtom;
  TDragResult = gint;
  {$ELSE}
  TAtom = PGdkAtom;
  TDragResult = TGtkDragResult;
  {$ENDIF}

  { TGtkHook

    The widget, its signal connections and the effect drawn over it.  Owned
    by the source or target below.  The widget's destroy signal tells the
    helper to let go and attach again later. }

  TGtkSignal = record
    Widget: PGtkWidget;
    ID: gulong;
  end;

  TGtkHook = class
  private
    FOwner: TCrossDragDropNative;
    FWidget: PGtkWidget;
    // GTK2 paints a container's client area into a child widget with its
    // own window, so the effect is drawn there; GTK3 draws on FWidget.
    FDrawWidget: PGtkWidget;
    FSignals: array of TGtkSignal;
    FDead: boolean;
    FEffect: boolean;
    procedure Paint(cr: Pcairo_t);
    class procedure Destroyed(Widget: PGtkWidget; Data: gpointer); cdecl; static;
    {$IFDEF LCLGTK2}
    class function Expose(Widget: PGtkWidget; Event: PGdkEventExpose; Data: gpointer): gboolean;
      cdecl; static;
    {$ELSE}
    class function Draw(Widget: PGtkWidget; cr: Pcairo_t; Data: gpointer): gboolean; cdecl; static;
    {$ENDIF}
  public
    constructor Create(AOwner: TCrossDragDropNative);
    destructor Destroy; override;
    procedure Connect(const Name: PChar; Callback: TGCallback; After: boolean = False;
      OnWidget: PGtkWidget = nil);
    procedure SetEffect(Visible: boolean);
    // The control's area in widget coordinates.
    function Area: TRect;
    function Snapshot(out HotX, HotY: integer): PGdkPixbuf;
    property Widget: PGtkWidget read FWidget;
    property Dead: boolean read FDead;
  end;

  { TGtkSource }

  TGtkSource = class(TCrossDragDropNativeSource)
  private
    FHook: TGtkHook;
    FFailed: integer;
    function Source: TCrossDragDropSource;
    class procedure DragBegin(Widget: PGtkWidget; Context: PGdkDragContext; Data: gpointer);
      cdecl; static;
    class procedure DragEnd(Widget: PGtkWidget; Context: PGdkDragContext; Data: gpointer);
      cdecl; static;
    class function DragFailed(Widget: PGtkWidget; Context: PGdkDragContext;
      Reason: TDragResult; Data: gpointer): gboolean; cdecl; static;
    class procedure DataGet(Widget: PGtkWidget; Context: PGdkDragContext;
      Selection: PGtkSelectionData; Info, Time: guint; Data: gpointer); cdecl; static;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    function Start: boolean; override;
    function PastThreshold(const From, Current: TPoint): boolean; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

  { TGtkTarget }

  TGtkTarget = class(TCrossDragDropNativeTarget)
  private
    FHook: TGtkHook;
    FTextList, FFilesList: PGtkTargetList;
    FBlocked: gulong;
    FPending: PGdkDragContext;
    FPendingFormat: TCrossDragDropFormat;
    function Target: TCrossDragDropTarget;
    function Offered(Context: PGdkDragContext): TCrossDragDropFormats;
    function Decide(Context: PGdkDragContext; X, Y: integer;
      out Chosen: TCrossDragDropFormat): boolean;
    class function Motion(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
      Time: guint; Data: gpointer): gboolean; cdecl; static;
    class procedure Leave(Widget: PGtkWidget; Context: PGdkDragContext; Time: guint;
      Data: gpointer); cdecl; static;
    class function Drop(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
      Time: guint; Data: gpointer): gboolean; cdecl; static;
    class procedure Received(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
      Selection: PGtkSelectionData; Info, Time: guint; Data: gpointer); cdecl; static;
  public
    constructor Create(AHelper: TCrossDragDropHelper); override;
    destructor Destroy; override;
    procedure ShowEffect(Visible: boolean); override;
  end;

function SourceOf(Data: gpointer): TGtkSource;
begin
  Result := TGtkSource(TGtkHook(Data).FOwner);
end;

function TargetOf(Data: gpointer): TGtkTarget;
begin
  Result := TGtkTarget(TGtkHook(Data).FOwner);
end;

function WidgetOf(Control: TWinControl): PGtkWidget;
begin
  {$IFDEF LCLGTK2}
  Result := PGtkWidget(Control.Handle);
  {$ELSE}
  Result := TGtk3Widget(Control.Handle).Widget;
  {$ENDIF}
end;

function AllowsCopy(Context: PGdkDragContext): boolean;
begin
  {$IFDEF LCLGTK2}
  Result := Context^.actions and GDK_ACTION_COPY <> 0;
  {$ELSE}
  Result := GDK_ACTION_COPY in gdk_drag_context_get_actions(Context);
  {$ENDIF}
end;

function ActionChosen(Context: PGdkDragContext): boolean;
begin
  {$IFDEF LCLGTK2}
  Result := Context^.action <> 0;
  {$ELSE}
  Result := gdk_drag_context_get_selected_action(Context) <> [];
  {$ENDIF}
end;

procedure SetSourceColor(cr: Pcairo_t; Color: TColor; Alpha: double);
begin
  Color := ColorToRGB(Color);
  cairo_set_source_rgba(cr, (Color and $FF) / 255, ((Color shr 8) and $FF) / 255,
    ((Color shr 16) and $FF) / 255, Alpha);
end;

{$IFDEF LCLGTK2}
function HasWindow(Widget: PGtkWidget): boolean;
begin
  Result := not GTK_WIDGET_NO_WINDOW(Widget);
end;

function Allocation(Widget: PGtkWidget): TRect;
begin
  with Widget^.allocation do Result := Bounds(x, y, width, height);
end;
{$ELSE}
function HasWindow(Widget: PGtkWidget): boolean;
begin
  Result := gtk_widget_get_has_window(Widget);
end;

function Allocation(Widget: PGtkWidget): TRect;
var
  A: TGtkAllocation;
begin
  gtk_widget_get_allocation(Widget, @A);
  Result := Bounds(A.x, A.y, A.width, A.height);
end;
{$ENDIF}

{ TGtkHook }

constructor TGtkHook.Create(AOwner: TCrossDragDropNative);
begin
  inherited Create;
  FOwner := AOwner;
  FWidget := WidgetOf(AOwner.Helper.NativeControl);
  g_object_ref(FWidget);
  Connect('destroy', TGCallback(@Destroyed));
  {$IFDEF LCLGTK2}
  FDrawWidget := PGtkWidget(GetFixedWidget(FWidget));
  Connect('expose-event', TGCallback(@Expose), True, FDrawWidget);
  {$ELSE}
  FDrawWidget := FWidget;
  Connect('draw', TGCallback(@Draw), True);
  {$ENDIF}
end;

destructor TGtkHook.Destroy;
var
  I: integer;
begin
  if not FDead then
  begin
    for I := 0 to High(FSignals) do
      g_signal_handler_disconnect(FSignals[I].Widget, FSignals[I].ID);
    if FEffect then gtk_widget_queue_draw(FDrawWidget);
  end;
  g_object_unref(FWidget);
  inherited Destroy;
end;

procedure TGtkHook.Connect(const Name: PChar; Callback: TGCallback; After: boolean;
  OnWidget: PGtkWidget);
var
  I: integer;
begin
  if OnWidget = nil then OnWidget := FWidget;
  I := Length(FSignals);
  SetLength(FSignals, I + 1);
  FSignals[I].Widget := OnWidget;
  if After then
    FSignals[I].ID := g_signal_connect_data(OnWidget, Name, Callback, Self, nil, ConnectAfter)
  else
    FSignals[I].ID := g_signal_connect_data(OnWidget, Name, Callback, Self, nil, ConnectDefault);
end;

procedure TGtkHook.SetEffect(Visible: boolean);
begin
  if FEffect = Visible then Exit;
  FEffect := Visible;
  if not FDead then gtk_widget_queue_draw(FDrawWidget);
end;

function TGtkHook.Area: TRect;
var
  A: TRect;
begin
  if FOwner.Helper.Control is TWinControl then
  begin
    A := Allocation(FDrawWidget);
    Result := Rect(0, 0, A.Width, A.Height);
  end
  else
    Result := FOwner.Helper.ControlRect;
end;

function TGtkHook.Snapshot(out HotX, HotY: integer): PGdkPixbuf;
var
  R, A: TRect;
  P: TPoint;
begin
  R := Area;
  // A widget without a window of its own draws in its parent's window,
  // starting at its allocation.
  if not HasWindow(FWidget) then
  begin
    A := Allocation(FWidget);
    OffsetRect(R, A.Left, A.Top);
  end;
  P := TCrossDragDropSource(FOwner.Helper).PressPoint;
  HotX := P.X - FOwner.Helper.ControlRect.Left;
  HotY := P.Y - FOwner.Helper.ControlRect.Top;
  if (HotX < 0) or (HotX >= R.Width) then HotX := R.Width div 2;
  if (HotY < 0) or (HotY >= R.Height) then HotY := R.Height div 2;
  {$IFDEF LCLGTK2}
  Result := gdk_pixbuf_get_from_drawable(nil, FWidget^.window, nil, R.Left, R.Top, 0, 0,
    R.Width, R.Height);
  {$ELSE}
  Result := gdk_pixbuf_get_from_window(gtk_widget_get_window(FWidget), R.Left, R.Top,
    R.Width, R.Height);
  {$ENDIF}
end;

procedure TGtkHook.Paint(cr: Pcairo_t);
const
  Dash: array[0..1] of double = (3, 3);
var
  R: TRect;
begin
  if not FEffect then Exit;
  R := Area;
  cairo_save(cr);
  if FOwner is TGtkSource then
  begin
    // Lifted away: the control fades under the window color, a dashed
    // line keeps its outline.
    SetSourceColor(cr, clForm, 0.6);
    cairo_rectangle(cr, R.Left, R.Top, R.Width, R.Height);
    cairo_fill(cr);
    SetSourceColor(cr, clWindowText, 0.5);
    cairo_set_line_width(cr, 1);
    cairo_set_dash(cr, @Dash[0], 2, 0);
    cairo_rectangle(cr, R.Left + 0.5, R.Top + 0.5, R.Width - 1, R.Height - 1);
    cairo_stroke(cr);
  end
  else
  begin
    SetSourceColor(cr, TCrossDragDropTarget(FOwner.Helper).HighlightColor, 0.15);
    cairo_rectangle(cr, R.Left, R.Top, R.Width, R.Height);
    cairo_fill(cr);
    SetSourceColor(cr, TCrossDragDropTarget(FOwner.Helper).HighlightColor, 0.9);
    cairo_set_line_width(cr, 2);
    cairo_rectangle(cr, R.Left + 1, R.Top + 1, R.Width - 2, R.Height - 2);
    cairo_stroke(cr);
  end;
  cairo_restore(cr);
end;

class procedure TGtkHook.Destroyed(Widget: PGtkWidget; Data: gpointer); cdecl;
begin
  try
    TGtkHook(Data).FDead := True;
    // Frees the owner and this hook; nothing below touches them again.
    TGtkHook(Data).FOwner.Helper.NativeLost;
  except
    Application.HandleException(nil);
  end;
end;

{$IFDEF LCLGTK2}
class function TGtkHook.Expose(Widget: PGtkWidget; Event: PGdkEventExpose;
  Data: gpointer): gboolean; cdecl;
var
  cr: Pcairo_t;
begin
  Result := False;
  if not TGtkHook(Data).FEffect then Exit;
  try
    cr := gdk_cairo_create(Event^.window);
    try
      if not HasWindow(Widget) then
        cairo_translate(cr, Widget^.allocation.x, Widget^.allocation.y);
      TGtkHook(Data).Paint(cr);
    finally
      cairo_destroy(cr);
    end;
  except
    Application.HandleException(nil);
  end;
end;
{$ELSE}
class function TGtkHook.Draw(Widget: PGtkWidget; cr: Pcairo_t; Data: gpointer): gboolean; cdecl;
begin
  Result := False;
  try
    TGtkHook(Data).Paint(cr);
  except
    Application.HandleException(nil);
  end;
end;
{$ENDIF}

{ TGtkSource }

constructor TGtkSource.Create(AHelper: TCrossDragDropHelper);
begin
  inherited Create(AHelper);
  FFailed := -1;
  FHook := TGtkHook.Create(Self);
  FHook.Connect('drag-begin', TGCallback(@DragBegin));
  FHook.Connect('drag-end', TGCallback(@DragEnd));
  FHook.Connect('drag-failed', TGCallback(@DragFailed));
  FHook.Connect('drag-data-get', TGCallback(@DataGet));
end;

destructor TGtkSource.Destroy;
begin
  FHook.Free;
  inherited Destroy;
end;

function TGtkSource.Source: TCrossDragDropSource;
begin
  Result := TCrossDragDropSource(Helper);
end;

function TGtkSource.Start: boolean;
var
  Event: PGdkEvent;
  List: PGtkTargetList;
begin
  Result := False;
  if FHook.Dead then Exit;
  Event := gtk_get_current_event;
  if Event = nil then Exit;
  List := gtk_target_list_new(nil, 0);
  try
    if Source.HasText then gtk_target_list_add_text_targets(List, TextInfo);
    if Source.HasFiles then gtk_target_list_add_uri_targets(List, FilesInfo);
    {$IFDEF LCLGTK2}
    Result := gtk_drag_begin(FHook.Widget, List, CopyAction, 1, Event) <> nil;
    {$ELSE}
    Result := gtk_drag_begin_with_coordinates(FHook.Widget, List, CopyAction, 1, Event,
      -1, -1) <> nil;
    {$ENDIF}
  finally
    gtk_target_list_unref(List);
    gdk_event_free(Event);
  end;
end;

function TGtkSource.PastThreshold(const From, Current: TPoint): boolean;
begin
  Result := gtk_drag_check_threshold(FHook.Widget, From.X, From.Y, Current.X, Current.Y);
end;

procedure TGtkSource.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

class procedure TGtkSource.DragBegin(Widget: PGtkWidget; Context: PGdkDragContext;
  Data: gpointer); cdecl;
var
  Self_: TGtkSource;
  Icon: PGdkPixbuf;
  HotX, HotY: integer;
begin
  Self_ := SourceOf(Data);
  try
    Self_.FFailed := -1;
    Icon := Self_.FHook.Snapshot(HotX, HotY);
    if Icon <> nil then
    begin
      gtk_drag_set_icon_pixbuf(Context, Icon, HotX, HotY);
      g_object_unref(Icon);
    end
    else
      gtk_drag_set_icon_default(Context);
    Self_.Source.NativeBegan;
  except
    Application.HandleException(nil);
  end;
end;

class procedure TGtkSource.DragEnd(Widget: PGtkWidget; Context: PGdkDragContext;
  Data: gpointer); cdecl;
var
  Self_: TGtkSource;
  Outcome: TCrossDragDropOutcome;
begin
  Self_ := SourceOf(Data);
  try
    // Wayland does not set the succeeded flag by drag-end; the action the
    // target settled on says the same thing there.
    case Self_.FFailed of
      -1: if gdk_drag_drop_succeeded(Context) or ActionChosen(Context) then Outcome := cdoDropped
        else
          Outcome := cdoRejected;
      ResultNoTarget: Outcome := cdoRejected;
      ResultUserCanceled: Outcome := cdoCanceled;
      else
        Outcome := cdoFailed;
    end;
    Self_.FFailed := -1;
    Self_.Source.NativeEnded(Outcome);
  except
    Application.HandleException(nil);
  end;
end;

class function TGtkSource.DragFailed(Widget: PGtkWidget; Context: PGdkDragContext;
  Reason: TDragResult; Data: gpointer): gboolean; cdecl;
begin
  // True: no snap-back animation; the outcome is reported in drag-end.
  Result := True;
  SourceOf(Data).FFailed := Ord(Reason);
end;

class procedure TGtkSource.DataGet(Widget: PGtkWidget; Context: PGdkDragContext;
  Selection: PGtkSelectionData; Info, Time: guint; Data: gpointer); cdecl;
var
  Offer: TCrossDragDropSource;
begin
  Offer := SourceOf(Data).Source;
  try
    if Info = TextInfo then
      gtk_selection_data_set_text(Selection, PChar(Offer.Text), Length(Offer.Text))
    else if Info = FilesInfo then
      {$IFDEF LCLGTK2}
      gtk_selection_data_set(Selection, Selection^.target, 8, Pguchar(PChar(Offer.URIs)),
        Length(Offer.URIs));
      {$ELSE}
      gtk_selection_data_set(Selection, gtk_selection_data_get_target(Selection), 8,
        Pguint8(PChar(Offer.URIs)), Length(Offer.URIs));
      {$ENDIF}
  except
    Application.HandleException(nil);
  end;
end;

{ TGtkTarget }

constructor TGtkTarget.Create(AHelper: TCrossDragDropHelper);
var
  All: PGtkTargetList;
  SignalID: guint;
begin
  inherited Create(AHelper);
  FHook := TGtkHook.Create(Self);
  FTextList := gtk_target_list_new(nil, 0);
  gtk_target_list_add_text_targets(FTextList, TextInfo);
  FFilesList := gtk_target_list_new(nil, 0);
  gtk_target_list_add_uri_targets(FFilesList, FilesInfo);
  // The LCL's own receive callback treats every payload as a file list
  // for OnDropFiles and finishes the drag; it is held back while this
  // target is attached.
  SignalID := g_signal_lookup('drag-data-received', gtk_widget_get_type);
  {$IFDEF LCLGTK2}
  FBlocked := g_signal_handler_find(FHook.Widget, G_SIGNAL_MATCH_ID or G_SIGNAL_MATCH_DATA,
    SignalID, 0, nil, nil, Helper.NativeControl);
  {$ELSE}
  FBlocked := g_signal_handler_find(FHook.Widget, [G_SIGNAL_MATCH_ID, G_SIGNAL_MATCH_DATA],
    SignalID, 0, nil, nil, Pointer(Helper.NativeControl.Handle));
  {$ENDIF}
  if FBlocked <> 0 then g_signal_handler_block(FHook.Widget, FBlocked);
  FHook.Connect('drag-motion', TGCallback(@Motion));
  FHook.Connect('drag-leave', TGCallback(@Leave));
  FHook.Connect('drag-drop', TGCallback(@Drop));
  FHook.Connect('drag-data-received', TGCallback(@Received));
  {$IFDEF LCLGTK2}
  gtk_drag_dest_set(FHook.Widget, 0, nil, 0, CopyAction);
  {$ELSE}
  gtk_drag_dest_set(FHook.Widget, [], nil, 0, CopyAction);
  {$ENDIF}
  All := gtk_target_list_new(nil, 0);
  gtk_target_list_add_text_targets(All, TextInfo);
  gtk_target_list_add_uri_targets(All, FilesInfo);
  gtk_drag_dest_set_target_list(FHook.Widget, All);
  gtk_target_list_unref(All);
end;

destructor TGtkTarget.Destroy;
begin
  if FPending <> nil then
  begin
    gtk_drag_finish(FPending, False, False, GDK_CURRENT_TIME);
    g_object_unref(FPending);
  end;
  if not FHook.Dead then
  begin
    gtk_drag_dest_unset(FHook.Widget);
    if FBlocked <> 0 then g_signal_handler_unblock(FHook.Widget, FBlocked);
  end;
  gtk_target_list_unref(FTextList);
  gtk_target_list_unref(FFilesList);
  FHook.Free;
  inherited Destroy;
end;

function TGtkTarget.Target: TCrossDragDropTarget;
begin
  Result := TCrossDragDropTarget(Helper);
end;

procedure TGtkTarget.ShowEffect(Visible: boolean);
begin
  FHook.SetEffect(Visible);
end;

function TGtkTarget.Offered(Context: PGdkDragContext): TCrossDragDropFormats;
begin
  Result := [];
  if PtrUInt(gtk_drag_dest_find_target(FHook.Widget, Context, FTextList)) <> 0 then
    Include(Result, cdfText);
  if PtrUInt(gtk_drag_dest_find_target(FHook.Widget, Context, FFilesList)) <> 0 then
    Include(Result, cdfFiles);
end;

function TGtkTarget.Decide(Context: PGdkDragContext; X, Y: integer;
  out Chosen: TCrossDragDropFormat): boolean;
begin
  Result := Target.Accepts(Offered(Context), AllowsCopy(Context), X, Y, Chosen);
end;

class function TGtkTarget.Motion(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
  Time: guint; Data: gpointer): gboolean; cdecl;
var
  Chosen: TCrossDragDropFormat;
begin
  Result := True;
  try
    if TargetOf(Data).Decide(Context, X, Y, Chosen) then
      gdk_drag_status(Context, CopyAction, Time)
    else
      gdk_drag_status(Context, NoAction, Time);
  except
    gdk_drag_status(Context, NoAction, Time);
    Application.HandleException(nil);
  end;
end;

class procedure TGtkTarget.Leave(Widget: PGtkWidget; Context: PGdkDragContext; Time: guint;
  Data: gpointer); cdecl;
begin
  try
    TargetOf(Data).Target.Leave;
  except
    Application.HandleException(nil);
  end;
end;

class function TGtkTarget.Drop(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
  Time: guint; Data: gpointer): gboolean; cdecl;
var
  Self_: TGtkTarget;
  Chosen: TCrossDragDropFormat;
  Atom: TAtom;
begin
  Result := False;
  Self_ := TargetOf(Data);
  try
    if (Self_.FPending <> nil) or not Self_.Decide(Context, X, Y, Chosen) then Exit;
    if Chosen = cdfText then
      Atom := gtk_drag_dest_find_target(Widget, Context, Self_.FTextList)
    else
      Atom := gtk_drag_dest_find_target(Widget, Context, Self_.FFilesList);
    Self_.FPending := Context;
    Self_.FPendingFormat := Chosen;
    g_object_ref(Context);
    gtk_drag_get_data(Widget, Context, Atom, Time);
    Result := True;
  except
    Application.HandleException(nil);
  end;
end;

class procedure TGtkTarget.Received(Widget: PGtkWidget; Context: PGdkDragContext; X, Y: gint;
  Selection: PGtkSelectionData; Info, Time: guint; Data: gpointer); cdecl;
var
  Self_: TGtkTarget;
  Success: boolean;
  Value: string;
  Text: PChar;
  Len: integer;
begin
  Self_ := TargetOf(Data);
  if Context <> Self_.FPending then Exit;
  Success := False;
  try
    try
      {$IFDEF LCLGTK2}
      Len := Selection^.length;
      {$ELSE}
      Len := gtk_selection_data_get_length(Selection);
      {$ENDIF}
      if Len >= 0 then
        if Self_.FPendingFormat = cdfText then
        begin
          // A valid empty text selection has no buffer to convert.
          Value := '';
          if Len > 0 then
          begin
            Text := PChar(gtk_selection_data_get_text(Selection));
            if Text = nil then Exit;
            try
              Value := Text;
            finally
              g_free(Text);
            end;
          end;
          Success := Self_.Target.DeliverText(Value, X, Y);
        end
        else
        begin
          {$IFDEF LCLGTK2}
          SetString(Value, PChar(Selection^.data), Len);
          {$ELSE}
          SetString(Value, PChar(gtk_selection_data_get_data(Selection)), Len);
          {$ENDIF}
          Success := Self_.Target.DeliverURIs(Value, X, Y);
        end;
    except
      Application.HandleException(nil);
    end;
  finally
    gtk_drag_finish(Context, Success, False, Time);
    g_object_unref(Self_.FPending);
    Self_.FPending := nil;
  end;
end;

initialization
  NativeSourceClass := TGtkSource;
  NativeTargetClass := TGtkTarget;

{$ENDIF}

end.
