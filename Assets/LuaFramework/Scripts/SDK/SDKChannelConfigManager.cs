using System.IO;
using UnityEngine;

namespace SDK
{
    public enum ChannelType
    {
        None = 0,
        Android_BaiDu,
        iOS_BaiDu,
        iOS_BaiDu_Test,
        Android_9377,
        iOS_9377,
        Android_ChiTu,
        Android_ilod,
        Android_ilod_OneStore,
        Android_ilod_OneStoreCB,
        iOS_ilod,
        Android_QuickGame,
        Android_QuickGame_douyin,
        iOS_QuickGame,
        Android_99,
        Android_99_Child,
        Android_99_Child2,
        Android_99_Child3,
        Android_99_Child4,
        Android_ChangWei,
        iOS_ChangWei,
    }


    public class SDKChannelConfigManager
    {
        private static SDKChannelConfigManager instance;
        public static SDKChannelConfigManager Instance
        {
            get
            {
                if (instance == null)
                {
                    instance = new SDKChannelConfigManager();
                    ReadTxt();
                }
                return instance;
            }
        }

        private string channelType = string.Empty;
        public string ChannelType
        {
            get
            {
                return channelType;
            }
            set
            {
                if (channelType != value)
                {
                    channelType = value;
                    Debug.LogError(channelType);
                    SaveTxt();
                }
            }
        }

        public static void ReadTxt()
        {
            TextAsset textAsset = Resources.Load<TextAsset>("SDKChannelConfig");
            if (textAsset == null)
            {
                textAsset = new TextAsset();
            }
            else
            {
                instance.channelType = textAsset.text;
            }
        }

        public static void SaveTxt()
        {
            string txt = "";

            if (instance != null)
            {
                txt = instance.channelType;
            }

            string fileName = "Assets/Resources/SDKChannelConfig.txt";

            if (!Directory.Exists(Path.GetDirectoryName(fileName)))
                return;

            using (FileStream fs = File.Open(fileName, FileMode.Create))
            {
                using (StreamWriter sw = new StreamWriter(fs))
                {
                    sw.Write(txt);
                }
            }
        }
    }
}
