#!/usr/bin/env python3
"""极简 Thrift 客户端：直连 gameserver 的 RPCGmServerTask (idipGm)。

用法:
    python3 gm_client.py [--host H] [--port P] <cmd...>
    python3 gm_client.py 'oneuserinfo 10000004'
    python3 gm_client.py --port 17916 'sendmailall 0 6001000#20@#Christmas Gift Pack@#Merry Christmas!'

生产服 gmport 只监听 127.0.0.1，先开隧道再连本地端口:
    ssh -N -L 17916:127.0.0.1:7916 gs     # 另一个终端挂着
    python3 gm_client.py --port 17916 '...'

环境变量 GM_HOST / GM_PORT 可替代命令行开关。
"""
import os
import sys
from thrift.protocol import TBinaryProtocol
from thrift.transport import TSocket, TTransport
from thrift.Thrift import TType, TMessageType

HOST = os.environ.get("GM_HOST", "127.0.0.1")
PORT = int(os.environ.get("GM_PORT", "7916"))


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
    argv = sys.argv[1:]
    host, port = HOST, PORT
    rest = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--host" and i + 1 < len(argv):
            host = argv[i + 1]
            i += 2
        elif a == "--port" and i + 1 < len(argv):
            port = int(argv[i + 1])
            i += 2
        else:
            rest.append(a)
            i += 1
    cmd = " ".join(rest)
    if not cmd:
        print("usage: gm_client.py [--host H] [--port P] <cmd>")
        sys.exit(2)
    print("TARGET: %s:%d" % (host, port))
    print("CMD:", cmd)
    print("RESULT:", call(cmd, host=host, port=port))
