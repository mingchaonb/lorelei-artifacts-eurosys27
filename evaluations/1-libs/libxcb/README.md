# libxcb 1.15 validation

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

`tests/TestXcb.c` is a directed native and Hecate smoke workload for the Ubuntu 24.04 libxcb core port. It connects to a real X server, reads the setup record, allocates an XID, creates and maps a window, performs a checked request, obtains a reply, and destroys the window.

Run it with `./evaluations/1-libs/libxcb/run.sh`. The recipe keeps packages, vcpkg build trees, generated thunks, and test executables below `.work/evaluations/libxcb`. The runner inherits `DISPLAY` and `XAUTHORITY` from its current environment. To select another graphical session, set `GUI_ENV` to a file containing both variables.

The workload also transfers socket ownership with `xcb_take_socket`. Its next request forces libxcb to return the socket through a guest callback. Success requires both the callback closure counter and the guest-global callback counter to equal one.

The first Spark development smoke run used `DISPLAY=:1` and `/run/user/1004/gdm/Xauthority`. Native and Hecate lanes both printed `xcb:11:0:1:1:3` and exited with status zero. Formal recipe runs record their own environment and summary below `results` or `reference-results`.
