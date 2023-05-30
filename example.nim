import std/strformat
import oswindow

var window = OsWindow.new()
window.setBackgroundColor(0.2, 0, 0)
window.show()

window.onFrame = proc(window: OsWindow) =
  discard

window.onClose = proc(window: OsWindow) =
  echo "Window closed"

window.onMove = proc(window: OsWindow, x, y: int) =
  echo &"Window moved: {x}, {y}"

window.onResize = proc(window: OsWindow, width, height: int) =
  echo &"Window resized: {width}, {height}"

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

window.onTextInput = proc(window: OsWindow, text: string) =
  echo &"Text typed: {text}"

# window.onScaleChange = proc(window: OsWindow, scale: float) =
#   echo &"Scale changed: {scale}"

window.run()