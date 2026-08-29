#include <X11/Xlib.h>
#include <X11/Xresource.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    KeySym escape = XStringToKeysym("Escape");
    const char *name = XKeysymToString(escape);
    XrmInitialize();
    XrmQuark quark = XrmStringToQuark("hecate.x11");
    const char *roundtrip = XrmQuarkToString(quark);
    if (escape == NoSymbol || !name || strcmp(name, "Escape") != 0 || !roundtrip ||
        strcmp(roundtrip, "hecate.x11") != 0) {
        return 1;
    }
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        return 2;
    }
    int glx_opcode = 0;
    int glx_event = 0;
    int glx_error = 0;
    if (!XQueryExtension(display, "GLX", &glx_opcode, &glx_event, &glx_error)) {
        XCloseDisplay(display);
        return 7;
    }
    XIM im = XOpenIM(display, NULL, NULL, NULL);
    if (!im) {
        XCloseDisplay(display);
        return 3;
    }
    XIMStyles *styles = NULL;
    char *failed = XGetIMValues(im, XNQueryInputStyle, &styles, NULL);
    if (failed || !styles || styles->count_styles == 0) {
        XCloseIM(im);
        XCloseDisplay(display);
        return 4;
    }
    Window window = DefaultRootWindow(display);
    XIMStyle style = styles->supported_styles[0];
    XIC ic = XCreateIC(im, XNInputStyle, style, XNClientWindow, window, NULL);
    if (!ic) {
        XFree(styles);
        XCloseIM(im);
        XCloseDisplay(display);
        return 5;
    }
    XIMStyle returned_style = 0;
    failed = XGetICValues(ic, XNInputStyle, &returned_style, NULL);
    XPoint point = {.x = 3, .y = 7};
    XVaNestedList nested = XVaCreateNestedList(0, XNSpotLocation, &point, NULL);
    if (failed || returned_style != style || !nested) {
        XDestroyIC(ic);
        XFree(styles);
        XCloseIM(im);
        XCloseDisplay(display);
        return 6;
    }
    XFree(nested);
    XDestroyIC(ic);
    XFree(styles);
    XCloseIM(im);
    XCloseDisplay(display);
    printf("x11:%lu:%s:%s:%lu:glx=%d\n", (unsigned long)escape, name, roundtrip,
           (unsigned long)returned_style, glx_opcode);
    return 0;
}
