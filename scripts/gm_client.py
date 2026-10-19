#!/usr/bin/env python3
"""极简 Thrift 客户端：直连 gameserver 的 RPCGmServerTask (idipGm)。

用法: python3 gm_client.py <cmd...>
例:   python3 gm_client.py "oneuserinfo 10000004"
"""
import sys
from thrift.protocol import TBinaryProtocol
from thrift.transport import TSocket, TTransport
from thrift.Thrift import TType, TMessageType

HOST = "127.0.0.1"
PORT = 7916


def call(cmd, host=HOST, port=PORT):
    sock = TSocket.TSocket(host, port)
    sock.setTimeout(15000)
    trans = TTransport.TBufferedTransport(sock)
    proto = TBinaryProtocol.TBinaryProtocol(trans, strictRead=True, strictWrite=True)
    trans.open()
    try:
        proto.writeMessageBegin("idipGm", TMessageType.CALL, 1)
        proto.writeStructBegin("idipGm_args")
        proto.writeFieldBegin("reserved", TType.STRING, 1)
        proto.writeString("")
        proto.writeFieldEnd()
        proto.writeFieldBegin("cmd", TType.STRING, 2)
        proto.writeString(cmd)
        proto.writeFieldEnd()
        proto.writeFieldStop()
        proto.writeStructEnd()
        proto.writeMessageEnd()
        trans.flush()

        name, mtype, seqid = proto.readMessageBegin()
        if mtype == TMessageType.EXCEPTION:
            # 读 TApplicationException
            proto.readStructBegin()
            fname, ftype, fid = proto.readFieldBegin()
            msg = proto.readString()
            proto.readFieldEnd()
            proto.readStructBegin()
            return ("EXCEPTION", msg)
        proto.readStructBegin()
        result = None
        while True:
            fname, ftype, fid = proto.readFieldBegin()
            if ftype == TType.STOP:
                break
            if fid == 0 and ftype == TType.STRUCT:
                proto.readStructBegin()
                code, msg = None, None
                while True:
                    fn, ft, fi = proto.readFieldBegin()
                    if ft == TType.STOP:
                        break
                    if fi == 1 and ft == TType.I32:
                        code = proto.readI32()
                    elif fi == 2 and ft == TType.STRING:
                        msg = proto.readString()
                    else:
                        proto.skip(ft)
                    proto.readFieldEnd()
                proto.readStructEnd()
                result = (code, msg)
            else:
                proto.skip(ftype)
            proto.readFieldEnd()
        proto.readStructEnd()
        proto.readMessageEnd()
        return result
    finally:
        trans.close()


if __name__ == "__main__":
    cmd = " ".join(sys.argv[1:])
    if not cmd:
        print("usage: gm_client.py <cmd>")
        sys.exit(2)
    print("CMD:", cmd)
    print("RESULT:", call(cmd))
