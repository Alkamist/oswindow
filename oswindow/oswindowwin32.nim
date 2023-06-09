{.experimental: "overloadableEnums".}
{.experimental: "codeReordering".}

import std/unicode
import std/times
import opengl
import ./common; export common
import ./win32api

type
  OsWindow* = ref OsWindowObj
  OsWindowObj* = object
    userData*: pointer
    onFrame*: proc(window: OsWindow)
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
    onTextInput*: proc(window: OsWindow, text: string)
    onDpiChange*: proc(window: OsWindow, dpi: float)
    isOpen*: bool
    isDecorated*: bool
    isHovered*: bool
    childStatus*: ChildStatus

    m_backgroundColor: tuple[r, g, b: uint8]
    m_cursorX: int
    m_cursorY: int
    m_hwnd: HWND
    m_hdc: HDC
    m_hglrc: HGLRC
    m_sizeMoveTimerId: UINT_PTR

var windowCount = 0
const windowClassName = "DefaultWindowClass"

proc `=destroy`*(window: var OsWindowObj) =
  if window.isOpen:
    window.isOpen = false
    DestroyWindow(window.m_hwnd)

proc new*(_: typedesc[OsWindow], parentHandle: pointer = nil): OsWindow =
  result = OsWindow()

  var hinstance = GetModuleHandleA(nil)

  if windowCount == 0:
    var windowClass = WNDCLASSEXA(
      cbSize: UINT(sizeof(WNDCLASSEXA)),
      style: CS_OWNDC,
      lpfnWndProc: windowProc,
      hInstance: hinstance,
      # hCursor: LoadCursorA(nil, IDC_ARROW),
      hCursor: nil,
      lpszClassName: windowClassName,
    )
    RegisterClassExA(addr(windowClass))

  var windowStyle = WS_OVERLAPPEDWINDOW
  if parentHandle != nil:
    result.childStatus = Floating
    windowStyle = windowStyle or int(WS_POPUP)

  result.m_hwnd = CreateWindowExA(
    0,
    windowClassName,
    nil,
    DWORD(windowStyle),
    cint(CW_USEDEFAULT),
    cint(CW_USEDEFAULT),
    cint(CW_USEDEFAULT),
    cint(CW_USEDEFAULT),
    GetDesktopWindow(),
    nil,
    hinstance,
    cast[pointer](result),
  )
  if result.m_hwnd == nil:
    echo "Failed to open window."

  result.isOpen = true
  result.isDecorated = true
  (result.m_cursorX, result.m_cursorY) = result.cursorPosition

  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

  initOpenGlContext(result)

  windowCount += 1

proc processFrame*(window: OsWindow) =
  if window.isOpen:
    window.makeContextCurrent()
    let (width, height) = window.size
    glViewport(0, 0, int32(width), int32(height))
    let (r, g, b) = window.m_backgroundColor
    glClearColor(float(r) / 255, float(g) / 255, float(b) / 255, 1.0)
    glClear(GL_COLOR_BUFFER_BIT)
    if window.onFrame != nil:
      window.onFrame(window)

proc run*(window: OsWindow) =
  while window.isOpen:
    window.pollEvents()
    window.processFrame()

proc close*(window: OsWindow) =
  if window.isOpen:
    window.isOpen = false
    DestroyWindow(window.m_hwnd)

proc pollEvents*(window: OsWindow) =
  if window.childStatus == None:
    var msg: MSG
    while PeekMessageA(addr(msg), window.m_hwnd, 0, 0, PM_REMOVE) != FALSE:
      TranslateMessage(addr(msg))
      DispatchMessageA(addr(msg))

proc swapBuffers*(window: OsWindow) =
  SwapBuffers(window.m_hdc)

proc makeContextCurrent*(window: OsWindow) =
  wglMakeCurrent(window.m_hdc, window.m_hglrc)

proc setBackgroundColor*(window: OsWindow, r, g, b: float) =
  window.m_backgroundColor = (uint8(r * 255), uint8(g * 255), uint8(b * 255))

proc setCursorStyle*(window: OsWindow, style: CursorStyle) =
  SetCursor(LoadCursorA(nil, style.toWin32CursorStyle))

proc time*(window: OsWindow): float =
  cpuTime()

proc cursorPosition*(window: OsWindow): (int, int) =
  var pos: POINT
  if GetCursorPos(addr(pos)) == TRUE:
    ScreenToClient(window.m_hwnd, addr(pos))
    return (int(pos.x), int(pos.y))

