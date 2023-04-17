{.experimental: "overloadableEnums".}

import opengl
import std/unicode
import std/times
import winim/lean
import ./oswindowbase; export oswindowbase

const WM_DPICHANGED* = 0x02E0
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4

proc SetProcessDpiAwarenessContext*(value: int): BOOL {.discardable, stdcall, dynlib: "user32", importc.}
proc GetDpiForWindow*(hWnd: HWND): UINT {.discardable, stdcall, dynlib: "user32", importc.}

type
  OsWindow* = ref object
    state*: OsWindowState
    onFrame*: proc()
    handle*: pointer
    hdc: HDC
    hglrc: HGLRC

proc `=destroy`*(window: var type OsWindow()[]) =
  if window.state.isOpen:
    window.state.isOpen = false
    DestroyWindow(cast[HWND](window.handle))

defineOsWindowBaseProcs(OsWindow)

template hwnd(window: OsWindow): HWND =
  cast[HWND](window.handle)

proc windowProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.}

const windowClassName = "Default Window Class"
var windowCount = 0

proc initOpenGlContext(window: OsWindow) =
  var pfd = PIXELFORMATDESCRIPTOR(
    nSize: sizeof(PIXELFORMATDESCRIPTOR).WORD,
    nVersion: 1,
    dwFlags: PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_SUPPORT_COMPOSITION or PFD_DOUBLEBUFFER,
    iPixelType: PFD_TYPE_RGBA,
    cColorBits: 32,
    cRedBits: 0, cRedShift: 0,
    cGreenBits: 0, cGreenShift: 0,
    cBlueBits: 0, cBlueShift: 0,
    cAlphaBits: 0, cAlphaShift: 0,
    cAccumBits: 0,
    cAccumRedBits: 0,
    cAccumGreenBits: 0,
    cAccumBlueBits: 0,
    cAccumAlphaBits: 0,
    cDepthBits: 32,
    cStencilBits: 8,
    cAuxBuffers: 0,
    iLayerType: PFD_MAIN_PLANE,
    bReserved: 0,
    dwLayerMask: 0,
    dwVisibleMask: 0,
    dwDamageMask: 0,
  )

  let dc = GetDC(window.hwnd)
  window.hdc = dc

  let fmt = ChoosePixelFormat(dc, pfd.addr)
  SetPixelFormat(dc, fmt, pfd.addr)

  window.hglrc = wglCreateContext(dc)
  wglMakeCurrent(dc, window.hglrc)

  opengl.loadExtensions()
  var currentTexture: GLint
  glGetIntegerv(GL_TEXTURE_BINDING_2D, currentTexture.addr)

  ReleaseDC(window.hwnd, dc)

proc makeContextCurrent(window: OsWindow) =
  wglMakeCurrent(window.hdc, window.hglrc)

template updateBounds(window: OsWindow) =
  var rect: RECT
  GetClientRect(window.hwnd, rect.addr)
  ClientToScreen(window.hwnd, cast[ptr POINT](rect.left.addr))
  ClientToScreen(window.hwnd, cast[ptr POINT](rect.right.addr))
  window.state.xPixels = rect.left
  window.state.yPixels = rect.top
  window.state.widthPixels = rect.right - rect.left
  window.state.heightPixels = rect.bottom - rect.top

func toWin32MouseCursorStyle(style: MouseCursorStyle): LPTSTR =
  case style:
  of Arrow: IDC_ARROW
  of IBeam: IDC_IBEAM
  of Crosshair: IDC_CROSS
  of PointingHand: IDC_HAND
  of ResizeLeftRight: IDC_SIZEWE
  of ResizeTopBottom: IDC_SIZENS
  of ResizeTopLeftBottomRight: IDC_SIZENWSE
  of ResizeTopRightBottomLeft: IDC_SIZENESW

proc setMouseCursorStyle*(window: OsWindow, style: MouseCursorStyle) =
  SetCursor(LoadCursor(0, style.toWin32MouseCursorStyle))

proc setBackgroundColor*(window: OsWindow, r, g, b, a: float) =
  window.makeContextCurrent()
  glClearColor(r, g, b, a)

proc setPosition*(window: OsWindow, x, y: int) =
  SetWindowPos(window.hwnd, 0, x.int32, y.int32, 0, 0, SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOSIZE)

proc setSize*(window: OsWindow, width, height: int) =
  SetWindowPos(window.hwnd, 0, 0, 0, width.int32, height.int32, SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOMOVE or SWP_NOZORDER)

