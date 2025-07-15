using UnityEngine;
using UnityEngine.UI;
using System.Collections;
using System.IO;
using System.Collections.Generic;
using GameCore;
public class ImageDownloader
{
    public int code;
    public Sprite sprite;
}

public class ImageDownloadRequest
{
    public string address;
    public Image imgTarget;
    public bool isSelf;
}
namespace GameLogic {
    public class ImageDownloadManager : UnitySingleton<ImageDownloadManager>
    {
        ImageDownloader selfImage = null;
        List<ImageDownloader> picList = new List<ImageDownloader>();
        Queue<ImageDownloadRequest> request = new Queue<ImageDownloadRequest>();

        private static int maxCacheSpriteCount = 200;
        private static int clearSpriteCount = 5;
        private static bool isDownloading = false;


        public void Reset()
        {
            StopAllCoroutines();
            ClearAllSpriteCache();

            isDownloading = false;
            request.Clear();
        }

        public void SetImage_GameObject(string url, GameObject obj, bool isSelf = false)
        {
            if (string.IsNullOrEmpty(url))
            {
                Debug.LogWarning("ImageDownload  Url is Empty");
                return;
            }

            if (obj == null)
            {
                Debug.LogWarning("ImageDownload  GameObject is Empty");
                return;
            }

            var image = obj.GetComponent<Image>();
            if (image == null)
                return;

            SetImage_Image(url, image, isSelf);
        }

        public void SetImage_Image(string url, Image image, bool isSelfImg = false)
        {
            if (string.IsNullOrEmpty(url))
            {
                Debug.LogWarning("ImageDownload  Url is Empty");
                return;
            }

            if (image == null)
            {
                Debug.LogWarning("ImageDownload  image is Empty");
                return;
            }



            //开始下载图片前，将UITexture的主图片设置为占位图  
            int code = url.GetHashCode();
            var pic = GetImage(code);
            if (pic != null)
            {
                image.sprite = pic.sprite;
                return;
            }

            request.Enqueue(new ImageDownloadRequest() { address = url, imgTarget = image, isSelf = isSelfImg });
        }

        void Update()
        {
            if (isDownloading)
                return;

            if (request.Count <= 0)
                return;

            var temp = request.Dequeue();

            if (picList.Count >= maxCacheSpriteCount)
                ClearSpriteCache();

            StartCoroutine(DownloadImage(temp.address, temp.imgTarget, temp.address.GetHashCode(), temp.isSelf));
        }


        IEnumerator DownloadImage(string url, Image image, int code, bool isSelf)
        {
            while (isDownloading)
            {
                yield return new WaitForSeconds(0.1f);
            }

            isDownloading = true;
            Debug.LogWarning("Image Download Url:   " + url);
            WWW www = new WWW(url);
            yield return www;
            if (!string.IsNullOrEmpty(www.error))
            {
                Debug.LogWarning(www.url + " Image Download Error:  " + www.error);
                isDownloading = false;
                yield break;
            }
            Texture2D tex2d = www.texture;
            //将图片保存至缓存路径  
            //        byte[] pngData = tex2d.EncodeToPNG();                                 不存图片了..  
            //      File.WriteAllBytes(path + url.GetHashCode(), pngData);  

            Sprite m_sprite = Sprite.Create(tex2d, new Rect(0, 0, tex2d.width, tex2d.height), new Vector2(0, 0));

            if (image != null)
            {
                image.sprite = m_sprite;
            }

            var temp = new ImageDownloader();
            temp.code = code;
            temp.sprite = m_sprite;

            if (isSelf)
                selfImage = temp;
            else
                picList.Add(temp);

            isDownloading = false;
            //www.Dispose();
        }

        void ClearSpriteCache()
        {
            if (picList.Count <= 0)
                return;

            Destroy(picList[0].sprite);
            //picList[0].sprite = null;
            picList.RemoveAt(0);
        }

        void ClearAllSpriteCache()
        {
            if (selfImage != null)
            {
                Destroy(selfImage.sprite);
                selfImage = null;
                //selfImage.sprite = null;
            }

            for (int i = 0; i < picList.Count; i++)
            {
                //Resources.UnloadAsset(picList[i].sprite);
                Destroy(picList[i].sprite);
                //picList[0].sprite = null;
            }

            picList.Clear();
        }

        ImageDownloader GetImage(int code)
        {
            if (selfImage != null)
            {
                if (selfImage.code == code)
                    return selfImage;
            }

            for (int i = 0; i < picList.Count; i++)
            {
                if (picList[i].code == code)
                    return picList[i];
            }

            return null;
        }
    }
}
