# System libGL validation

This recipe uses the installed libglvnd DSOs. The `glvnd` overlay port does not build or copy libglvnd. Its CMake project generates and installs separate legacy GL, direct GLX, and X11 thunk packs, native and x86_64 validation programs, `ThunkDB.json`, and TLC audit output into the vcpkg package tree. The evaluation script only installs that port, runs the packaged programs, and collects evidence.

The tests create a GLX pbuffer context on the active X server, resolve OpenGL functions through `glXGetProcAddressARB`, write through a mapped GL buffer, and exercise the OpenGL debug callback when the driver exposes it. One executable links only the legacy `libGL.so.1` entry point. The other carries direct `DT_NEEDED` entries for both `libGLX.so.0` and `libGL.so.1`, which verifies the standalone GLX forward thunk. The port depends on `libx11[hlr]` and packages the matching X11 thunk alongside both graphics thunks.
