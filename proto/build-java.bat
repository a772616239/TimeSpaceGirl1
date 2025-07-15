@echo off

set protoExe=%cd%\tools\protoc-2.5.0-win32\protoc.exe
set _protoSrc=C:\ljsd_msy\protocol_jieling\protos\

set cdy=%cd%
cd..
set get=%cd%
set protoOut=C:\ljsd_msy\jieling-server\serverlogic\src\main\java

cd C:\ljsd_msy\protocol_jieling\protos

for /r  %%i in (*.proto)do (
echo %%i===============
	%protoExe%  --proto_path=%_protoSrc%  --java_out=%protoOut%  %%i
)
pause 



