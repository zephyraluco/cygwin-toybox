#include <X11/Xlib.h>
#include <stdio.h>

int main(void)
{
  Display *display = XOpenDisplay(NULL);
  if (!display) return 1;
  int screen = DefaultScreen(display);
  Window window = XCreateSimpleWindow(display, RootWindow(display, screen),
      0, 0, 64, 64, 0, BlackPixel(display, screen), WhitePixel(display, screen));
  XMapWindow(display, window);
  GC gc = XCreateGC(display, window, 0, NULL);
  XDrawLine(display, window, gc, 0, 0, 63, 63);
  XSync(display, False);
  XWindowAttributes attributes;
  int ok = XGetWindowAttributes(display, window, &attributes)
      && attributes.width == 64 && attributes.height == 64;
  XFreeGC(display, gc);
  XDestroyWindow(display, window);
  XCloseDisplay(display);
  if (ok) puts("X11 client smoke test passed");
  return ok ? 0 : 1;
}