proc embedInsideWindow*(window: OsWindow, parent: pointer) =
  if not window.state.isEmbeddedChild:
    SetWindowLongPtr(window.hwnd, GWL_STYLE, WS_CHILDWINDOW or WS_CLIPSIBLINGS)
    window.state.isEmbeddedChild = true
  SetWindowPos(
    window.hwnd,
    HWND_TOPMOST,
    window.state.xPixels.int32, window.state.yPixels.int32,
    window.state.widthPixels.int32, window.state.heightPixels.int32,
    SWP_SHOWWINDOW,
  )
  SetParent(window.hwnd, cast[HWND](parent))

proc show*(window: OsWindow) =
  ShowWindow(window.hwnd, SW_SHOW)

proc hide*(window: OsWindow) =
  ShowWindow(window.hwnd, SW_HIDE)

proc close*(window: OsWindow) =
  if window.state.isOpen:
    window.state.isOpen = false
    DestroyWindow(window.hwnd)

template renderFrameWithoutPollingEvents(window: OsWindow): untyped {.dirty.} =
  window.makeContextCurrent()
  glClear(GL_COLOR_BUFFER_BIT)

  if window.mouseEntered:
    window.setMouseCursorStyle(Arrow)

  if window.onFrame != nil:
    window.onFrame()

  SwapBuffers(window.hdc)
  window.updateState(cpuTime())

proc process*(window: OsWindow) =
  if not (window.isFloatingChild or window.isEmbeddedChild):
    var msg: MSG
    while PeekMessage(msg, window.hwnd, 0, 0, PM_REMOVE) != 0:
      TranslateMessage(msg)
      DispatchMessage(msg)

  window.renderFrameWithoutPollingEvents()

proc newOsWindow*(parentHandle: pointer = nil): OsWindow =
  result = OsWindow()
  result.initState(cpuTime())

  if windowCount == 0:
    var windowClass = WNDCLASSEX(
      cbSize: WNDCLASSEX.sizeof.UINT,
      style: CS_OWNDC,
      lpfnWndProc: windowProc,
      cbClsExtra: 0,
      cbWndExtra: 0,
      hInstance: GetModuleHandle(nil),
      hIcon: 0,
      hCursor: 0,
      hbrBackground: CreateSolidBrush(RGB(0, 0, 0)),
      lpszMenuName: nil,
      lpszClassName: windowClassName,
      hIconSm: 0,
    )
    RegisterClassEx(windowClass)

  result.state.isFloatingChild = parentHandle != nil
  var windowStyle = WS_OVERLAPPEDWINDOW or WS_VISIBLE
  if result.state.isFloatingChild:
    windowStyle = windowStyle or WS_POPUP

  let hwnd = CreateWindow(
    lpClassName = windowClassName,
    lpWindowName = "",
    dwStyle = windowStyle.int32,
    x = 0,
    y = 0,
    nWidth = 800,
    nHeight = 600,
    hWndParent = if result.state.isFloatingChild: cast[HWND](parentHandle) else: GetDesktopWindow(),
    hMenu = 0,
    hInstance = GetModuleHandle(nil),
    lpParam = cast[pointer](result),
  )
  result.state.isOpen = true
  result.handle = cast[pointer](hwnd)

  discard SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

  result.updateBounds()
  result.setMouseCursorStyle(Arrow)

  result.initOpenGlContext()
  result.makeContextCurrent()

  inc windowCount

func toMouseButton(msg: UINT, wParam: WPARAM): MouseButton =
  case msg:
  of WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK:
    MouseButton.Left
  of WM_MBUTTONDOWN, WM_MBUTTONUP, WM_MBUTTONDBLCLK:
    MouseButton.Middle
  of WM_RBUTTONDOWN, WM_RBUTTONUP, WM_RBUTTONDBLCLK:
    MouseButton.Right
  of WM_XBUTTONDOWN, WM_XBUTTONUP, WM_XBUTTONDBLCLK:
    if HIWORD(wParam) == 1:
      MouseButton.Extra1
    else:
      MouseButton.Extra2
  else:
    MouseButton.Unknown

