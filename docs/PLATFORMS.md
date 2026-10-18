# Platform matrix

The GTK2/GTK3 and Qt5 backends are complete and tested through the real
components. Other rows remain targets.

| Operating system | LCL widgetset | Display/architecture goal | Status |
|---|---|---|---|
| Linux | GTK3 | Native Wayland, x86_64 | Tested: components and effects in the KDE guest |
| Linux | GTK3 | X11, x86_64 | Tested: components, demos, lifetime, effects, in Xephyr |
| Linux | GTK2 | X11, x86_64 | Tested: components, lifetime, effects, in Xephyr |
| Linux | Qt5 | X11 and native Wayland, checked separately | Tested: components and effects, both backends, in the KDE guest |
| Linux | Qt6 | X11 and native Wayland, checked separately | Planned; test guest lacks Qt6Pas and Qt6 LCL units |
| Windows | Win32 | x86 and x86_64, checked separately | Backend planned; x86_64 demos build and run, report unsupported |
| macOS | Cocoa | Intel x86_64 | Backend planned; demos build and run in the guest, report unsupported |
| macOS | Cocoa | Apple Silicon aarch64 | Planned; test environment not established |
| BSD desktops | GTK/Qt as available | Assess portability and native peers | Planned; test environment not established |
| Other LCL targets | As available | Inspect native drag support | Not assessed |

Native Wayland, X11 and XWayland results must remain distinct. Identify
the actual Qt platform plugin or GDK backend used, rather than inferring
it only from the desktop session environment.

For each checked combination record the source revision, compiler and
Lazarus versions, OS, architecture, backend, peer applications, acceptance
checks and remaining gaps. Use tested, build-only, planned or unsupported
explicitly. Initial availability does not imply every architecture or
widgetset on that OS is covered.

## Before the components

Native feasibility probes for GTK2, GTK3 and Qt5 came first, on X11 and
native Wayland, and settled how gestures, clicks and the LCL's own
file-drop handler coexist. The components replaced them; their results
match the component results below.

## Component checks on GTK2 and GTK3, X11

The probe (tests/componentprobe.lpr) builds a window from
TCrossDragDropSource and TCrossDragDropTarget and runs eight gestures
between two processes. Both widgetsets passed the Unicode
and empty text phases: exact text and file paths, format choice and
fallback, two plain clicks, movement under the threshold, a nonwindowed
label source, a rejected half, Escape, and a drag after the cancel. The
outcomes reported to OnDragEnd were four drops, one rejection and one
cancel. Screenshots taken while hovering show the faded source and the
framed target; the verifier compares those pixels against the final shot.
The lifetime check passed on both with heaptrc reporting no leaks. The
host toolchain was FPC 3.3.1 and LCL 5.99 on Linux x86_64.

## Component checks on GTK3, native Wayland

The same component probe ran in the dedicated KDE Plasma guest with
`GDK_BACKEND=wayland`; both processes logged `GdkWaylandDisplay` (GTK
3.24.52, host-built executable with FPC 3.3.1 and LCL 5.99). Both phases
passed: exact text and files, gestures, four drops, one rejection and one
cancel. Two differences from X11 are built into the backend and the
verifier. GDK does not set its drop-succeeded flag by drag-end on Wayland,
so the source also reads the action the target settled on; and GTK sends
drag-leave before the data arrives, so the target's highlight is already
off when OnDropText or OnDropFiles runs. A program on Wayland cannot learn
its windows' screen positions, so the screenshot pixel check is skipped
there and the hover screenshot is inspected by eye: the source button was
faded under its dashed outline and the target framed, with the desktop's
own copy cursor. The compositor's screenshot did not show the drag image;
whether the snapshot icon appears on Wayland is not established.

## Component checks on Qt5, X11 and native Wayland

Built in the KDE guest with its FPC 3.2.2, Lazarus 4.4 and Qt5Pas. The
X11 run in Xephyr confirmed the `xcb` platform plugin in both processes,
the native run the `wayland` plugin. Both phases passed on each: exact
text and files, gestures, four drops, and the two drags that end without
a drop, which Qt reports as rejected since it does not tell a cancel
apart. The lifetime check passed on both plugins. Three things were
learned on the way and are built in: a Qt drag must start from inside the
mouse event that moves the pointer, before the LCL handles it, so the Qt
unit reads the gesture in its event filter; a drag object that has
finished must be left alone, since deleting it or running it again stalls
the next drag; and nothing may be painted from an event filter or shown
and hidden while a drag starts, so the effects are a picture on a label
that stays in place. The screenshot pixel check needs ImageMagick, which
the guest does not have; the hover screenshots show the faded source,
the framed target and the snapshot under the pointer on X11.

Since 17 Oct the probe runs one phase with Unicode text: empty text now
means "offer no text" and starts no drag, so the empty-text phase of the
runs above no longer applies.

## Windows and macOS without a backend (17 Oct 2026)

Both demos were cross-built on the Linux host for Windows x86_64 (FPC
3.3.1, LCL 5.99, Win32 widgetset) as GUI executables and run in the
Windows 10 guest, and built in the macOS Sequoia guest with its Lazarus
4.8 and FPC 3.2.4 for Cocoa and run there. On both the forms open, every
helper sends one OnError, and the demos show "Native drag and drop is
not available on this widgetset yet." The package and the lifetime check
also built for Cocoa. No drag was attempted; there is nothing to drag
with until the backends exist.

