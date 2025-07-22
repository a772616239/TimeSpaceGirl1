using UnityEngine;
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Collections;
using System.Collections.Generic;
using GameLogic;
using System.Text;
using LuaInterface;
//using System.Runtime.InteropServices;

public enum NetworkStateType
{
    Connected,
    ConnectFail,
    Reconnected,
    ReconnectFail,
    Exception,
    Disconnect,
}


static class IPAddressExtensions
{
    public static IPAddress MapToIPv6(this IPAddress addr)
    {
        if (addr.AddressFamily != AddressFamily.InterNetwork)
            throw new ArgumentException("Must pass an IPv4 address to MapToIPv6");

        string ipv4str = addr.ToString();

        return IPAddress.Parse("::ffff:" + ipv4str);
    }

    public static bool IsIPv4MappedToIPv6(this IPAddress addr)
    {
        bool pass1 = addr.AddressFamily == System.Net.Sockets.AddressFamily.InterNetworkV6, pass2;

        try
        {
            pass2 = (addr.ToString().StartsWith("0000:0000:0000:0000:0000:ffff:") ||
                    addr.ToString().StartsWith("0:0:0:0:0:ffff:") ||
                    addr.ToString().StartsWith("::ffff:")) &&
                    IPAddress.Parse(addr.ToString().Substring(addr.ToString().LastIndexOf(":") + 1)).AddressFamily == AddressFamily.InterNetwork;
        }
        catch
        {
            return false;
        }

        return pass1 && pass2;
    }
}

public class SocketClient
{
    public NetworkManager netMgr;
    private TcpClient client = null;
    private NetworkStream outStream = null;
    private MemoryStream _memStream;
    public MemoryStream CurMemoryStream
    {
        get
        {
            if (_memStream == null)
                _memStream = new MemoryStream();

            return _memStream;
        }
    }

    private BinaryReader _reader;
    public BinaryReader CurReader
    {
        get
        {
            if (_reader == null)
                _reader = new BinaryReader(_memStream);

            return _reader;
        }
    }

    static readonly int HeaderSize = sizeof(ushort) + sizeof(int);
    private const int MAX_READ = 8192;
    private byte[] byteBuffer = new byte[MAX_READ];
    static TEA crypto = new TEA();

    Queue<NetMsg> mEvents = new Queue<NetMsg>();
    Stack<NetworkStateInfo> stateInfoStack = new Stack<NetworkStateInfo>();
    Dictionary<int, IDispatcher> dispatchers = new Dictionary<int, IDispatcher>();
    Dictionary<int, IDispatcher> callbacks = new Dictionary<int, IDispatcher>();

    int m_serialId;
    int m_indicationSid;
    bool m_isConnected = false;
    bool m_isConnecting = false;

    private const int INDICATION_RESPONSE = 10046;
    private const int INDICATION_ERROR_CODE = 10400;

    public string IpAddress { get; private set; }
    public int Port { get; private set; }

    // Use this for initialization
    public SocketClient(string ipAddress, int port)
    {

        //Debug.Log("****Socket*********************创建一个Socket   ---" + ipAddress);
        IpAddress = ipAddress;
        Port = port;
        _memStream = new MemoryStream();
        _reader = new BinaryReader(_memStream);
    }

    public void SetIpAddress(string ipAddress, int port)
    {
        if (!IsConnected())
        {
            IpAddress = ipAddress;
            Port = port;
            m_indicationSid = 0;
            m_serialId = 1;
        }
    }

    /// <summary>
    /// 连接服务器
    /// </summary>
    public void Connect()
    {

        //Debug.Log("****Socket*********************Connect   ---" + IpAddress);
        Close();

        try
        {
            var ipType = GetIPAddressType(IpAddress);
            client = null;
            client = new TcpClient(ipType);
            client.SendTimeout = 1000;
            client.ReceiveTimeout = 1000;
            client.NoDelay = true;
            client.BeginConnect(IpAddress, Port, new AsyncCallback(OnConnect), null);
        }
        catch (Exception e)
        {
            OnConnectFail();
            Debug.LogWarning(e.Message);
        }
    }

    public void OnConnectFail()
    {
        //Debug.Log("****Socket*********************OnConnectFail   ---" + IpAddress);
        AddStateInfo(NetworkStateType.ConnectFail, null);
    }

    /// <summary>
    /// 连接上服务器
    /// </summary>
    void OnConnect(IAsyncResult asr)
    {
        //Debug.Log("****Socket*********************OnConnect   ---" + IpAddress);
        outStream = client.GetStream();
        client.GetStream().BeginRead(byteBuffer, 0, MAX_READ, new AsyncCallback(OnRead), null);
        AddStateInfo(NetworkStateType.Connected, null);
    }

