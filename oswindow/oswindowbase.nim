{.experimental: "overloadableEnums".}

const densityPixelDpi* = 96.0

type
  MouseCursorStyle* = enum
    Arrow
    IBeam
    Crosshair
    PointingHand
    ResizeLeftRight
    ResizeTopBottom
    ResizeTopLeftBottomRight
    ResizeTopRightBottomLeft

  MouseButton* = enum
    Unknown,
    Left, Middle, Right,
    Extra1, Extra2, Extra3,
    Extra4, Extra5,

  KeyboardKey* = enum
    Unknown,
    A, B, C, D, E, F, G, H, I,
    J, K, L, M, N, O, P, Q, R,
    S, T, U, V, W, X, Y, Z,
    Key1, Key2, Key3, Key4, Key5,
    Key6, Key7, Key8, Key9, Key0,
    Pad1, Pad2, Pad3, Pad4, Pad5,
    Pad6, Pad7, Pad8, Pad9, Pad0,
    F1, F2, F3, F4, F5, F6, F7,
    F8, F9, F10, F11, F12,
    Backtick, Minus, Equal, Backspace,
    Tab, CapsLock, Enter, LeftShift,
    RightShift, LeftControl, RightControl,
    LeftAlt, RightAlt, LeftMeta, RightMeta,
    LeftBracket, RightBracket, Space,
    Escape, Backslash, Semicolon, Quote,
    Comma, Period, Slash, ScrollLock,
    Pause, Insert, End, PageUp, Delete,
    Home, PageDown, LeftArrow, RightArrow,
    DownArrow, UpArrow, NumLock, PadDivide,
    PadMultiply, PadSubtract, PadAdd, PadEnter,
    PadPeriod, PrintScreen,

  OsWindowState* = object
    isOpen*: bool
    isFloatingChild*: bool
    isEmbeddedChild*: bool
    isHovered*: bool
    wasHovered*: bool
    xPixels*: int
    yPixels*: int
    previousXPixels*: int
    previousYPixels*: int
    widthPixels*: int
    heightPixels*: int
    previousWidthPixels*: int
    previousHeightPixels*: int
    time*: float
    previousTime*: float
    pixelDensity*: float
    previousPixelDensity*: float
    mouseXPixels*: int
    mouseYPixels*: int
    previousMouseXPixels*: int
    previousMouseYPixels*: int
    mouseWheelX*: float
    mouseWheelY*: float
    mousePresses*: seq[MouseButton]
    mouseReleases*: seq[MouseButton]
    mouseIsDown*: array[MouseButton, bool]
    keyPresses*: seq[KeyboardKey]
    keyReleases*: seq[KeyboardKey]
    keyIsDown*: array[KeyboardKey, bool]
    textInput*: string

