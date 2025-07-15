#!/bin/sh
##########################
## generate lua code
##########################

find ./protos |grep "\.proto" | while read line
do
	echo $line
	protoc --proto_path=./protos --proto_path=./protos/command --proto_path=./protos/indication --proto_path==./protos/request --proto_path=./protos/response --plugin=protoc-gen-lua=./tools/protoc-gen-lua/plugin/protoc-gen-lua --lua_out=./lua_out $line
   
done