    /// <summary>
    /// 写数据
    /// </summary>
    void WriteMessage(byte[] message)
    {
        MemoryStream ms = null;
        using (ms = new MemoryStream())
        {
            ms.Position = 0;

            BinaryWriter writer = new BinaryWriter(ms);
            short msglen = (short)message.Length;

            msglen = IPAddress.HostToNetworkOrder(msglen);

            byte[] tempBuffer = new byte[message.Length];
            Buffer.BlockCopy(message, 0, tempBuffer, 0, message.Length);

            if (crypto != null)
                tempBuffer = crypto.Encode(tempBuffer);

            writer.Write(tempBuffer);
            writer.Flush();
            if (client != null && client.Connected)
            {
                //NetworkStream stream = client.GetStream(); 
                byte[] payload = ms.ToArray();
                outStream.BeginWrite(payload, 0, payload.Length, new AsyncCallback(OnWrite), ms);
            }
            else
            {
                Debug.Log("client.connected----->>false");
            }
        }
    }


    /// <summary>
    /// 读取消息
    /// </summary>
    void OnRead(IAsyncResult asr)
    {
        int bytesRead = 0;
        //try
        {
            lock (client.GetStream())
            {
                //读取字节流到缓冲区
                bytesRead = client.GetStream().EndRead(asr);
            }

            if (bytesRead < 1)
            {
                //包尺寸有问题，断线处理
                AddStateInfo(NetworkStateType.Disconnect, "bytesRead < 1");
                return;
            }
            OnReceive(byteBuffer, bytesRead); //分析数据包内容，抛给逻辑层
            lock (client.GetStream())
            {
                //分析完，再次监听服务器发过来的新消息
                Array.Clear(byteBuffer, 0, byteBuffer.Length); //清空数组
                client.GetStream().BeginRead(byteBuffer, 0, MAX_READ, new AsyncCallback(OnRead), null);
            }
        }
        //catch (Exception ex)
        //{
        //    //PrintBytes();
        //    AddStateInfo(NetworkStateType.Exception, ex.Message);
        //}
    }

    /// <summary>
    /// 丢失链接
    /// </summary>
    public void AddStateInfo(NetworkStateType dis, string msg)
    {
        NetworkStateInfo info = new NetworkStateInfo();
        info.type = dis;
        info.msg = msg;
        stateInfoStack.Push(info);
    }

    /// <summary>
    /// 打印字节
    /// </summary>
    /// <param name="bytes"></param>
    void PrintBytes()
    {
        string returnStr = string.Empty;
        for (int i = 0; i < byteBuffer.Length; i++)
        {
            returnStr += byteBuffer[i].ToString("X2");
        }
        Debug.LogError(returnStr);
    }

    /// <summary>
    /// 向链接写入数据流
    /// </summary>
    void OnWrite(IAsyncResult r)
    {
        try
        {
            MemoryStream stream = (MemoryStream)r.AsyncState;
            outStream.EndWrite(r);
            if (stream != null)
            {
                stream.Close();
            }
        }
        catch (Exception ex)
        {
            Debug.LogError("OnWrite--->>>" + ex.Message);
        }
    }

    /// <summary>
    /// 接收到消息
    /// </summary>
    void OnReceive(byte[] bytes, int length)
    {

        //Debug.Log("****Socket*********************OnReceive   ---" + IpAddress);
        try
        {
            var stream = CurMemoryStream;
            var reader = CurReader;

            stream.Seek(0, SeekOrigin.End);
            stream.Write(bytes, 0, length);
            //Reset to beginning
            stream.Seek(0, SeekOrigin.Begin);

            while (RemainingBytes() > 6)
            {
                int messageLen = reader.ReadInt32();
                messageLen = IPAddress.NetworkToHostOrder(messageLen);
                //memStream.Seek(0, SeekOrigin.Begin);              
                //TEA解密需要补齐8位
                int decodeMessageLen = (messageLen + 7) / 8 * 8;
                if (RemainingBytes() >= decodeMessageLen)  //粘包处理
                {
                    var msgBytes = reader.ReadBytes(decodeMessageLen);
                    if (crypto != null)
                        msgBytes = crypto.Decode(msgBytes, messageLen);
                    OnReceivedMessage(new ByteBuffer(msgBytes));
                }
                else
                {
                    //Back up the position two bytes
                    stream.Position = stream.Position - 4;
                    break;
                }
            }
            //Create a new stream with any leftover bytes
            byte[] leftover = reader.ReadBytes((int)RemainingBytes());
            stream.SetLength(0);     //Clear
            stream.Write(leftover, 0, leftover.Length);
        }
        catch (Exception e)
        {
            Debug.LogError("Network Read Exception: " + e.ToString());
            Debug.Log(bytes);
            AddStateInfo(NetworkStateType.Disconnect, "Network Read Exception: " + e.ToString());
        }
    }