proc position*(window: OsWindow): (int, int) =
  var pos: POINT
  ClientToScreen(window.m_hwnd, addr(pos))
  return (int(pos.x), int(pos.y))

proc setPosition*(window: OsWindow, x, y: int) =
  SetWindowPos(
    window.m_hwnd, nil,
    int32(x), int32(y),
    0, 0,
    SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOSIZE,
  )

proc size*(window: OsWindow): (int, int) =
  var area: RECT
  GetClientRect(window.m_hwnd, addr(area))
  return (int(area.right), int(area.bottom))

proc setSize*(window: OsWindow, width, height: int) =
  SetWindowPos(
    window.m_hwnd, nil,
    0, 0,
    int32(width), int32(height),
    SWP_NOACTIVATE or SWP_NOOWNERZORDER or SWP_NOMOVE or SWP_NOZORDER,
  )

proc dpi*(window: OsWindow): float =
  return float(GetDpiForWindow(window.m_hwnd))

proc setDecorated*(window: OsWindow, decorated: bool) =
  window.isDecorated = decorated

proc embedInsideWindow*(window: OsWindow, parent: pointer) =
  if window.childStatus != Embedded:
    SetWindowLongPtrA(
      window.m_hwnd,
      GWL_STYLE,
      WS_CHILDWINDOW or WS_CLIPSIBLINGS,
    )
    window.childStatus = Embedded
    window.setDecorated(false)
    var (x, y) = window.position()
    var (width, height) = window.size()
    SetWindowPos(
      window.m_hwnd,
      HWND_TOPMOST,
      int32(x), int32(y),
      int32(width), int32(height),
      SWP_SHOWWINDOW,
    )
  SetParent(window.m_hwnd, cast[HWND](parent))

proc show*(window: OsWindow) =
  ShowWindow(window.m_hwnd, SW_SHOW)

proc hide*(window: OsWindow) =
  ShowWindow(window.m_hwnd, SW_HIDE)

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

  window.m_hdc = GetDC(window.m_hwnd)
  SetPixelFormat(
    window.m_hdc,
    ChoosePixelFormat(window.m_hdc, addr(pfd)),
    addr(pfd),
  )

  window.m_hglrc = wglCreateContext(window.m_hdc)
  wglMakeCurrent(window.m_hdc, window.m_hglrc)

  opengl.loadExtensions()

  ReleaseDC(window.m_hwnd, window.m_hdc)

