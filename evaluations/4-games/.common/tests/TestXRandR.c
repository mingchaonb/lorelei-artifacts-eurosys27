#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>

int main(void) {
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        return 2;
    }
    Window root = RootWindow(display, DefaultScreen(display));
    int min_width = 0;
    int min_height = 0;
    int max_width = 0;
    int max_height = 0;
    Status range_status =
        XRRGetScreenSizeRange(display, root, &min_width, &min_height, &max_width, &max_height);
    XRRScreenConfiguration *config = XRRGetScreenInfo(display, root);
    int size_count = -1;
    XRRScreenSize *sizes = config ? XRRConfigSizes(config, &size_count) : NULL;
    Rotation rotation = 0;
    SizeID current = config ? XRRConfigCurrentConfiguration(config, &rotation) : 0;
    short rate = config ? XRRConfigCurrentRate(config) : 0;
    XRRScreenResources *resources = XRRGetScreenResourcesCurrent(display, root);
    printf("screen=%dx%d range=%d:%dx%d-%dx%d sizes=%d current=%u:%dx%d@%d resources=%d:%d:%d\n",
           DisplayWidth(display, DefaultScreen(display)),
           DisplayHeight(display, DefaultScreen(display)), range_status, min_width, min_height,
           max_width, max_height, size_count, current,
           sizes && current < size_count ? sizes[current].width : 0,
           sizes && current < size_count ? sizes[current].height : 0, rate,
           resources ? resources->ncrtc : -1, resources ? resources->noutput : -1,
           resources ? resources->nmode : -1);
    if (resources) {
        XRRFreeScreenResources(resources);
    }
    if (config) {
        XRRFreeScreenConfigInfo(config);
    }
    XCloseDisplay(display);
    return 0;
}
