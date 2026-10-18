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
--
-- ⚠️ 名称长度约束：选择面板的格子 nameText 宽 180、字号 22（横向 Overflow 开启）。
--    中文 ≤8 字、英文 ≤16 字符、日/韩文 ≤8 字，超了会溢到隔壁格子。
--    因此 Bosnia and Herzegovina 一类长名在列表里用短名（Bosnia / ボスニア / 보스니아）。
CountryConfig.List = {
    { code = "cn", zh = "中国",       en = "China",        jp = "中国",       kr = "중국" },
    { code = "tw", zh = "中国台湾",   en = "Taiwan",       jp = "台湾",       kr = "대만" },
    { code = "hk", zh = "中国香港",   en = "Hong Kong",    jp = "香港",       kr = "홍콩" },
    { code = "mo", zh = "中国澳门",   en = "Macao",        jp = "マカオ",     kr = "마카오" },
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

    -- 欧洲逐国（原先只有一面「欧洲其他 eu」，玩家无法表达具体国家）
    { code = "nl", zh = "荷兰",       en = "Netherlands",  jp = "オランダ",   kr = "네덜란드" },
    { code = "be", zh = "比利时",     en = "Belgium",      jp = "ベルギー",   kr = "벨기에" },
    { code = "ch", zh = "瑞士",       en = "Switzerland",  jp = "スイス",     kr = "스위스" },
    { code = "at", zh = "奥地利",     en = "Austria",      jp = "オーストリア", kr = "오스트리아" },
    { code = "se", zh = "瑞典",       en = "Sweden",       jp = "スウェーデン", kr = "스웨덴" },
    { code = "no", zh = "挪威",       en = "Norway",       jp = "ノルウェー", kr = "노르웨이" },
    { code = "dk", zh = "丹麦",       en = "Denmark",      jp = "デンマーク", kr = "덴마크" },
    { code = "fi", zh = "芬兰",       en = "Finland",      jp = "フィンランド", kr = "핀란드" },
    { code = "ie", zh = "爱尔兰",     en = "Ireland",      jp = "アイルランド", kr = "아일랜드" },
    { code = "pt", zh = "葡萄牙",     en = "Portugal",     jp = "ポルトガル", kr = "포르투갈" },
    { code = "gr", zh = "希腊",       en = "Greece",       jp = "ギリシャ",   kr = "그리스" },
    { code = "pl", zh = "波兰",       en = "Poland",       jp = "ポーランド", kr = "폴란드" },
    { code = "cz", zh = "捷克",       en = "Czechia",      jp = "チェコ",     kr = "체코" },
    { code = "hu", zh = "匈牙利",     en = "Hungary",      jp = "ハンガリー", kr = "헝가리" },
    { code = "ro", zh = "罗马尼亚",   en = "Romania",      jp = "ルーマニア", kr = "루마니아" },
    { code = "bg", zh = "保加利亚",   en = "Bulgaria",     jp = "ブルガリア", kr = "불가리아" },
    { code = "ua", zh = "乌克兰",     en = "Ukraine",      jp = "ウクライナ", kr = "우크라이나" },
    { code = "sk", zh = "斯洛伐克",   en = "Slovakia",     jp = "スロバキア", kr = "슬로바키아" },
    { code = "si", zh = "斯洛文尼亚", en = "Slovenia",     jp = "スロベニア", kr = "슬로베니아" },
    { code = "hr", zh = "克罗地亚",   en = "Croatia",      jp = "クロアチア", kr = "크로아티아" },
    { code = "rs", zh = "塞尔维亚",   en = "Serbia",       jp = "セルビア",   kr = "세르비아" },
    { code = "lt", zh = "立陶宛",     en = "Lithuania",    jp = "リトアニア", kr = "리투아니아" },
    { code = "lv", zh = "拉脱维亚",   en = "Latvia",       jp = "ラトビア",   kr = "라트비아" },
    { code = "ee", zh = "爱沙尼亚",   en = "Estonia",      jp = "エストニア", kr = "에스토니아" },
    { code = "is", zh = "冰岛",       en = "Iceland",      jp = "アイスランド", kr = "아이슬란드" },
    { code = "lu", zh = "卢森堡",     en = "Luxembourg",   jp = "ルクセンブルク", kr = "룩셈부르크" },
    { code = "md", zh = "摩尔多瓦",   en = "Moldova",      jp = "モルドバ",   kr = "몰도바" },
    { code = "al", zh = "阿尔巴尼亚", en = "Albania",      jp = "アルバニア", kr = "알바니아" },
    { code = "ba", zh = "波黑",       en = "Bosnia",       jp = "ボスニア",   kr = "보스니아" },
    { code = "mk", zh = "北马其顿",   en = "N. Macedonia", jp = "北マケドニア", kr = "북마케도니아" },
    { code = "ge", zh = "格鲁吉亚",   en = "Georgia",      jp = "ジョージア", kr = "조지아" },
    { code = "am", zh = "亚美尼亚",   en = "Armenia",      jp = "アルメニア", kr = "아르메니아" },
    { code = "az", zh = "阿塞拜疆",   en = "Azerbaijan",   jp = "アゼルバイジャン", kr = "아제르바이잔" },
    { code = "mt", zh = "马耳他",     en = "Malta",        jp = "マルタ",     kr = "몰타" },
    { code = "cy", zh = "塞浦路斯",   en = "Cyprus",       jp = "キプロス",   kr = "키프로스" },
    { code = "by", zh = "白俄罗斯",   en = "Belarus",      jp = "ベラルーシ", kr = "벨라루스" },

    -- 其他常见国家/地区
    { code = "nz", zh = "新西兰",     en = "New Zealand",  jp = "ニュージーランド", kr = "뉴질랜드" },
    { code = "za", zh = "南非",       en = "South Africa", jp = "南アフリカ", kr = "남아프리카" },
    { code = "eg", zh = "埃及",       en = "Egypt",        jp = "エジプト",   kr = "이집트" },
    { code = "il", zh = "以色列",     en = "Israel",       jp = "イスラエル", kr = "이스라엘" },
    { code = "cl", zh = "智利",       en = "Chile",        jp = "チリ",       kr = "칠레" },
    { code = "co", zh = "哥伦比亚",   en = "Colombia",     jp = "コロンビア", kr = "콜롬비아" },
    { code = "pe", zh = "秘鲁",       en = "Peru",         jp = "ペルー",     kr = "페루" },
    { code = "pk", zh = "巴基斯坦",   en = "Pakistan",     jp = "パキスタン", kr = "파키스탄" },

    { code = "xx", zh = "其他地区",   en = "Other",        jp = "その他",      kr = "기타" },
}

CountryConfig.BY_CODE = {}
for _, info in ipairs(CountryConfig.List) do
    CountryConfig.BY_CODE[info.code] = info
end

-- 兜底国家码（旗帜图与显示名都必有）
CountryConfig.FALLBACK_CODE = "xx"

-- 别名：设备 RegionInfo 可能返回这些码，归并到我们有的旗帜
-- ⚠️ mo（中国澳门）已有自己的旗帜，别再并到 hk
CountryConfig.ALIAS = {
    uk = "gb",
    el = "gr",
    cn_hk = "hk",
    cn_tw = "tw",
    cn_mo = "mo",
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

return CountryConfig
