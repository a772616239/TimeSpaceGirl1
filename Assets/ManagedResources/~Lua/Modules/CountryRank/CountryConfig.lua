--[[
 * 国家排行榜 —— 国家基础数据（客户端唯一真源）
 *
 * 为什么数据放在 Lua 而不是配置表：
 *   这一份是「视觉资源 ⇄ 国家码 ⇄ 玩家本地选择」的静态映射，纯客户端概念，
 *   与服务端数值配置无关；放进 xlsx 会牵动导表 + CRC32 + 服务端 TSV 三条链，
 *   而它本身没有任何服务端消费方。后续若服务端下发玩家国家，也只需把
 *   CountryRankManager 的数据源换掉，这里的表继续用。
 *
 * 字段：
 *   code  ISO 3166-1 alpha-2（小写，与 CountryRegionUtil 写入 PlayerPrefs 的大小写一致）
 *   sprite 旗帜图集里的 sprite 名（对应 Assets/ManagedResources/Atlas/CountryRankPanelAtlas）
 *   zh/en/jp/kr  显示名。缺省回落 zh。
 *
 * 旗帜图只有这些国家时，未列出的国家码一律落到 "xx"（灰底问号旗）。
--]]

CountryConfig = {}

-- 展示顺序即「选择国家」面板的排列顺序（人口/市场量级优先）
CountryConfig.List = {
    { code = "cn", zh = "中国",       en = "China",        jp = "中国",       kr = "중국" },
    { code = "tw", zh = "中国台湾",   en = "Taiwan",       jp = "台湾",       kr = "대만" },
    { code = "hk", zh = "中国香港",   en = "Hong Kong",    jp = "香港",       kr = "홍콩" },
    { code = "jp", zh = "日本",       en = "Japan",        jp = "日本",       kr = "일본" },
    { code = "kr", zh = "韩国",       en = "Korea",        jp = "韓国",       kr = "대한민국" },
    { code = "us", zh = "美国",       en = "United States", jp = "アメリカ",  kr = "미국" },
    { code = "gb", zh = "英国",       en = "United Kingdom", jp = "イギリス",  kr = "영국" },
    { code = "de", zh = "德国",       en = "Germany",      jp = "ドイツ",     kr = "독일" },
    { code = "fr", zh = "法国",       en = "France",       jp = "フランス",   kr = "프랑스" },
    { code = "it", zh = "意大利",     en = "Italy",        jp = "イタリア",   kr = "이탈리아" },
    { code = "es", zh = "西班牙",     en = "Spain",        jp = "スペイン",   kr = "스페인" },
    { code = "ru", zh = "俄罗斯",     en = "Russia",       jp = "ロシア",     kr = "러시아" },
    { code = "br", zh = "巴西",       en = "Brazil",       jp = "ブラジル",   kr = "브라질" },
    { code = "ca", zh = "加拿大",     en = "Canada",       jp = "カナダ",     kr = "캐나다" },
    { code = "au", zh = "澳大利亚",   en = "Australia",    jp = "オーストラリア", kr = "호주" },
    { code = "mx", zh = "墨西哥",     en = "Mexico",       jp = "メキシコ",   kr = "멕시코" },
    { code = "ar", zh = "阿根廷",     en = "Argentina",    jp = "アルゼンチン", kr = "아르헨티나" },
    { code = "sg", zh = "新加坡",     en = "Singapore",    jp = "シンガポール", kr = "싱가포르" },
    { code = "th", zh = "泰国",       en = "Thailand",     jp = "タイ",       kr = "태국" },
    { code = "vn", zh = "越南",       en = "Vietnam",      jp = "ベトナム",   kr = "베트남" },
    { code = "id", zh = "印度尼西亚", en = "Indonesia",    jp = "インドネシア", kr = "인도네시아" },
    { code = "my", zh = "马来西亚",   en = "Malaysia",     jp = "マレーシア", kr = "말레이시아" },
    { code = "ph", zh = "菲律宾",     en = "Philippines",  jp = "フィリピン", kr = "필리핀" },
    { code = "in", zh = "印度",       en = "India",        jp = "インド",     kr = "인도" },
    { code = "tr", zh = "土耳其",     en = "Turkey",       jp = "トルコ",     kr = "튀르키예" },
    { code = "sa", zh = "沙特阿拉伯", en = "Saudi Arabia", jp = "サウジアラビア", kr = "사우디아라비아" },
    { code = "ae", zh = "阿联酋",     en = "UAE",          jp = "アラブ首長国連邦", kr = "아랍에미리트" },
    { code = "eu", zh = "欧洲其他",   en = "Europe",       jp = "ヨーロッパ",  kr = "유럽" },
    { code = "xx", zh = "其他地区",   en = "Other",        jp = "その他",      kr = "기타" },
}

CountryConfig.BY_CODE = {}
for _, info in ipairs(CountryConfig.List) do
    CountryConfig.BY_CODE[info.code] = info
end

-- 兜底国家码（旗帜图与显示名都必有）
CountryConfig.FALLBACK_CODE = "xx"

-- 别名：设备 RegionInfo 可能返回这些码，归并到我们有的旗帜
CountryConfig.ALIAS = {
    uk = "gb",
    el = "gr",
    mo = "hk",
    cn_hk = "hk",
    cn_tw = "tw",
}

--- 规整国家码：小写、去空格、别名归并、未知码落到 xx
function CountryConfig.Normalize(code)
    if code == nil then
        return CountryConfig.FALLBACK_CODE
    end
    local c = tostring(code):lower():gsub("%s", "")
    if c == "" then
        return CountryConfig.FALLBACK_CODE
    end
    c = CountryConfig.ALIAS[c] or c
    if not CountryConfig.BY_CODE[c] then
        return CountryConfig.FALLBACK_CODE
    end
    return c
end

--- 旗帜 sprite 名
function CountryConfig.GetFlagSprite(code)
    local c = CountryConfig.Normalize(code)
    return "cn2-guoqi_" .. c
end

--- 按当前语言取显示名
function CountryConfig.GetName(code)
    local c = CountryConfig.Normalize(code)
    local info = CountryConfig.BY_CODE[c]
    if not info then
        return ""
    end
    local lan = GetLan and GetLan() or 0
    if lan == 1 and info.en then
        return info.en
    elseif lan == 2 and info.jp then
        return info.jp
    elseif lan == 3 and info.kr then
        return info.kr
    end
    return info.zh or info.en or c
end
