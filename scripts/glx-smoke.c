#include <X11/Xlib.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <stdio.h>

int main(void)
{
  Display *display = XOpenDisplay(NULL);
  if (!display) { fputs("Cannot open X display\n", stderr); return 1; }
  int major, minor, error, event;
  if (!glXQueryExtension(display, &error, &event)
      || !glXQueryVersion(display, &major, &minor)) {
    fputs("GLX extension unavailable\n", stderr); return 1;
  }
  int attributes[] = {GLX_RGBA, GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8,
      GLX_BLUE_SIZE, 8, None};
  XVisualInfo *visual = glXChooseVisual(display, DefaultScreen(display), attributes);
  if (!visual) { fputs("No GLX RGBA visual\n", stderr); return 1; }
  /* Use a pixmap to avoid undefined reads from an unmapped/occluded window.
     The separate X11 smoke test covers native window creation and mapping. */
  Pixmap pixmap = XCreatePixmap(display, RootWindow(display, visual->screen),
      64, 64, visual->depth);
  GLXPixmap drawable = glXCreateGLXPixmap(display, visual, pixmap);
  /* False explicitly requests indirect GLX, as used across SSH forwarding. */
  GLXContext context = glXCreateContext(display, visual, NULL, False);
  if (!drawable || !context || !glXMakeCurrent(display, drawable, context)) {
    fputs("Cannot create or bind indirect GLX context\n", stderr); return 1;
  }
  if (glXIsDirect(display, context)) {
    fputs("Unexpected direct GLX context\n", stderr); return 1;
  }
  const GLubyte *version = glGetString(GL_VERSION);
  const GLubyte *renderer = glGetString(GL_RENDERER);
  if (!version || !renderer) { fputs("No OpenGL renderer\n", stderr); return 1; }
  printf("GLX %d.%d; indirect=yes; OpenGL=%s; renderer=%s\n",
      major, minor, version, renderer);
  glViewport(0, 0, 64, 64);
  glDrawBuffer(GL_FRONT);
  glReadBuffer(GL_FRONT);
  glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  glFinish();
  unsigned char pixel[4] = {0};
  glReadPixels(32, 32, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  GLenum status = glGetError();
  int ok = status == GL_NO_ERROR && pixel[0] > 200
      && pixel[1] < 40 && pixel[2] < 40;
  printf("GLX pixel readback: %u,%u,%u,%u; GL error=%u\n",
      pixel[0], pixel[1], pixel[2], pixel[3], (unsigned)status);
  glXMakeCurrent(display, None, NULL);
  glXDestroyContext(display, context);
  glXDestroyGLXPixmap(display, drawable);
  XFreePixmap(display, pixmap);
  XFree(visual);
  XCloseDisplay(display);
  if (!ok) return 1;
  puts("Indirect GLX rendering smoke test passed");
  return 0;
}
