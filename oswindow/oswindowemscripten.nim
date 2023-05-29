{.experimental: "overloadableEnums".}
{.experimental: "codeReordering".}

import ./common; export common
import ./emscriptenapi

const canvas = "canvas.emscripten"

{.passL: "-s EXPORTED_RUNTIME_METHODS=ccall".}
{.passL: "-s EXPORTED_FUNCTIONS=_main,_onMousePress,_onMouseRelease,_onMouseMove".}

emscripten_run_script("""
function dispatchMousePress(e) {
  Module.ccall("onMousePress", null, ["number", "number", "number"], [e.button, e.clientX, e.clientY]);
}
function dispatchMouseRelease(e) {
  Module.ccall("onMouseRelease", null, ["number", "number", "number"], [e.button, e.clientX, e.clientY]);
}
function dispatchMouseMove(e) {
  Module.ccall("onMouseMove", null, ["number", "number"], [e.clientX, e.clientY]);
}
window.addEventListener("mousedown", dispatchMousePress);
window.addEventListener("mouseup", dispatchMouseRelease);
window.addEventListener("mousemove", dispatchMouseMove);
""")

{.emit: """
#include <emscripten/em_js.h>
EM_JS(int, getWindowWidth, (), {
  return window.innerWidth;
});
EM_JS(int, getWindowHeight, (), {
  return window.innerHeight;
});
EM_JS(double, getDpi, (), {
  return window.devicePixelRatio * 96.0;
});
EM_JS(void, setCursorImage, (const char* cursorName), {
  document.body.style.cursor = UTF8ToString(cursorName);
});
""".}

proc getWindowWidth(): cint {.importc, nodecl.}
proc getWindowHeight(): cint {.importc, nodecl.}
proc getDpi(): cdouble {.importc, nodecl.}
proc setCursorImage(cursorName: cstring) {.importc, nodecl.}

type
  OsWindow* = ref OsWindowObj
  OsWindowObj* = object
    userData*: pointer
    onClose*: proc(window: OsWindow)
    onMove*: proc(window: OsWindow, x, y: int)
    onResize*: proc(window: OsWindow, width, height: int)
    onMouseMove*: proc(window: OsWindow, x, y: int)
    onMousePress*: proc(window: OsWindow, button: MouseButton, x, y: int)
    onMouseRelease*: proc(window: OsWindow, button: MouseButton, x, y: int)
    onMouseEnter*: proc(window: OsWindow, x, y: int)
    onMouseExit*: proc(window: OsWindow, x, y: int)
    onMouseWheel*: proc(window: OsWindow, x, y: float)
    onKeyPress*: proc(window: OsWindow, key: KeyboardKey)
    onKeyRelease*: proc(window: OsWindow, key: KeyboardKey)
    onRune*: proc(window: OsWindow, r: Rune)
    onDpiChange*: proc(window: OsWindow, dpi: float)
    isOpen*: bool
    isDecorated*: bool
    isHovered*: bool
    childStatus*: ChildStatus

    m_onFrame*: proc(window: OsWindow)
    m_webGlContext*: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE

var mainWindow: OsWindow

proc new*(_: typedesc[OsWindow], parentHandle: pointer = nil): OsWindow =
  mainWindow = OsWindow()
  GcRef(mainWindow)

  let (width, height) = mainWindow.size
  discard emscripten_set_canvas_element_size(canvas, cint(width), cint(height))

  mainWindow.createWebGlContext()
  mainWindow.makeContextCurrent()

  discard emscripten_set_resize_callback(EMSCRIPTEN_EVENT_TARGET_WINDOW, cast[pointer](mainWindow), EM_BOOL(false), onResize)

  return mainWindow

proc run*(window: OsWindow, onFrame: proc(window: OsWindow)) =
  window.m_onFrame = onFrame
  emscripten_request_animation_frame_loop(mainLoop, cast[pointer](window))

proc close*(window: OsWindow) =
  discard

proc pollEvents*(window: OsWindow) =
  discard

proc swapBuffers*(window: OsWindow) =
  discard

proc makeContextCurrent*(window: OsWindow) =
  discard emscripten_webgl_make_context_current(window.m_webGlContext)

proc setCursorStyle*(window: OsWindow, style: CursorStyle) =
  setCursorImage(style.toJsCursorStyle)

proc cursorPosition*(window: OsWindow): (int, int) =
  var event: EmscriptenMouseEvent
  discard emscripten_get_mouse_status(addr(event))
  (int(event.clientX), int(event.clientY))

proc position*(window: OsWindow): (int, int) =
  (0, 0)

proc setPosition*(window: OsWindow, x, y: int) =
  discard

proc size*(window: OsWindow): (int, int) =
  (int(getWindowWidth()), int(getWindowHeight()))

proc setSize*(window: OsWindow, width, height: int) =
  discard

proc dpi*(window: OsWindow): float =
  return float(getDpi())

proc embedInsideWindow*(window: OsWindow, parent: pointer) =
  discard

proc show*(window: OsWindow) =
  discard

proc hide*(window: OsWindow) =
  discard

proc createWebGlContext(window: OsWindow) =
  var attributes: EmscriptenWebGLContextAttributes
  emscripten_webgl_init_context_attributes(addr(attributes))
  attributes.stencil = true.EM_BOOL
  attributes.depth = true.EM_BOOL
  window.m_webGlContext = emscripten_webgl_create_context(canvas, addr(attributes))

func toMouseButton(jsCode: cint): MouseButton =
  case jsCode:
  of 0: MouseButton.Left
  of 1: MouseButton.Middle
  of 2: MouseButton.Right
  of 3: MouseButton.Extra1
  of 4: MouseButton.Extra2
  else: MouseButton.Unknown

func toJsCursorStyle(style: CursorStyle): cstring =
  case style:
  of Arrow: cstring"default"
  of IBeam: cstring"text"
  of Crosshair: cstring"crosshair"
  of PointingHand: cstring"pointer"
  of ResizeLeftRight: cstring"ew-resize"
  of ResizeTopBottom: cstring"ns-resize"
  of ResizeTopLeftBottomRight: cstring"nwse-resize"
  of ResizeTopRightBottomLeft: cstring"nesw-resize"

proc mainLoop(time: cdouble, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[OsWindow](userData)
  if window.m_onFrame != nil:
    window.m_onFrame(window)
  return EM_TRUE

proc onResize(eventType: cint, uiEvent: ptr EmscriptenUiEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[OsWindow](userData)
  discard emscripten_set_canvas_element_size(canvas, uiEvent.windowInnerWidth, uiEvent.windowInnerHeight)
  if window.onResize != nil:
    window.onResize(window, uiEvent.windowInnerWidth, uiEvent.windowInnerHeight)

proc onMousePress(button: cint, x, y: cdouble) {.exportc.} =
  if mainWindow.onMousePress != nil:
    mainWindow.onMousePress(mainWindow, button.toMouseButton, int(x), int(y))

proc onMouseRelease(button: cint, x, y: cdouble) {.exportc.} =
  if mainWindow.onMouseRelease != nil:
    mainWindow.onMouseRelease(mainWindow, button.toMouseButton, int(x), int(y))

proc onMouseMove(x, y: cdouble) {.exportc.} =
  if mainWindow.onMouseMove != nil:
    mainWindow.onMouseMove(mainWindow, int(x), int(y))