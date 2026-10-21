# Roadmap

The two components, the GTK2/GTK3, Qt5 and Win32 backends, the package and
two demo programs exist. They pass the two-process checks on X11, on native
Wayland and on Windows 10, with the fade, the highlight and the drag image. Results per
desktop are in [the platform matrix](docs/PLATFORMS.md).

## Next

- [ ] Cocoa backend: NSDraggingSource and NSDraggingDestination, checked
      in the macOS guest.
- [ ] Check the help comments in the Object Inspector.
- [ ] Drag to and from a file manager and a text editor on each Linux
      desktop (done on Windows with Explorer and WordPad).
- [ ] Build and check 32-bit Windows.
- [ ] Qt6, once a Qt6 LCL and Qt6Pas are installed somewhere to test.

## Known limits

- One target per native window. A TLabel or TImage target uses its
  parent's window, so two label targets in one panel, or a panel target
  with a label target inside it, are refused with an error that names
  the other one.
- A form with AllowDropFiles set should not also have a target on the
  form itself; the two take the same native hook.
- Qt reports Rejected for a canceled drag as well; it does not say which.
- On Qt each drag gets a new drag object that stays with the control
  until the control is freed: Qt keeps referring to a finished one, and
  deleting or reusing it stalls the next drag.
- Once, the first drag after the windows appeared was reported as
  rejected on Qt X11 although the data arrived. Two reruns did not show
  it again.
- Cocoa builds compile, report Supported = False and send one OnError
  when a helper attaches.
- On Windows a window that other code already registered for OLE drops,
  such as a rich edit, cannot also take a target.

## Parked

HTML, images, separate URL formats, custom formats and cursors, move and
link, generated files, autoscroll and tree or list adapters wait for a
real use.