    /// <summary>
    /// 剩余的字节
    /// </summary>
    private long RemainingBytes()
    {
        return CurMemoryStream.Length - CurMemoryStream.Position;
    }

    /// <summary>
    /// 接收到消息
    /// </summary>
    /// <param name="ms"></param>
    void OnReceivedMessage(ByteBuffer buffer)
    {
        //user id
        buffer.ReadIntToByte();
        //token
        buffer.ReadIntToByte();
        //协议号
        int msgid = buffer.ReadIntToByte();

        //收到心跳包
        if (msgid == 1001)
        {
            lock (mEvents)
            {
                mEvents.Enqueue(new NetMsg(msgid, 0, 0, buffer));
            }
            return;
        }
        //消息index
        int sId = buffer.ReadIntToByte();
        //结果码
        int result = buffer.ReadIntToByte();
        lock (mEvents)
        {
            mEvents.Enqueue(new NetMsg(msgid, sId, result, buffer));
        }
    }

    private void indicationErrorAction(ByteBuffer buffer)
    {

        //Debug.Log("****Socket*********************indicationErrorAction   ---" + IpAddress);
        Util.CallMethod("SocketManager", "ReceiveErrorInfo", this, buffer);
    }


    /// <summary>
    /// 关闭链接
    /// </summary>
    public void Close()
    {
        //Debug.Log("****Socket*********************Close   ---" + IpAddress);
        UnregistNetMessage(INDICATION_ERROR_CODE, indicationErrorAction);
        m_isConnected = false;
        m_isConnecting = false;

        lock (mEvents)
        {
            mEvents.Clear();
        }
        dispatchers.Clear();
        callbacks.Clear();
        stateInfoStack.Clear();

        if (client != null)
        {
            client.Close();
            client = null;
        }

        if (_memStream != null)
        {
            _memStream.Dispose();
            _memStream = null;
        }
        if (_reader != null)
        {
            _reader.Close();
            _reader = null;
        }
        Array.Clear(byteBuffer, 0, byteBuffer.Length);
    }

    bool testConnect;
    public void Update()
    {
        if (stateInfoStack.Count > 0)
        {
            var info = stateInfoStack.Pop();

            if (info.type == NetworkStateType.Connected)
            {
                m_isConnected = true;
                RegistNetMessage(INDICATION_ERROR_CODE, indicationErrorAction);
                Util.CallMethod("SocketManager", "OnConnect", this);
            }
            else if (info.type == NetworkStateType.ConnectFail)
            {
                Util.CallMethod("SocketManager", "OnConnectFail", this);
            }
            else if (info.type == NetworkStateType.Reconnected)
            {
                m_isConnected = true;
                RegistNetMessage(INDICATION_ERROR_CODE, indicationErrorAction);
                Util.CallMethod("SocketManager", "OnReconnect", this);
            }
            else if (info.type == NetworkStateType.ReconnectFail)
            {
                Util.CallMethod("SocketManager", "OnReconnectFail", this);
            }
            else if (info.type == NetworkStateType.Disconnect)
            {
                Disconnect();
            }
            else if (info.type == NetworkStateType.Exception)
            {
                Disconnect();
            }
            return;
        }

        lock (mEvents)
        {
            while (mEvents.Count > 0)
            {
                DispatchMessage(mEvents.Dequeue());
            }
        }

        testConnect = Input.GetKeyDown(KeyCode.F1);

        if (testConnect)
        {
            Debug.Log("~~~~~~~~~~~~~测试掉线~~~~~~~~~~~~~~~");
        }

        if (m_isConnecting && !testConnect)
        {
            return;
        }

        if ((testConnect || !IsConnected()) && m_isConnected)
        {
            Disconnect();
        }
    }

