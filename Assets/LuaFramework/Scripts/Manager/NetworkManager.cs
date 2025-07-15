using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;
using System.Text;
using GameCore;
using UnityEngine.Networking;

namespace GameLogic
{
    class AcceptAllCertificatesSignedWithASpecificPublicKey : CertificateHandler
    {
        protected override bool ValidateCertificate(byte[] certificateData)
        {
            return true;
        }
    }

    public class NetMsg
    {
        public int msgId;
        public int sid;
        public int result;
        public ByteBuffer msg;

        public NetMsg(int msgId, int sid, int result, ByteBuffer msg)
        {
            this.msgId = msgId;
            this.sid = sid;
            this.msg = msg;
            this.result = result;
        }
    }
    public class NetworkStateInfo
    {
        public NetworkStateType type;
        public string msg;
    }

    public class NetworkManager : UnitySingleton<NetworkManager>
    {
        private List<SocketClient> socketList = new List<SocketClient>();

        void Awake()
        {
        }

        void OnApplicationQuit()
        {
            Reset();
        }
        /// <summary>
        /// Îö¹¹º¯Êý
        /// </summary>
        void OnDestroy()
        {
            Reset();
        }

        public void Reset()
        {
            foreach(var s in socketList)
            {
                s.Close();
            }
            socketList.Clear();
        }

        void Update()
        {
            for(int i = 0; i < socketList.Count; i++)
            {
                socketList[i].Update();
            }
        }

        public void OnInit()
        {
            Util.CallMethod("SocketManager", "Start");
        }

        public void Unload()
        {
            Util.CallMethod("SocketManager", "Unload");
        }

        public SocketClient AddSocket(string ipAddress, int port)
        {
            SocketClient socket = new SocketClient(ipAddress, port);
            socket.netMgr = this;
            socketList.Add(socket);
            return socket;
        }

        public void SendGetHttp(string url, LuaFunction callback, Action<string> sharpFunc, Action errorAction, LuaFunction errorLuaFunc)
        {
            StartCoroutine(HttpGet_Co(url, callback, sharpFunc, errorAction, errorLuaFunc));
        }

        IEnumerator HttpGet_Co(string url, LuaFunction callback, Action<string> sharpFunc, Action errorAction, LuaFunction errorLuaFunc)
        {
            if (string.IsNullOrEmpty(url))
            {
                if (errorAction!=null)
                {
                    errorAction();
                }
                if (errorLuaFunc != null)
                {
                    errorLuaFunc.Call();
                }
                yield break;
            }
            Debug.Log("[NetworkManager]::HttpGet_Co url: " + url);
            UnityWebRequest request = UnityWebRequest.Get(url);
            request.certificateHandler = new AcceptAllCertificatesSignedWithASpecificPublicKey();

            yield return request.SendWebRequest();
            if (request.isNetworkError)
            {
                Util.LogError("url::" + url + " HttpGet Error:    " + request.error);
                if (errorAction != null)
                    errorAction();

                yield break;
            }
            else
            {
                //var result = Encoding.UTF8.GetString(getData.bytes);
                var result = request.downloadHandler.text;
                Debug.Log("[NetworkManager]::HttpGet_Co succ result: " + result);

                if (callback != null)
                    callback.Call(result);

                if (sharpFunc != null)
                    sharpFunc(result);
            }
        }
         public void SendAndroidData(string url)
        {
            StartCoroutine(HttpSetAndroidData(url));
        }
        IEnumerator HttpSetAndroidData(string url)
        {
            if (string.IsNullOrEmpty(url))
            {
                yield break;
            }

            UnityWebRequest request = UnityWebRequest.Get(url);
            request.certificateHandler = new AcceptAllCertificatesSignedWithASpecificPublicKey();
            Debug.Log(url);
            yield return request.SendWebRequest();
            if (request.isNetworkError)
            {
                Util.LogError("url::" + url + " HttpGet Error:    " + request.error);

                yield break;
            }
            else
            {
                //var result = Encoding.UTF8.GetString(getData.bytes);
                var result = request.downloadHandler.text;

            }
        }
        public void SendHttpPost_Raw_Lua(string url, string data, LuaFunction callback, LuaFunction errorLuaFunc)
        {
            StartCoroutine(HttpPost_Co(url, data, callback, null, null, errorLuaFunc));
        }

        public void SendHttpPost_Json_Lua(string url, string data, LuaFunction callback, LuaFunction errorLuaFunc)
        {
            var strs = data.Split(';');
            Hashtable table = new Hashtable();
            for (int i = 0; i < strs.Length; i = i + 2)
            {
                table.Add(strs[i], strs[i + 1]);
            }
            var jsonData = MiniJSON.jsonEncode(table);
            StartCoroutine(HttpPost_Co(url, jsonData, callback, null, null, errorLuaFunc));
        }

        public void SendHttpPost_Raw_CSharp(string url, string data, Action<string> sharpFunc, Action errorAction)
        {
            StartCoroutine(HttpPost_Co(url, data, null, sharpFunc, errorAction, null));
        }

        public void SendHttpPost_Json_CSharp(string url, string data, Action<string> sharpFunc, Action errorAction)
        {
            var strs = data.Split(';');
            Hashtable table = new Hashtable();
            for (int i = 0; i < strs.Length; i = i + 2)
            {
                table.Add(strs[i], strs[i + 1]);
            }

            var jsonData = MiniJSON.jsonEncode(table);

            StartCoroutine(HttpPost_Co(url, jsonData, null, sharpFunc, errorAction, null));
        }


        public IEnumerator HttpPost_Co(string url, string data, LuaFunction callback, Action<string> sharpFunc, Action errorAction, LuaFunction errorLuaFunc)
        {
            float duration = 0;
            if(string.IsNullOrEmpty(url))
            {
                if (errorAction!=null)
                {
                    errorAction();
                }
                if (errorLuaFunc!=null)
                {
                    errorLuaFunc.Call();
                }
                yield break;
            }
            Dictionary<string, string> header = new Dictionary<string, string>();
            header.Add("Content-Type", "application/json");
            header.Add("charset", "utf-8");
            WWW postData = new WWW(url, Encoding.UTF8.GetBytes(data), header);
            while (!postData.isDone)
            {
                yield return new WaitForEndOfFrame();
                duration += Time.deltaTime;
                if(duration>=AppConst.HttpTimeout)
                {
                    Debug.Log(url + " HttpPostError:    HttpTimeout:"+ AppConst.HttpTimeout+"  "+ data);
                    if (errorAction != null)
                        errorAction();

                    if (errorLuaFunc != null)
                        errorLuaFunc.Call();

                    postData.Dispose();
                    yield break;
                }
            }

            var result = Encoding.UTF8.GetString(postData.bytes);
            Debug.LogWarning(url+"  Result:  " + result);
            if (postData.error != null)
            {
                Debug.Log("HttpPostError:    " + postData.error);
                if (errorAction != null)
                    errorAction();

                if (errorLuaFunc != null)
                    errorLuaFunc.Call();

                yield break;
            }

            if (callback != null)
                callback.Call(result);

            if (sharpFunc != null)
                sharpFunc(result);
        }
    }
}