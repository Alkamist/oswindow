if defined(emscripten):
  --os:linux
  --cpu:wasm32
  --cc:clang

  when defined(windows):
    --clang.exe:emcc.bat
    --clang.linkerexe:emcc.bat
    --clang.cpp.exe:emcc.bat
    --clang.cpp.linkerexe:emcc.bat
  else:
    --clang.exe:emcc
    --clang.linkerexe:emcc
    --clang.cpp.exe:emcc
    --clang.cpp.linkerexe:emcc

  --listCmd
  --gc:arc
  --exceptions:goto
  --define:noSignalHandler

  switch("passL", "-o bin/index.html --shell-file shell_minimal.html")