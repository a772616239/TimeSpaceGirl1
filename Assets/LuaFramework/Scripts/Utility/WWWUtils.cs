using System;
using System.IO;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using Object=UnityEngine.Object;
using GameCore;
using GameLogic;

public class WWWManager : UnitySingleton<WWWManager>{}
    public class WWWUtils
    {
        public static void StopAllWWWCoroutine()
        {
            WWWManager.Instance.StopAllCoroutines();
        }

        public static void StopWWWCoroutine(Coroutine co)
        {
            WWWManager.Instance.StopCoroutine(co);
        }

        public static void RequestText(string url, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<string>(url, null, null, secuessHandle, failHandle, timeOut));
        }

        public static void RequestText(string url, byte[] postBytes, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<string>(url, null, postBytes, secuessHandle, failHandle, timeOut));
        }

        public static void RequestText(string url, string postDatas, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWForm form = new WWWForm();
            var datas = postDatas.Split(';');
            Hashtable table = new Hashtable();
            for (int i = 0; i < datas.Length; i++)
            {
                var fieldInfo = datas[i].Split(':');

                if (fieldInfo != null && fieldInfo.Length == 2)
                {
                    table.Add(fieldInfo[0], fieldInfo[1]);
                    form.AddField(fieldInfo[0], fieldInfo[1]);
                }
            }

            WWWManager.Instance.StartCoroutine(WWW<string>(url, form, null, secuessHandle, failHandle, timeOut));
        }

        public static void RequestTexture(string url, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<Texture2D>(url, null, null, secuessHandle, failHandle, timeOut));
        }

        public static void RequestAudio(string url, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<AudioClip>(url, null, null, secuessHandle, failHandle, timeOut));
        }

        public static void RequestAssetBundle(string url, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<AssetBundle>(url, null, null, secuessHandle, failHandle, timeOut));
        }

        public static void RequestBytes(string url, GameEventHandler secuessHandle = null, GameEventHandler failHandle = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(WWW<Byte>(url, null, null, secuessHandle, failHandle, timeOut));
        }

        public static void UploadScreenShot(string picName, string storagePath, string uploadUrl, int picWidth, int picHeight, int startPosX = 0, int startPoxY = 0, string info = null, GameEventHandler secuessScreenShot = null, GameEventHandler failScreenShot = null, GameEventHandler secuessUpload = null, GameEventHandler failUpload = null, int timeOut = 0)
        {
            WWWManager.Instance.StartCoroutine(ScreenShot(picName, storagePath, uploadUrl, picWidth, picHeight, startPosX, startPoxY, info, secuessScreenShot, failScreenShot, secuessUpload, failUpload, timeOut));
        }

        private static IEnumerator ScreenShot(string picName, string storagePath, string uploadUrl, int picWidth, int picHeight, int startPosX = 0, int startPoxY = 0, string info = null, GameEventHandler secuessScreenShot = null, GameEventHandler failScreenShot = null, GameEventHandler secuessUpload = null, GameEventHandler failUpload = null, int timeOut = 0)
        {
            yield return new WaitForEndOfFrame();

            try
            {
                int width = picWidth;
                int height = picHeight;
                Texture2D tex = new Texture2D(width, height, TextureFormat.RGB24, false);
                tex.ReadPixels(new Rect(startPosX, startPoxY, width, height), 0, 0, false);
                tex.Apply();
                byte[] bytes = tex.EncodeToPNG();
                WWWForm form = new WWWForm();
                if (info != null)
                    form.AddField("info", info);
                form.AddField("picName", picName);
                form.AddBinaryData("post", bytes);
                WWWManager.Instance.StartCoroutine(WWW<Object>(uploadUrl, form, null, secuessUpload, failUpload, timeOut));
                File.WriteAllBytes(storagePath + "/" + picName, bytes);
                Object.Destroy(tex);
                if (secuessScreenShot != null)
                    secuessScreenShot(storagePath + "/" + picName);
            }
            catch (Exception e)
            {
                if (failScreenShot != null)
                {
                    failScreenShot(e.Message);
                }
            }
        }

        public static IEnumerator WWW<T>(string url, WWWForm form = null, byte[] formBytes = null, GameEventHandler secuessHandle = null, GameEventHandler errorHandle = null, int timeOut = 0)
        {
            float startTime = Time.realtimeSinceStartup;
            UnityWebRequest webRequest = null;
            if (form != null)
            {
                webRequest =  UnityWebRequest.Post(url,form);
            }
            else if (formBytes != null)
            {
                webRequest = UnityWebRequest.Put(url, formBytes);
            }
            else if (typeof(T) == typeof(Texture2D))
            {
                webRequest = UnityWebRequestTexture.GetTexture(url);
            }
            else if (typeof(T) == typeof(AudioClip))
            {
                webRequest = UnityWebRequestMultimedia.GetAudioClip(url, AudioType.OGGVORBIS);
            }
            else if (typeof(T) == typeof(AssetBundle))
            {
                webRequest = UnityWebRequestAssetBundle.GetAssetBundle(url);
            }
            else
            {
                webRequest = new UnityWebRequest(url);
            }
            webRequest = UnityWebRequest.Get(url);
            yield return webRequest.Send();
            if (webRequest.error != null)
            {
              if (errorHandle != null)
                  errorHandle("wwwError", webRequest.error);
                yield break;
            }
            else if (timeOut>0 && Time.realtimeSinceStartup - startTime > timeOut)
            {
                if (errorHandle != null)
                {
                    errorHandle("TimeOut", Time.realtimeSinceStartup - startTime);
                }
                yield break;
            }
            else
            {
                string returnMessage = webRequest.downloadHandler.text;
            
                if (typeof(T) == typeof(string))
                {
                    if (secuessHandle != null)
                    {
                        secuessHandle(webRequest.downloadHandler.text);
                    }
                }
                else if (typeof(T) == typeof(Texture2D))
                {
                    if (secuessHandle != null)
                        secuessHandle(webRequest);
                }
                else if (typeof(T) == typeof(AudioClip))
                {
                    if (secuessHandle != null)
                        secuessHandle(DownloadHandlerAudioClip.GetContent(webRequest));
                }
                else if (typeof(T) == typeof(AssetBundle))
                {
                    if (secuessHandle != null)
                    {
                        secuessHandle(DownloadHandlerAssetBundle.GetContent(webRequest));
                    }
                }
                else if (typeof(T) == typeof(Byte))
                {
                    if (secuessHandle != null)
                        secuessHandle(webRequest.downloadHandler.data);
                }
                else if (typeof(T) == typeof(Object))
                {
                    if (secuessHandle != null)
                        secuessHandle();
                }
            }
        }
    }
