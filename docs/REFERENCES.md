# Reference documentation

These describe native protocols and comparable public APIs. Their feature
sets do not expand the component's scope.
No implementation code is included from these references.

* [WinForms drag-and-drop overview](https://learn.microsoft.com/en-us/dotnet/desktop/winforms/input-mouse/drag-and-drop)
* [WPF drag-and-drop overview](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/drag-and-drop-overview)
* [Qt drag-and-drop overview](https://doc.qt.io/qt-6/dnd.html)
* [Qt QDrag](https://doc.qt.io/qt-6/qdrag.html)
* [Qt QMimeData](https://doc.qt.io/qt-6/qmimedata.html)
* [Qt QObject event filters](https://doc.qt.io/qt-6/qobject.html#installEventFilter)
* [GTK3 drag source configuration](https://docs.gtk.org/gtk3/method.Widget.drag_source_set.html)
* [GTK3 explicit drag initiation](https://docs.gtk.org/gtk3/method.Widget.drag_begin_with_coordinates.html)
* [GTK3 destination format matching](https://docs.gtk.org/gtk3/method.Widget.drag_dest_find_target.html)
* [GTK3 drag data received](https://docs.gtk.org/gtk3/signal.Widget.drag-data-received.html)
* [GTK3 drag motion](https://docs.gtk.org/gtk3/signal.Widget.drag-motion.html)
* [GTK3 drag failure reporting](https://docs.gtk.org/gtk3/signal.Widget.drag-failed.html)
* [Wayland data-device protocol](https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_data_device)
* [Win32 DoDragDrop](https://learn.microsoft.com/en-us/windows/win32/api/ole2/nf-ole2-dodragdrop)
* [Win32 IDropTarget](https://learn.microsoft.com/en-us/windows/win32/api/oleidl/nn-oleidl-idroptarget)
* [Win32 IDragSourceHelper](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idragsourcehelper)
* [Win32 SHCreateDataObject](https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/nf-shlobj_core-shcreatedataobject)
* [Win32 SetWindowSubclass](https://learn.microsoft.com/en-us/windows/win32/api/commctrl/nf-commctrl-setwindowsubclass)
* [Apple NSDraggingSource](https://developer.apple.com/documentation/appkit/nsdraggingsource)
* [Apple NSDraggingDestination](https://developer.apple.com/documentation/appkit/nsdraggingdestination)
* [wxPython drag-and-drop overview](https://docs.wxpython.org/dnd_overview.html)

Inspect the matching Free Pascal and Lazarus sources for existing types,
format helpers, event hooks and widgetset interfaces before introducing
new routines. Use official platform documentation to resolve native
ownership and completion behavior.