    void DispatchMessage(NetMsg _event)
    {
        int msgId = _event.msgId;
        ByteBuffer msg = _event.msg;

        //Debug.LogError("msgId:" + msgId);
        //Debug.LogError("m_indicationSid:" + m_indicationSid);
        //Debug.LogError("sid:" + _event.sid);

        //处理心跳包回调
        if (msgId == 1001)
        {
            Util.CallMethod("SocketManager", "ReceiveClientHeartBeat", this, msg);
            return;
        }
        //处理错误码
        if (_event.result == 0)
        {
            m_serialId++;
            Util.CallMethod("SocketManager", "ReceiveErrorInfo", this, msg);
            if (callbacks.ContainsKey(msgId))
            {
                callbacks.Remove(msgId);
            }
            return;
        }

        if (dispatchers.ContainsKey(msgId) && callbacks.ContainsKey(msgId))
        {
            Debug.LogError("重复！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！：" + msgId);
        }


        //处理请求回应消息
        if (callbacks.ContainsKey(msgId))
        {
            var call = callbacks[msgId];
            callbacks.Remove(msgId);
            m_serialId++;
            if (!call.Process(msg))
            {
                UnityEngine.Debug.LogErrorFormat("Failed to process message. msgId : {0}", msgId);
            }
        }
        else
        {
            //处理推送消息，当序列号比本地游标大1，处理推送信息，否则不处理
            if (dispatchers.ContainsKey(msgId))
            {
                //if (m_indicationSid == _event.sid - 1)
                //{
                //    m_indicationSid++;
                if (!dispatchers[msgId].Process(msg))
                {
                    UnityEngine.Debug.LogErrorFormat("Failed to process message. msgId : {0}", msgId);
                }
                //}
                //else
                //{
                //    Debug.LogError("服务器推送ID：" + msgId +  ",客户端计数：" + m_indicationSid + ",服务器计数：" + _event.sid);
                //}

                //if (_event.sid <= m_indicationSid)
                //{
                //Debug.LogError("INDICATION_RESPONSE" + msgId);
                m_SendMessage(INDICATION_RESPONSE, null, _event.sid);
                //}
            }
        }
    }

    public void Disconnect()
    {
        //Debug.Log("****Socket*********************Disconnect   ---" + IpAddress);
        Close();   //关掉客户端链接
        Util.CallMethod("SocketManager", "OnDisconnect", this);
    }

    private Coroutine checkConnect_co;
    IEnumerator CheckConnect_Co()
    {
        yield return new WaitForEndOfFrame();
        Debug.LogWarning("Start Connecting  IP: " + IpAddress + "     Port: " + Port);
        Connect();
        m_isConnecting = true;
        yield return new WaitForSeconds(AppConst.ConnectTimeout);
        if (!IsConnected())
        {
            OnConnectFail();
        }

        m_isConnecting = false;
        checkConnect_co = null;
    }
    /// <summary>
    /// 发送连接请求
    /// </summary>
    public void TryConnect()
    {
        //Debug.Log("****Socket*********************TryConnect   ---" + IpAddress);
        if (IsConnected())
        {
            NetworkStateInfo info = new NetworkStateInfo();
            info.type = NetworkStateType.Connected;
            info.msg = null;
            stateInfoStack.Push(info);
            return;
        }
        if (m_isConnecting)
            return;

        if (checkConnect_co != null)
        {
            netMgr.StopCoroutine(checkConnect_co);
        }

        checkConnect_co = netMgr.StartCoroutine(CheckConnect_Co());
    }

    private Coroutine reconnect_co;
    IEnumerator CheckReconnect_Co()
    {
        yield return new WaitForEndOfFrame();
        Reconnect();
        m_isConnecting = true;
        yield return new WaitForSeconds(AppConst.ConnectTimeout);
        if (!IsConnected())
            OnReconnectFail();

        m_isConnecting = false;
        reconnect_co = null;
    }

    public void TryReconnect()
    {
        //Debug.Log("****Socket*********************TryReconnect   ---" + IpAddress);
        if (IsConnected())
        {
            NetworkStateInfo info = new NetworkStateInfo();
            info.type = NetworkStateType.Reconnected;
            info.msg = null;
            stateInfoStack.Push(info);
            return;
        }
        if (m_isConnecting)
            return;

        if (reconnect_co != null)
        {
            netMgr.StopCoroutine(reconnect_co);
        }
        reconnect_co = netMgr.StartCoroutine(CheckReconnect_Co());
    }

    public void Reconnect()
    {
        //Debug.Log("****Socket*********************Reconnect   ---" + IpAddress);
        Close();
        try
        {
            var ipType = GetIPAddressType(IpAddress);
            client = null;
            client = new TcpClient(ipType);
            //client.SendTimeout = 1000;
            //client.ReceiveTimeout = 1000;
            client.NoDelay = true;
            client.BeginConnect(IpAddress, Port, new AsyncCallback(OnReconnect), null);
        }
        catch (Exception e)
        {
            Debug.LogError(e.Message);
            OnReconnectFail();
        }
    }