func toKeyboardKey(wParam: WPARAM, lParam: LPARAM): KeyboardKey =
  let scanCode = LOBYTE(HIWORD(lParam))
  let isRight = (HIWORD(lParam) and KF_EXTENDED) == KF_EXTENDED
  case scanCode:
    of 42: KeyboardKey.LeftShift
    of 54: KeyboardKey.RightShift
    of 29:
      if isRight: KeyboardKey.RightControl else: KeyboardKey.LeftControl
    of 56:
      if isRight: KeyboardKey.RightAlt else: KeyboardKey.LeftAlt
    else:
      case wParam.int:
      of 8: KeyboardKey.Backspace
      of 9: KeyboardKey.Tab
      of 13: KeyboardKey.Enter
      of 19: KeyboardKey.Pause
      of 20: KeyboardKey.CapsLock
      of 27: KeyboardKey.Escape
      of 32: KeyboardKey.Space
      of 33: KeyboardKey.PageUp
      of 34: KeyboardKey.PageDown
      of 35: KeyboardKey.End
      of 36: KeyboardKey.Home
      of 37: KeyboardKey.LeftArrow
      of 38: KeyboardKey.UpArrow
      of 39: KeyboardKey.RightArrow
      of 40: KeyboardKey.DownArrow
      of 45: KeyboardKey.Insert
      of 46: KeyboardKey.Delete
      of 48: KeyboardKey.Key0
      of 49: KeyboardKey.Key1
      of 50: KeyboardKey.Key2
      of 51: KeyboardKey.Key3
      of 52: KeyboardKey.Key4
      of 53: KeyboardKey.Key5
      of 54: KeyboardKey.Key6
      of 55: KeyboardKey.Key7
      of 56: KeyboardKey.Key8
      of 57: KeyboardKey.Key9
      of 65: KeyboardKey.A
      of 66: KeyboardKey.B
      of 67: KeyboardKey.C
      of 68: KeyboardKey.D
      of 69: KeyboardKey.E
      of 70: KeyboardKey.F
      of 71: KeyboardKey.G
      of 72: KeyboardKey.H
      of 73: KeyboardKey.I
      of 74: KeyboardKey.J
      of 75: KeyboardKey.K
      of 76: KeyboardKey.L
      of 77: KeyboardKey.M
      of 78: KeyboardKey.N
      of 79: KeyboardKey.O
      of 80: KeyboardKey.P
      of 81: KeyboardKey.Q
      of 82: KeyboardKey.R
      of 83: KeyboardKey.S
      of 84: KeyboardKey.T
      of 85: KeyboardKey.U
      of 86: KeyboardKey.V
      of 87: KeyboardKey.W
      of 88: KeyboardKey.X
      of 89: KeyboardKey.Y
      of 90: KeyboardKey.Z
      of 91: KeyboardKey.LeftMeta
      of 92: KeyboardKey.RightMeta
      of 96: KeyboardKey.Pad0
      of 97: KeyboardKey.Pad1
      of 98: KeyboardKey.Pad2
      of 99: KeyboardKey.Pad3
      of 100: KeyboardKey.Pad4
      of 101: KeyboardKey.Pad5
      of 102: KeyboardKey.Pad6
      of 103: KeyboardKey.Pad7
      of 104: KeyboardKey.Pad8
      of 105: KeyboardKey.Pad9
      of 106: KeyboardKey.PadMultiply
      of 107: KeyboardKey.PadAdd
      of 109: KeyboardKey.PadSubtract
      of 110: KeyboardKey.PadPeriod
      of 111: KeyboardKey.PadDivide
      of 112: KeyboardKey.F1
      of 113: KeyboardKey.F2
      of 114: KeyboardKey.F3
      of 115: KeyboardKey.F4
      of 116: KeyboardKey.F5
      of 117: KeyboardKey.F6
      of 118: KeyboardKey.F7
      of 119: KeyboardKey.F8
      of 120: KeyboardKey.F9
      of 121: KeyboardKey.F10
      of 122: KeyboardKey.F11
      of 123: KeyboardKey.F12
      of 144: KeyboardKey.NumLock
      of 145: KeyboardKey.ScrollLock
      of 186: KeyboardKey.Semicolon
      of 187: KeyboardKey.Equal
      of 188: KeyboardKey.Comma
      of 189: KeyboardKey.Minus
      of 190: KeyboardKey.Period
      of 191: KeyboardKey.Slash
      of 192: KeyboardKey.Backtick
      of 219: KeyboardKey.LeftBracket
      of 220: KeyboardKey.BackSlash
      of 221: KeyboardKey.RightBracket
      of 222: KeyboardKey.Quote
      else: KeyboardKey.Unknown