proc windowProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM): LRESULT {.stdcall.} =
  if msg == WM_CREATE:
    var lpcs = cast[LPCREATESTRUCTA](lparam)
    SetWindowLongPtrA(hwnd, GWLP_USERDATA, cast[LONG_PTR](lpcs.lpCreateParams))

  var window = cast[OsWindow](GetWindowLongPtrA(hwnd, GWLP_USERDATA))
  if window == nil or hwnd != window.m_hwnd:
    return DefWindowProcA(hwnd, msg, wparam, lparam)

  case msg:

  # of WM_PAINT:
  #   # var ps: PAINTSTRUCT
  #   # let hdc = BeginPaint(window.m_hwnd, addr(ps))
  #   # FillRect(hdc, &ps.rcPaint, (HBRUSH) (COLOR_WINDOW+1))
  #   window.processFrame()
  #   # EndPaint(window.m_hwnd, addr(ps))
  #   return 0

  of WM_ENTERSIZEMOVE:
    window.m_sizeMoveTimerId = SetTimer(window.m_hwnd, 1, USER_TIMER_MINIMUM, nil)

  of WM_EXITSIZEMOVE:
    KillTimer(window.m_hwnd, window.m_sizeMoveTimerId)

  of WM_TIMER:
    if (wParam == window.m_sizeMoveTimerId):
      window.processFrame()

  of WM_MOVE:
    if window.onMove != nil:
      window.onMove(
        window,
        int(GET_X_LPARAM(lparam)),
        int(GET_Y_LPARAM(lparam)),
      )

  of WM_SIZE:
    if window.onResize != nil:
      window.onResize(
        window,
        int(LOWORD(cast[DWORD](lparam))),
        int(HIWORD(cast[DWORD](lparam))),
      )

  of WM_CLOSE:
    window.close()

  of WM_DESTROY:
    window.makeContextCurrent()
    if window.onClose != nil:
      window.onClose(window)
    if windowCount > 0:
      windowCount -= 1
      if windowCount == 0:
        UnregisterClassA(windowClassName, nil)

  of WM_DPICHANGED:
    if window.onDpiChange != nil:
      window.onDpiChange(window, float(GetDpiForWindow(window.m_hwnd)))

  of WM_MOUSEMOVE:
    window.setCursorStyle(Arrow)

    window.m_cursorX = int(GET_X_LPARAM(lparam))
    window.m_cursorY = int(GET_Y_LPARAM(lparam))

    if not window.isHovered:
      var tme: TTRACKMOUSEEVENT
      tme.cbSize = DWORD(sizeof(tme))
      tme.dwFlags = TME_LEAVE
      tme.hwndTrack = window.m_hwnd
      TrackMouseEvent(addr(tme))
      window.isHovered = true
      if window.onMouseEnter != nil:
        window.onMouseEnter(window, window.m_cursorX, window.m_cursorY)

    if window.onMouseMove != nil:
      window.onMouseMove(window, window.m_cursorX, window.m_cursorY)

  of WM_MOUSELEAVE:
      window.isHovered = false
      if window.onMouseExit != nil:
        window.onMouseExit(window, window.m_cursorX, window.m_cursorY)

  of WM_MOUSEWHEEL:
    if window.onMouseWheel != nil:
      window.onMouseWheel(
        window,
        0,
        float(GET_WHEEL_DELTA_WPARAM(wparam)) / WHEEL_DELTA,
      )

  of WM_MOUSEHWHEEL:
    if window.onMouseWheel != nil:
      window.onMouseWheel(
        window,
        float(GET_WHEEL_DELTA_WPARAM(wparam)) / WHEEL_DELTA,
        0,
      )

  of WM_LBUTTONDOWN, WM_LBUTTONDBLCLK,
     WM_MBUTTONDOWN, WM_MBUTTONDBLCLK,
     WM_RBUTTONDOWN, WM_RBUTTONDBLCLK,
     WM_XBUTTONDOWN, WM_XBUTTONDBLCLK:
    window.m_cursorX = int(GET_X_LPARAM(lparam))
    window.m_cursorY = int(GET_Y_LPARAM(lparam))
    SetCapture(window.m_hwnd)
    if window.onMousePress != nil:
      window.onMousePress(window, toMouseButton(msg, wparam), window.m_cursorX, window.m_cursorY)

  of WM_LBUTTONUP, WM_MBUTTONUP, WM_RBUTTONUP, WM_XBUTTONUP:
    window.m_cursorX = int(GET_X_LPARAM(lparam))
    window.m_cursorY = int(GET_Y_LPARAM(lparam))
    ReleaseCapture()
    if window.onMouseRelease != nil:
      window.onMouseRelease(window, toMouseButton(msg, wparam), window.m_cursorX, window.m_cursorY)

  of WM_KEYDOWN, WM_SYSKEYDOWN:
    if window.on_key_press != nil:
      window.on_key_press(window, toKeyboardKey(wparam, lparam))

  of WM_KEYUP, WM_SYSKEYUP:
    if window.onKeyRelease != nil:
      window.onKeyRelease(window, toKeyboardKey(wparam, lparam))

  of WM_CHAR, WM_SYSCHAR:
    if wparam > 0 and wparam < 0x10000:
      if window.onTextInput != nil:
        window.onTextInput(window, $cast[Rune](wparam))

  of WM_ERASEBKGND:
    let hdc = cast[HDC](wparam)
    var clientRect: RECT
    GetClientRect(window.m_hwnd, addr(clientRect))
    let (r, g, b) = window.m_backgroundColor
    FillRect(hdc, addr(clientRect), CreateSolidBrush(RGB(r, g, b)))

  of WM_NCCALCSIZE:
    if not window.isDecorated:
      return 0

  else:
    discard

  return DefWindowProcA(hwnd, msg, wparam, lparam)

proc toWin32CursorStyle(style: CursorStyle): LPSTR =
  return case style:
    of Arrow: IDC_ARROW
    of IBeam: IDC_IBEAM
    of Crosshair: IDC_CROSS
    of PointingHand: IDC_HAND
    of ResizeLeftRight: IDC_SIZEWE
    of ResizeTopBottom: IDC_SIZENS
    of ResizeTopLeftBottomRight: IDC_SIZENWSE
    of ResizeTopRightBottomLeft: IDC_SIZENESW

func toMouseButton(msg: UINT, wParam: WPARAM): MouseButton =
  return case msg:
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
  return case scanCode:
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