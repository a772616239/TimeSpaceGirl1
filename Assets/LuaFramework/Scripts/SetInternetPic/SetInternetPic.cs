using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class SetInternetPic
{
 
    public static void SetInternetPicture(string str,Image image)
    {
        AsyncImageDownload.Instance.SetAsyncImage(str, image);
    }
}