import std/strformat
import oswindow
import opengl

var window = OsWindow.new()
window.show()

opengl.loadExtensions()

proc onFrame(window: OsWindow) =
  let (width, height) = window.size
  glViewport(0, 0, int32(width), int32(height))
  glClearColor(0.1, 0.1, 0.1, 1.0)
  glClear(GL_COLOR_BUFFER_BIT)
  window.swapBuffers()

window.onClose = proc(window: OsWindow) =
  echo "Window closed"

window.onMove = proc(window: OsWindow, x, y: int) =
  echo &"Window moved: {x}, {y}"

window.onResize = proc(window: OsWindow, width, height: int) =
  echo &"Window resized: {width}, {height}"
  onFrame(window)

window.onMouseMove = proc(window: OsWindow, x, y: int) =
  echo &"Mouse moved: {x}, {y}"

window.onMousePress = proc(window: OsWindow, button: MouseButton, x, y: int) =
  echo &"Mouse pressed: {button}, {x}, {y}"

window.onMouseRelease = proc(window: OsWindow, button: MouseButton, x, y: int) =
  echo &"Mouse released: {button}, {x}, {y}"

window.onMouseWheel = proc(window: OsWindow, x, y: float) =
  echo &"Mouse wheel: {x}, {y}"

window.onMouseEnter = proc(window: OsWindow, x, y: int) =
  echo &"Mouse entered: {x}, {y}"

window.onMouseExit = proc(window: OsWindow, x, y: int) =
  echo &"Mouse exited: {x}, {y}"

window.onKeyPress = proc(window: OsWindow, key: KeyboardKey) =
  echo &"Key pressed: {key}"

window.onKeyRelease = proc(window: OsWindow, key: KeyboardKey) =
  echo &"Key released: {key}"

window.onRune = proc(window: OsWindow, r: unicode.Rune) =
  echo &"Rune typed: {r}"

window.onDpiChange = proc(window: OsWindow, dpi: float) =
  echo &"Dpi changed: {dpi}"

while window.isOpen:
  window.pollEvents()
  onFrame(window)