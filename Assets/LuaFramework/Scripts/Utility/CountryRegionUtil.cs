using UnityEngine;

namespace GameLogic
{
    /// <summary>
    /// 设备地区（国家）识别。
    ///
    /// 数据来源与优先级：
    ///   1. Application.systemLanguage 对应的默认地区（兜底，必然有值）
    ///   2. System.Globalization.RegionInfo.CurrentRegion（Android/iOS 上由系统时区+语言推断，
    ///      与 CrashlyticsMgr 里上报 Firebase 的 country 用的是同一套 API）
    ///
    /// 写入 PlayerPrefs 后交给 Lua 侧 CountryRankManager 读取，
    /// Lua 不做任何 C# 调用（避免新增 toLua 绑定）。
    ///
    /// 约定：
    ///   - PlayerPrefs "device_country"：设备地区，只在缺失时写一次，之后不再覆盖
    ///   - PlayerPrefs "player_country"：玩家在「国家旗帜选择面板」里的选择（Lua 侧写）
    ///   玩家改过之后以 "player_country" 为准。
    /// </summary>
    public static class CountryRegionUtil
    {
        public const string KEY_DEVICE_COUNTRY = "device_country";
        public const string KEY_PLAYER_COUNTRY = "player_country";

        /// <summary>设备地区为空时的兜底值（跟随语言，再不行就 UN）。</summary>
        private const string FALLBACK_REGION = "un";

        /// <summary>
        /// 取设备地区 ISO 3166-1 alpha-2（小写）。失败时返回语言推断值，再失败返回 "un"。
        /// </summary>
        public static string GetDeviceRegionCode()
        {
            // 1) RegionInfo：真机上最贴近"设备地区"
            try
            {
                string code = System.Globalization.RegionInfo.CurrentRegion.TwoLetterISORegionName;
                if (!string.IsNullOrEmpty(code))
                {
                    return code.ToLowerInvariant();
                }
            }
            catch (System.Exception)
            {
                // RegionInfo 在极端设备上可能抛异常，落到语言推断
            }

            // 2) 语言兜底
            return LanguageToRegion(Application.systemLanguage);
        }

        /// <summary>系统语言 → 默认地区（只在取不到 RegionInfo 时使用）。</summary>
        private static string LanguageToRegion(SystemLanguage lang)
        {
            switch (lang)
            {
                case SystemLanguage.ChineseSimplified:
                case SystemLanguage.ChineseTraditional:
                case SystemLanguage.Chinese:
                    return "cn";
                case SystemLanguage.Japanese:
                    return "jp";
                case SystemLanguage.Korean:
                    return "kr";
                case SystemLanguage.English:
                    return "us";
                default:
                    return FALLBACK_REGION;
            }
        }

        /// <summary>
        /// 确保 device_country 已写入（一次性）。玩家已自选国家时不覆盖设备值。
        /// </summary>
        public static void EnsureDeviceRegionSaved()
        {
            if (PlayerPrefs.HasKey(KEY_DEVICE_COUNTRY))
            {
                return;
            }
            string code = GetDeviceRegionCode();
            PlayerPrefs.SetString(KEY_DEVICE_COUNTRY, code);
            PlayerPrefs.Save();
            Debug.Log("[CountryRegion] device_country=" + code);
        }
    }
}