    public AddressFamily GetIPAddressType(string ip)
    {
        bool hasIpv4 = false;
        bool hasIpv6 = false;

        try
        {
            IPAddress[] address = Dns.GetHostAddresses(ip);
            for (int i = 0; i < address.Length; i++)
            {
                //从IP地址列表中筛选出IPv4类型的IP地址  
                //AddressFamily.InterNetwork表示此IP为IPv4,  
                //AddressFamily.InterNetworkV6表示此地址为IPv6类型  
                if (address[i].AddressFamily == AddressFamily.InterNetwork)
                {
                    hasIpv4 = true;
                }
                else if (address[i].AddressFamily == AddressFamily.InterNetworkV6)
                {
                    hasIpv6 = true;
                }

                Util.Log("Network IPAddresssFamily： " + address[i].AddressFamily.ToString() + "  IP:  " + address[i].ToString());
            }
        }
        catch (Exception ex)
        {
            Debug.LogWarning("Network GetIPAddressType Exception: " + ex);
            return AddressFamily.InterNetwork;
        }

        if (hasIpv4)
            return AddressFamily.InterNetwork;

        if (hasIpv6)
            return AddressFamily.InterNetworkV6;

        return AddressFamily.InterNetwork;
    }

    public void OnReconnectFail()
    {
        //Debug.Log("****Socket*********************OnReconnectFail   ---" + IpAddress);
        AddStateInfo(NetworkStateType.ReconnectFail, null);
    }

    void OnReconnect(IAsyncResult result)
    {
        //Debug.Log("****Socket*********************OnReconnect   ---" + IpAddress);
        outStream = client.GetStream();
        client.GetStream().BeginRead(byteBuffer, 0, MAX_READ, new AsyncCallback(OnRead), null);
        AddStateInfo(NetworkStateType.Reconnected, null);
    }

    /// <summary>
    /// 发送消息
    /// </summary>
    public void SendMessage(int msgId, ByteBuffer msg)
    {
        m_serialId++;
        m_SendMessage(msgId, msg, m_serialId);
    }


    void m_SendMessage(int msgId, ByteBuffer msg, int sn)
    {
        if (!IsConnected())
        {
            return;
        }
        ByteBuffer buffer = new ByteBuffer();
        buffer.WriteIntToByte(AppConst.UserId);
        buffer.WriteIntToByte(AppConst.Token);
        buffer.WriteIntToByte(msgId);
        buffer.WriteIntToByte(sn);

        if (msg != null)
        {
            buffer.WriteBuffer(new LuaInterface.LuaByteBuffer(msg.ToBytes()));
            msg.Close();
        }

        WriteMessage(buffer.ToBytes());
        buffer.Close();
    }

    /// <summary>
    /// 发送心跳
    /// </summary>
    public void SendHeartBeat()
    {
        ByteBuffer buffer = new ByteBuffer();
        buffer.WriteIntToByte(AppConst.UserId);
        buffer.WriteIntToByte(AppConst.Token);
        buffer.WriteIntToByte(1000);
        WriteMessage(buffer.ToBytes());
        buffer.Close();
    }


    public bool IsConnected()
    {
        return client != null && client.Connected;
    }

    public void RegistNetMessage(int msgId, Action<ByteBuffer> handle)
    {
        if (!dispatchers.ContainsKey(msgId))
            dispatchers.Add(msgId, new SimpleDispatcher());
        //XDebug.Log.l("++++++++++++++++RegistNetMessage================================", msgId, IpAddress, Port);
        SimpleDispatcher find = (SimpleDispatcher)dispatchers[msgId];
        find.processor += handle;
    }

    public void UnregistNetMessage(int msgId, Action<ByteBuffer> handle)
    {
        if (!dispatchers.ContainsKey(msgId))
            return;
        //XDebug.Log.l("-------------------UnregistNetMessage================================", msgId, IpAddress, Port);
        SimpleDispatcher find = (SimpleDispatcher)dispatchers[msgId];
        find.processor -= handle;
    }


    public void SendMessageWithCallBack(int msgId, int receiveMsgId, ByteBuffer message, LuaFunction callback)
    {
        if (!IsConnected())
        {
            XDebug.Log.l("Try to send message with invalid connection.");
            AddStateInfo(NetworkStateType.Disconnect, "bytesRead < 1");
        }
        else
        {
            SimpleDispatcher cb = new SimpleDispatcher();
            cb.processor += b => callback.Call(b);
            if (!callbacks.ContainsKey(receiveMsgId))
            {
                callbacks.Add(receiveMsgId, cb);
            }
            m_SendMessage(msgId, message, m_serialId);
            XDebug.Log.l("SendMessageWithCallBack msgId: " + msgId + " receiveMsgId: " + receiveMsgId + " serialId: " + m_serialId);
        }
    }

}