template defineOsWindowBaseProcs*(T: typedesc): untyped {.dirty.} =
  proc initState*(window: T, time: float) =
    window.state = OsWindowState(
      time: time,
      previousTime: time,
      pixelDensity: 1.0,
      previousPixelDensity: 1.0,
    )

  proc updateState*(window: T, time: float) =
    window.state.wasHovered = window.state.isHovered
    window.state.previousXPixels = window.state.xPixels
    window.state.previousYPixels = window.state.yPixels
    window.state.previousWidthPixels = window.state.widthPixels
    window.state.previousHeightPixels = window.state.heightPixels
    window.state.previousTime = window.state.time
    window.state.previousPixelDensity = window.state.pixelDensity
    window.state.previousMouseXPixels = window.state.mouseXPixels
    window.state.previousMouseYPixels = window.state.mouseYPixels
    window.state.mouseWheelX = 0.0
    window.state.mouseWheelY = 0.0
    window.state.textInput = ""
    window.state.mousePresses.setLen(0)
    window.state.mouseReleases.setLen(0)
    window.state.keyPresses.setLen(0)
    window.state.keyReleases.setLen(0)
    window.state.time = time

  proc isOpen*(window: T): bool = window.state.isOpen
  proc isFloatingChild*(window: T): bool = window.state.isFloatingChild
  proc isEmbeddedChild*(window: T): bool = window.state.isEmbeddedChild
  proc isHovered*(window: T): bool = window.state.isHovered
  proc xPixels*(window: T): int = window.state.xPixels
  proc yPixels*(window: T): int = window.state.yPixels
  proc widthPixels*(window: T): int = window.state.widthPixels
  proc heightPixels*(window: T): int = window.state.heightPixels
  proc time*(window: T): float = window.state.time
  proc pixelDensity*(window: T): float = window.state.pixelDensity
  proc mouseXPixels*(window: T): int = window.state.mouseXPixels
  proc mouseYPixels*(window: T): int = window.state.mouseYPixels
  proc mouseWheelX*(window: T): float = window.state.mouseWheelX
  proc mouseWheelY*(window: T): float = window.state.mouseWheelY
  proc mousePresses*(window: T): seq[MouseButton] = window.state.mousePresses
  proc mouseReleases*(window: T): seq[MouseButton] = window.state.mouseReleases
  proc mouseIsDown*(window: T, button: MouseButton): bool = window.state.mouseIsDown[button]
  proc keyPresses*(window: T): seq[KeyboardKey] = window.state.keyPresses
  proc keyReleases*(window: T): seq[KeyboardKey] = window.state.keyReleases
  proc keyIsDown*(window: T, key: KeyboardKey): bool = window.state.keyIsDown[key]
  proc textInput*(window: T): string = window.state.textInput

  proc justMoved*(window: T): bool = window.state.xPixels != window.state.previousXPixels or window.state.yPixels != window.state.previousYPixels
  proc x*(window: T): float = window.state.xPixels.float / window.state.pixelDensity
  proc y*(window: T): float = window.state.yPixels.float / window.state.pixelDensity

  proc justResized*(window: T): bool = window.state.widthPixels != window.state.previousWidthPixels or window.state.heightPixels != window.state.previousHeightPixels
  proc width*(window: T): float = window.state.widthPixels.float / window.state.pixelDensity
  proc height*(window: T): float = window.state.heightPixels.float / window.state.pixelDensity

  proc deltaTime*(window: T): float = window.state.time - window.state.previousTime

  proc pixelDensityChanged*(window: T): bool = window.state.pixelDensity != window.state.previousPixelDensity
  proc scale*(window: T): float = 1.0 / window.state.pixelDensity
  proc aspectRatio*(window: T): float = window.state.widthPixels / window.state.heightPixels

  proc mouseJustMoved*(window: T): bool = window.state.mouseXPixels != window.state.previousMouseXPixels or window.state.mouseYPixels != window.state.previousMouseYPixels
  proc mouseWheelJustMoved*(window: T): bool = window.state.mouseWheelX != 0.0 or window.state.mouseWheelY != 0.0
  proc mouseJustPressed*(window: T, button: MouseButton): bool = button in window.state.mousePresses
  proc mouseJustReleased*(window: T, button: MouseButton): bool = button in window.state.mouseReleases
  proc anyMouseJustPressed*(window: T): bool = window.state.mousePresses.len > 0
  proc anyMouseJustReleased*(window: T): bool = window.state.mouseReleases.len > 0
  proc keyJustPressed*(window: T, key: KeyboardKey): bool = key in window.state.keyPresses
  proc keyJustReleased*(window: T, key: KeyboardKey): bool = key in window.state.keyReleases
  proc anyKeyJustPressed*(window: T): bool = window.state.keyPresses.len > 0
  proc anyKeyJustReleased*(window: T): bool = window.state.keyReleases.len > 0

  proc mouseEntered*(window: T): bool = window.state.isHovered and not window.state.wasHovered
  proc mouseExited*(window: T): bool = window.state.wasHovered and not window.state.isHovered