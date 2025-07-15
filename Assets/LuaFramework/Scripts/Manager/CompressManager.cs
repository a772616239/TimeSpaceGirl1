using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;
using System;
using GameCore;

public class CompressManager : UnitySingleton<CompressManager>
{
    /// <summary>
    /// Compresses the picture.
    /// </summary>
    /// <param name="imagePath">Image path.</param>
    /// <param name="action">成功返回原地址，失败返回null.</param>
    public void CompressPicture(int compressSize, string sourcePath, string outPath, Action<bool> complete)
    {
        StartCoroutine(Compress(compressSize, sourcePath, outPath, delegate(bool isSucess)
        {
            if (complete != null)
                complete(isSucess);
        }));
    }

    IEnumerator Compress(int compressSize, string sourcePath, string outPath, Action<bool> action)
    {
        int count = 0;
        while (!File.Exists(sourcePath))
        {
            yield return new WaitForSeconds(0.1f);
            count++;
            if (count >= 10)
            {
                if (action != null)
                    action(false);

                yield break;
            }
        }

        FileInfo f = new FileInfo(sourcePath);
        if ((f.Length / 1024) >= compressSize)
        {
            Debug.Log("开始压缩，图片原始大小为：" + f.Length / 1000 + "Kb");
        }

        int qualityI = 50;
        WWW www = new WWW("file:///" + sourcePath);
        yield return www;
        if (www.error != null)
        {
            if (action != null)
                action(false);
            //发返回失败
        }
        else
        {
            Texture2D t2d = www.texture;
            byte[] b = t2d.EncodeToJPG(qualityI);
            Debug.Log("图原始读取的字节数 " + (b.Length / 1000).ToString());

            while ((b.Length / 1024) >= compressSize && qualityI>0)
            {
                qualityI -= 5;
                b = t2d.EncodeToJPG(qualityI);
                Debug.Log("当前大小：" + b.Length / 1000);
            }

            Debug.Log("压缩成功，当前大小：" + b.Length / 1000);
            File.WriteAllBytes(outPath, b);

            if (action != null)
                action(true);
        }

        www.Dispose();
    }
}
