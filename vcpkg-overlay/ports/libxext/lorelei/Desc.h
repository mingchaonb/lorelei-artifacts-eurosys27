#pragma once

extern "C" {
#include <X11/Xlib.h>
#include <X11/extensions/EVI.h>
#include <X11/extensions/MITMisc.h>
#include <X11/extensions/XShm.h>
#include <X11/extensions/Xag.h>
#include <X11/extensions/Xcup.h>
#include <X11/extensions/Xdbe.h>
#include <X11/extensions/Xext.h>
#include <X11/extensions/Xge.h>
#include <X11/extensions/XLbx.h>
#include <X11/extensions/XEVI.h>
#include <X11/extensions/dpms.h>
#include <X11/extensions/multibuf.h>
#include <X11/extensions/security.h>
#include <X11/extensions/shape.h>
#include <X11/extensions/sync.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wregister"
#include <X11/extensions/xtestext1.h>
#pragma clang diagnostic pop

typedef struct _XExtensionInfo XExtensionInfo;
typedef struct _XExtDisplayInfo XExtDisplayInfo;
typedef struct _XExtensionHooks XExtensionHooks;

XExtensionInfo *XextCreateExtension(void);
void XextDestroyExtension(XExtensionInfo *info);
XExtDisplayInfo *XextAddDisplay(XExtensionInfo *extinfo, Display *dpy,
                               _Xconst char *ext_name,
                               XExtensionHooks *hooks, int nevents,
                               XPointer data);
int XextRemoveDisplay(XExtensionInfo *extinfo, Display *dpy);
XExtDisplayInfo *XextFindDisplay(XExtensionInfo *extinfo, Display *dpy);
}

#ifdef Success
#undef Success
#endif

#include <lorelei/ThunkInterface/Proc.h>
