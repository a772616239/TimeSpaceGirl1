#!/bin/sh
##########################
## generate c code
##########################

find ./protos |grep "\.proto" | while read line
do
	filename=$(basename $line .proto)
	protoc --proto_path=./protos --proto_path=./protos/command --proto_path=./protos/indication --proto_path==./protos/request --proto_path=./protos/response --descriptor_set_out ./pb_out/$filename.pb $line
   
done
