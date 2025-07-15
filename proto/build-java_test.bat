@echo off

set protoExe=%cd%\tools\protoc-2.5.0-win32\protoc.exe
set _protoSrc=D:\jmfy_msy\protocol\protos\

set cdy=%cd%
cd..
set get=%cd%
set protoOut=D:\jmfy_msy\test_netty\test_1\src


cd D:\jmfy_msy\protocol\protos

for /r  %%i in (*.proto)do (
echo %%i===============
	%protoExe%  --proto_path=%_protoSrc% --proto_path=%_protoSrc%command  --proto_path=%_protoSrc%indication  --proto_path=%_protoSrc%request  --proto_path=%_protoSrc%response  --java_out=%protoOut%  %%i
)
pause 



