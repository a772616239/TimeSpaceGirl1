using System.Collections.Generic;

public class MultiLanguageHelper
{
    private static Dictionary<int, MultiLanguageItem> _multiLanDic;
    /// <summary>
    /// 多语言类型和文件夹字典
    /// </summary>
    public static Dictionary<int, MultiLanguageItem> MultiLanguageDictionary
    {
        get
        {
            if (_multiLanDic == null)
            {
                _multiLanDic = new Dictionary<int, MultiLanguageItem>();
                _multiLanDic.Add(0, new MultiLanguageItem() { DirName = "artfont_zh", SpriteNameSuffix = "_zh" });
                _multiLanDic.Add(1, new MultiLanguageItem() { DirName = "artfont_en", SpriteNameSuffix = "_en" });
                _multiLanDic.Add(2, new MultiLanguageItem() { DirName = "artfont_jp", SpriteNameSuffix = "_jp" });
                _multiLanDic.Add(3, new MultiLanguageItem() { DirName = "artfont_kr", SpriteNameSuffix = "_kr" });
            }

            return _multiLanDic;
        }
    }

    public class MultiLanguageItem
    {
        /// <summary>
        /// 文件夹名字
        /// </summary>
        public string DirName;
        /// <summary>
        /// 图片后缀
        /// </summary>
        public string SpriteNameSuffix;
    }
}