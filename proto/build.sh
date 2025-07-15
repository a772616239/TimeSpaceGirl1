#!/bin/sh
##########################
## generate java code
##########################
find ./protos |grep proto | while read line
do
    protoc $line --java_out=../java  --proto_path=./protos --proto_path=./protos/command --proto_path=./protos/indication --proto_path==./protos/request --proto_path=./protos/response
done


