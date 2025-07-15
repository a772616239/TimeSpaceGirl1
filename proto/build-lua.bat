@echo off

set cdy=%cd%

set protocExe=%cdy%\tools\protoc-2.5.0-win32\protoc.exe
set protocGenLua=%cdy%\tools\protoc-gen-lua\plugin\protoc-gen-lua.bat
set protoluaOut=%cdy%\lua_out
set _protoSrc=%cdy%\protos\


cd %cdy%\protos\

for /r  %%i in (*.proto)do (
	%protocExe%  --proto_path=%_protoSrc% --plugin=protoc-gen-lua=%protocGenLua% --lua_out=%protoluaOut% %%i 
	echo %protoluaOut%\%%~ni.lua--ok!
)
pause