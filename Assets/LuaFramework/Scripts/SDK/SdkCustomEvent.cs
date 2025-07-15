using System.Collections.Generic;
using GameLogic;

namespace SDK
{
    public class SdkCustomEvent
    {
        public static void CustomEvent(string param)
        {
            CustomEvent(0, param);
        }

        public static void CustomEvent(int type, string param)
        {
            if (AppConst.isSDKLogin)
            {
                SDKManager.Instance.CustomEvent(type, param);
            }
        }
    }
}