proc windowProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  if msg == WM_CREATE:
    var lpcs = cast[LPCREATESTRUCT](lParam)
    SetWindowLongPtr(hwnd, GWLP_USERDATA, cast[LONG_PTR](lpcs.lpCreateParams))

  let window = cast[OsWindow](GetWindowLongPtr(hwnd, GWLP_USERDATA))
  if window == nil or hwnd != window.hwnd:
    return DefWindowProc(hwnd, msg, wParam, lParam)

  case msg:

  # of WM_SETFOCUS:
  #   window.state.isFocused = true

  # of WM_KILLFOCUS:
  #   window.state.isFocused = false

  of WM_MOVE:
    window.updateBounds()
    window.renderFrameWithoutPollingEvents()

  of WM_SIZE:
    window.updateBounds()
    window.renderFrameWithoutPollingEvents()

  # of WM_ENTERSIZEMOVE:
  #   window.platform.moveTimer = SetTimer(window.hwnd, 1, USER_TIMER_MINIMUM, nil)

  # of WM_EXITSIZEMOVE:
  #   KillTimer(window.hwnd, window.platform.moveTimer)

  # of WM_TIMER:
  #   if wParam == window.platform.moveTimer:
  #     window.processFrame:
  #       window.updateBounds()

  # of WM_WINDOWPOSCHANGED:
  #   window.processFrame(cpuTime()):
  #     window.updateBounds()
  #   return 0

  of WM_CLOSE:
    window.close()

  of WM_DESTROY:
    dec windowCount
    windowCount = windowCount.max(0)
    if windowCount == 0:
      UnregisterClass(windowClassName, 0)

  of WM_DPICHANGED:
    window.state.pixelDensity = GetDpiForWindow(window.hwnd).float / densityPixelDpi
    window.updateBounds()

  of WM_MOUSEMOVE:
    if not window.state.isHovered:
      var tme: TTRACKMOUSEEVENT
      ZeroMemory(tme.addr, sizeof(tme))
      tme.cbSize = sizeof(tme).cint
      tme.dwFlags = TME_LEAVE
      tme.hwndTrack = window.hwnd
      TrackMouseEvent(tme.addr)
      window.state.isHovered = true

    window.state.mouseXPixels = GET_X_LPARAM(lParam).int
    window.state.mouseYPixels = GET_Y_LPARAM(lParam).int
    window.renderFrameWithoutPollingEvents()

  of WM_MOUSELEAVE:
    window.state.isHovered = false

  of WM_MOUSEWHEEL:
    window.state.mouseWheelY += GET_WHEEL_DELTA_WPARAM(wParam).float / WHEEL_DELTA.float
    window.renderFrameWithoutPollingEvents()

  of WM_MOUSEHWHEEL:
    window.state.mouseWheelX += GET_WHEEL_DELTA_WPARAM(wParam).float / WHEEL_DELTA.float
    window.renderFrameWithoutPollingEvents()

  of WM_LBUTTONDOWN, WM_LBUTTONDBLCLK,
     WM_MBUTTONDOWN, WM_MBUTTONDBLCLK,
     WM_RBUTTONDOWN, WM_RBUTTONDBLCLK,
     WM_XBUTTONDOWN, WM_XBUTTONDBLCLK:
    SetCapture(window.hwnd)
    let button = toMouseButton(msg, wParam)
    window.state.mousePresses.add button
    window.state.mouseIsDown[button] = true

  of WM_LBUTTONUP, WM_MBUTTONUP, WM_RBUTTONUP, WM_XBUTTONUP:
    ReleaseCapture()
    let button = toMouseButton(msg, wParam)
    window.state.mouseReleases.add button
    window.state.mouseIsDown[button] = false

  of WM_KEYDOWN, WM_SYSKEYDOWN:
    let key = toKeyboardKey(wParam, lParam)
    window.state.keyPresses.add key
    window.state.keyIsDown[key] = true

  of WM_KEYUP, WM_SYSKEYUP:
    let key = toKeyboardKey(wParam, lParam)
    window.state.keyReleases.add key
    window.state.keyIsDown[key] = false

  of WM_CHAR, WM_SYSCHAR:
    if wParam > 0 and wParam < 0x10000:
      window.state.textInput &= cast[Rune](wParam).toUTF8

  # of WM_NCCALCSIZE:
  #   return 0

  # of WM_NCHITTEST:
  #   const topBorder = 27
  #   const bottomBorder = 8
  #   const leftBorder = 8
  #   const rightBorder = 8

  #   var m = POINT(x: GET_X_LPARAM(lParam).int32, y: GET_Y_LPARAM(lParam).int32)
  #   var w: RECT
  #   GetWindowRect(hWnd, w.addr)

  #   var frame = RECT()
  #   AdjustWindowRectEx(frame.addr, WS_OVERLAPPEDWINDOW and not WS_CAPTION, false, 0)

  #   var row = 1
  #   var col = 1
  #   var onResizeBorder = false

  #   if m.y >= w.top and m.y < w.top + topBorder:
  #     onResizeBorder = m.y < (w.top - frame.top)
  #     row = 0
  #   elif m.y < w.bottom and m.y >= w.bottom - bottomBorder:
  #     row = 2

  #   if m.x >= w.left and m.x < w.left + leftBorder:
  #     col = 0
  #   elif m.x < w.right and m.x >= w.right - rightBorder:
  #     col = 2

  #   let hitTests = [
  #     [HTTOPLEFT, if onResizeBorder: HTTOP else: HTCAPTION, HTTOPRIGHT],
  #     [HTLEFT, HTCLIENT, HTRIGHT],
  #     [HTBOTTOMLEFT, HTBOTTOM, HTBOTTOMRIGHT],
  #   ]

  #   return hitTests[row][col]

  else:
    discard

  DefWindowProc(hwnd, msg, wParam, lParam)