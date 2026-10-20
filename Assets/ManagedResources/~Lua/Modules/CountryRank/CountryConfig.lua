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

-- 本表顺序只表达「主要国家优先」的录入习惯，**不是**选择面板的展示顺序；
-- 面板按英文名字母序排列，见文件末尾的 CountryConfig.SortedList。
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


    -- 其余 ISO 3166-1 国家/地区（2026-10-19 一次性补齐；此前一律落到 xx 问号旗）
    -- 名称长度约束同上（中文 ≤8 字 / 英文 ≤16 字符），超长的用通行的短名；
    -- jp/kr 为 nil 的条目由 GetName 回落到 en（拉丁字母比简体中文更易读）。
    { code = "ad", zh = "安道尔"            , en = "Andorra"             , jp = "アンドラ"            , kr = "안도라" },
    { code = "af", zh = "阿富汗"            , en = "Afghanistan"         , jp = "アフガニスタン"      , kr = "아프가니스탄" },
    { code = "ag", zh = "安提瓜和巴布达"    , en = "Antigua & Barb."   , jp = "アンティグア"        , kr = "앤티가바부다" },
    { code = "ai", zh = "安圭拉"            , en = "Anguilla"            , jp = "アンギラ"            , kr = "앵귈라" },
    { code = "ao", zh = "安哥拉"            , en = "Angola"              , jp = "アンゴラ"            , kr = "앙골라" },
    { code = "aq", zh = "南极洲"            , en = "Antarctica"          , jp = "南極"                , kr = "남극" },
    { code = "as", zh = "美属萨摩亚"        , en = "American Samoa"      , jp = "米領サモア"          , kr = "미국령사모아" },
    { code = "aw", zh = "阿鲁巴"            , en = "Aruba"               , jp = "アルバ"              , kr = "아루바" },
    { code = "ax", zh = "奥兰群岛"          , en = "Åland"              , jp = "オーランド"          , kr = "올란드" },
    { code = "bb", zh = "巴巴多斯"          , en = "Barbados"            , jp = "バルバドス"          , kr = "바베이도스" },
    { code = "bd", zh = "孟加拉国"          , en = "Bangladesh"          , jp = "バングラデシュ"      , kr = "방글라데시" },
    { code = "bf", zh = "布基纳法索"        , en = "Burkina Faso"        , jp = "ブルキナファソ"      , kr = "부르키나파소" },
    { code = "bh", zh = "巴林"              , en = "Bahrain"             , jp = "バーレーン"          , kr = "바레인" },
    { code = "bi", zh = "布隆迪"            , en = "Burundi"             , jp = "ブルンジ"            , kr = "부룬디" },
    { code = "bj", zh = "贝宁"              , en = "Benin"               , jp = "ベナン"              , kr = "베냉" },
    { code = "bl", zh = "圣巴泰勒米"        , en = "St. Barthélemy"     , jp = nil                   , kr = nil },
    { code = "bm", zh = "百慕大"            , en = "Bermuda"             , jp = "バミューダ"          , kr = "버뮤다" },
    { code = "bn", zh = "文莱"              , en = "Brunei"              , jp = "ブルネイ"            , kr = "브루나이" },
    { code = "bo", zh = "玻利维亚"          , en = "Bolivia"             , jp = "ボリビア"            , kr = "볼리비아" },
    { code = "bq", zh = "加勒比荷兰"        , en = "Caribbean NL"        , jp = "カリブ・オランダ"    , kr = "카리브네덜란드" },
    { code = "bs", zh = "巴哈马"            , en = "Bahamas"             , jp = "バハマ"              , kr = "바하마" },
    { code = "bt", zh = "不丹"              , en = "Bhutan"              , jp = "ブータン"            , kr = "부탄" },
    { code = "bv", zh = "布韦岛"            , en = "Bouvet Island"       , jp = "ブーベ島"            , kr = "부베섬" },
    { code = "bw", zh = "博茨瓦纳"          , en = "Botswana"            , jp = "ボツワナ"            , kr = "보츠와나" },
    { code = "bz", zh = "伯利兹"            , en = "Belize"              , jp = "ベリーズ"            , kr = "벨리즈" },
    { code = "cc", zh = "科科斯群岛"        , en = "Cocos Islands"       , jp = "ココス諸島"          , kr = "코코스제도" },
    { code = "cd", zh = "刚果民主共和国"    , en = "DR Congo"            , jp = "コンゴ民主"          , kr = "콩고민주" },
    { code = "cf", zh = "中非共和国"        , en = "C. African Rep."     , jp = "中央アフリカ"        , kr = "중앙아프리카" },
    { code = "cg", zh = "刚果共和国"        , en = "Congo"               , jp = "コンゴ共和国"        , kr = "콩고" },
    { code = "ci", zh = "科特迪瓦"          , en = "Côte d'Ivoire"      , jp = "コートジボワール"    , kr = "코트디부아르" },
    { code = "ck", zh = "库克群岛"          , en = "Cook Islands"        , jp = "クック諸島"          , kr = "쿡제도" },
    { code = "cm", zh = "喀麦隆"            , en = "Cameroon"            , jp = "カメルーン"          , kr = "카메룬" },
    { code = "cr", zh = "哥斯达黎加"        , en = "Costa Rica"          , jp = "コスタリカ"          , kr = "코스타리카" },
    { code = "cu", zh = "古巴"              , en = "Cuba"                , jp = "キューバ"            , kr = "쿠바" },
    { code = "cv", zh = "佛得角"            , en = "Cabo Verde"          , jp = "カーボベルデ"        , kr = "카보베르데" },
    { code = "cw", zh = "库拉索"            , en = "Curaçao"            , jp = "キュラソー"          , kr = "퀴라소" },
    { code = "cx", zh = "圣诞岛"            , en = "Christmas Is."       , jp = "クリスマス島"        , kr = "크리스마스섬" },
    { code = "dj", zh = "吉布提"            , en = "Djibouti"            , jp = "ジブチ"              , kr = "지부티" },
    { code = "dm", zh = "多米尼克"          , en = "Dominica"            , jp = "ドミニカ"            , kr = "도미니카" },
    { code = "do", zh = "多米尼加"          , en = "Dominican Rep."      , jp = "ドミニカ共和国"      , kr = "도미니카공화국" },
    { code = "dz", zh = "阿尔及利亚"        , en = "Algeria"             , jp = "アルジェリア"        , kr = "알제리" },
    { code = "ec", zh = "厄瓜多尔"          , en = "Ecuador"             , jp = "エクアドル"          , kr = "에콰도르" },
    { code = "eh", zh = "西撒哈拉"          , en = "Western Sahara"      , jp = "西サハラ"            , kr = "서사하라" },
    { code = "er", zh = "厄立特里亚"        , en = "Eritrea"             , jp = "エリトリア"          , kr = "에리트레아" },
    { code = "et", zh = "埃塞俄比亚"        , en = "Ethiopia"            , jp = "エチオピア"          , kr = "에티오피아" },
    { code = "fj", zh = "斐济"              , en = "Fiji"                , jp = "フィジー"            , kr = "피지" },
    { code = "fk", zh = "福克兰群岛"        , en = "Falkland Is."        , jp = "フォークランド"      , kr = "포클랜드" },
    { code = "fm", zh = "密克罗尼西亚"      , en = "Micronesia"          , jp = "ミクロネシア"        , kr = "미크로네시아" },
    { code = "fo", zh = "法罗群岛"          , en = "Faroe Islands"       , jp = "フェロー諸島"        , kr = "페로제도" },
    { code = "ga", zh = "加蓬"              , en = "Gabon"               , jp = "ガボン"              , kr = "가봉" },
    { code = "gd", zh = "格林纳达"          , en = "Grenada"             , jp = "グレナダ"            , kr = "그레나다" },
    { code = "gf", zh = "法属圭亚那"        , en = "French Guiana"       , jp = "仏領ギアナ"          , kr = "프랑스령기아나" },
    { code = "gg", zh = "根西岛"            , en = "Guernsey"            , jp = "ガーンジー"          , kr = "건지" },
    { code = "gh", zh = "加纳"              , en = "Ghana"               , jp = "ガーナ"              , kr = "가나" },
    { code = "gi", zh = "直布罗陀"          , en = "Gibraltar"           , jp = "ジブラルタル"        , kr = "지브롤터" },
    { code = "gl", zh = "格陵兰"            , en = "Greenland"           , jp = "グリーンランド"      , kr = "그린란드" },
    { code = "gm", zh = "冈比亚"            , en = "Gambia"              , jp = "ガンビア"            , kr = "감비아" },
    { code = "gn", zh = "几内亚"            , en = "Guinea"              , jp = "ギニア"              , kr = "기니" },
    { code = "gp", zh = "瓜德罗普"          , en = "Guadeloupe"          , jp = "グアドループ"        , kr = "과들루프" },
    { code = "gq", zh = "赤道几内亚"        , en = "Eq. Guinea"          , jp = "赤道ギニア"          , kr = "적도기니" },
    { code = "gs", zh = "南乔治亚"          , en = "South Georgia"       , jp = "南ジョージア"        , kr = "사우스조지아" },
    { code = "gt", zh = "危地马拉"          , en = "Guatemala"           , jp = "グアテマラ"          , kr = "과테말라" },
    { code = "gu", zh = "关岛"              , en = "Guam"                , jp = "グアム"              , kr = "괌" },
    { code = "gw", zh = "几内亚比绍"        , en = "Guinea-Bissau"       , jp = "ギニアビサウ"        , kr = "기니비사우" },
    { code = "gy", zh = "圭亚那"            , en = "Guyana"              , jp = "ガイアナ"            , kr = "가이아나" },
    { code = "hm", zh = "赫德岛"            , en = "Heard Island"        , jp = "ハード島"            , kr = "하드섬" },
    { code = "hn", zh = "洪都拉斯"          , en = "Honduras"            , jp = "ホンジュラス"        , kr = "온두라스" },
    { code = "ht", zh = "海地"              , en = "Haiti"               , jp = "ハイチ"              , kr = "아이티" },
    { code = "im", zh = "马恩岛"            , en = "Isle of Man"         , jp = "マン島"              , kr = "맨섬" },
    { code = "io", zh = "英属印度洋领地"    , en = "Chagos Is."          , jp = "英領インド洋"        , kr = "차고스제도" },
    { code = "iq", zh = "伊拉克"            , en = "Iraq"                , jp = "イラク"              , kr = "이라크" },
    { code = "ir", zh = "伊朗"              , en = "Iran"                , jp = "イラン"              , kr = "이란" },
    { code = "je", zh = "泽西岛"            , en = "Jersey"              , jp = "ジャージー"          , kr = "저지" },
    { code = "jm", zh = "牙买加"            , en = "Jamaica"             , jp = "ジャマイカ"          , kr = "자메이카" },
    { code = "jo", zh = "约旦"              , en = "Jordan"              , jp = "ヨルダン"            , kr = "요르단" },
    { code = "ke", zh = "肯尼亚"            , en = "Kenya"               , jp = "ケニア"              , kr = "케냐" },
    { code = "kg", zh = "吉尔吉斯斯坦"      , en = "Kyrgyzstan"          , jp = "キルギス"            , kr = "키르기스스탄" },
    { code = "kh", zh = "柬埔寨"            , en = "Cambodia"            , jp = "カンボジア"          , kr = "캄보디아" },
    { code = "ki", zh = "基里巴斯"          , en = "Kiribati"            , jp = "キリバス"            , kr = "키리바시" },
    { code = "km", zh = "科摩罗"            , en = "Comoros"             , jp = "コモロ"              , kr = "코모로" },
    { code = "kn", zh = "圣基茨和尼维斯"    , en = "St. Kitts"           , jp = "セントキッツ"        , kr = "세인트키츠" },
    { code = "kp", zh = "朝鲜"              , en = "North Korea"         , jp = "北朝鮮"              , kr = "북한" },
    { code = "kw", zh = "科威特"            , en = "Kuwait"              , jp = "クウェート"          , kr = "쿠웨이트" },
    { code = "ky", zh = "开曼群岛"          , en = "Cayman Is."          , jp = "ケイマン諸島"        , kr = "케이맨제도" },
    { code = "kz", zh = "哈萨克斯坦"        , en = "Kazakhstan"          , jp = "カザフスタン"        , kr = "카자흐스탄" },
    { code = "la", zh = "老挝"              , en = "Laos"                , jp = "ラオス"              , kr = "라오스" },
    { code = "lb", zh = "黎巴嫩"            , en = "Lebanon"             , jp = "レバノン"            , kr = "레바논" },
    { code = "lc", zh = "圣卢西亚"          , en = "St. Lucia"           , jp = "セントルシア"        , kr = "세인트루시아" },
    { code = "li", zh = "列支敦士登"        , en = "Liechtenstein"       , jp = "リヒテン"            , kr = "리히텐슈타인" },
    { code = "lk", zh = "斯里兰卡"          , en = "Sri Lanka"           , jp = "スリランカ"          , kr = "스리랑카" },
    { code = "lr", zh = "利比里亚"          , en = "Liberia"             , jp = "リベリア"            , kr = "라이베리아" },
    { code = "ls", zh = "莱索托"            , en = "Lesotho"             , jp = "レソト"              , kr = "레소토" },
    { code = "ly", zh = "利比亚"            , en = "Libya"               , jp = "リビア"              , kr = "리비아" },
    { code = "ma", zh = "摩洛哥"            , en = "Morocco"             , jp = "モロッコ"            , kr = "모로코" },
    { code = "mc", zh = "摩纳哥"            , en = "Monaco"              , jp = "モナコ"              , kr = "모나코" },
    { code = "me", zh = "黑山"              , en = "Montenegro"          , jp = "モンテネグロ"        , kr = "몬테네그로" },
    { code = "mf", zh = "圣马丁"            , en = "St. Martin"          , jp = "サンマルタン"        , kr = "세인트마틴" },
    { code = "mg", zh = "马达加斯加"        , en = "Madagascar"          , jp = "マダガスカル"        , kr = "마다가스카르" },
    { code = "mh", zh = "马绍尔群岛"        , en = "Marshall Is."        , jp = "マーシャル諸島"      , kr = "마셜제도" },
    { code = "ml", zh = "马里"              , en = "Mali"                , jp = "マリ"                , kr = "말리" },
    { code = "mm", zh = "缅甸"              , en = "Myanmar"             , jp = "ミャンマー"          , kr = "미얀마" },
    { code = "mn", zh = "蒙古"              , en = "Mongolia"            , jp = "モンゴル"            , kr = "몽골" },
    { code = "mp", zh = "北马里亚纳"        , en = "N. Mariana Is."      , jp = "北マリアナ"          , kr = "북마리아나" },
    { code = "mq", zh = "马提尼克"          , en = "Martinique"          , jp = "マルティニーク"      , kr = "마르티니크" },
    { code = "mr", zh = "毛里塔尼亚"        , en = "Mauritania"          , jp = "モーリタニア"        , kr = "모리타니" },
    { code = "ms", zh = "蒙特塞拉特"        , en = "Montserrat"          , jp = "モントセラト"        , kr = "몬트세랫" },
    { code = "mu", zh = "毛里求斯"          , en = "Mauritius"           , jp = "モーリシャス"        , kr = "모리셔스" },
    { code = "mv", zh = "马尔代夫"          , en = "Maldives"            , jp = "モルディブ"          , kr = "몰디브" },
    { code = "mw", zh = "马拉维"            , en = "Malawi"              , jp = "マラウイ"            , kr = "말라위" },
    { code = "mz", zh = "莫桑比克"          , en = "Mozambique"          , jp = "モザンビーク"        , kr = "모잠비크" },
    { code = "na", zh = "纳米比亚"          , en = "Namibia"             , jp = "ナミビア"            , kr = "나미비아" },
    { code = "nc", zh = "新喀里多尼亚"      , en = "New Caledonia"       , jp = "ニューカレドニア"    , kr = "뉴칼레도니아" },
    { code = "ne", zh = "尼日尔"            , en = "Niger"               , jp = "ニジェール"          , kr = "니제르" },
    { code = "nf", zh = "诺福克岛"          , en = "Norfolk Island"      , jp = "ノーフォーク島"      , kr = "노퍽섬" },
    { code = "ng", zh = "尼日利亚"          , en = "Nigeria"             , jp = "ナイジェリア"        , kr = "나이지리아" },
    { code = "ni", zh = "尼加拉瓜"          , en = "Nicaragua"           , jp = "ニカラグア"          , kr = "니카라과" },
    { code = "np", zh = "尼泊尔"            , en = "Nepal"               , jp = "ネパール"            , kr = "네팔" },
    { code = "nr", zh = "瑙鲁"              , en = "Nauru"               , jp = "ナウル"              , kr = "나우루" },
    { code = "nu", zh = "纽埃"              , en = "Niue"                , jp = "ニウエ"              , kr = "니우에" },
    { code = "om", zh = "阿曼"              , en = "Oman"                , jp = "オマーン"            , kr = "오만" },
    { code = "pa", zh = "巴拿马"            , en = "Panama"              , jp = "パナマ"              , kr = "파나마" },
    { code = "pf", zh = "法属波利尼西亚"    , en = "French Polynesia"    , jp = "仏領ポリネシア"      , kr = "폴리네시아" },
    { code = "pg", zh = "巴布亚新几内亚"    , en = "Papua New Guinea"    , jp = "パプア"              , kr = "파푸아뉴기니" },
    { code = "pm", zh = "圣皮埃尔"          , en = "St. Pierre"          , jp = "サンピエール"        , kr = "생피에르" },
    { code = "pn", zh = "皮特凯恩"          , en = "Pitcairn"            , jp = "ピトケアン"          , kr = "핏케언" },
    { code = "pr", zh = "波多黎各"          , en = "Puerto Rico"         , jp = "プエルトリコ"        , kr = "푸에르토리코" },
    { code = "ps", zh = "巴勒斯坦"          , en = "Palestine"           , jp = "パレスチナ"          , kr = "팔레스타인" },
    { code = "pw", zh = "帕劳"              , en = "Palau"               , jp = "パラオ"              , kr = "팔라우" },
    { code = "py", zh = "巴拉圭"            , en = "Paraguay"            , jp = "パラグアイ"          , kr = "파라과이" },
    { code = "qa", zh = "卡塔尔"            , en = "Qatar"               , jp = "カタール"            , kr = "카타르" },
    { code = "re", zh = "留尼汪"            , en = "Réunion"            , jp = "レユニオン"          , kr = "레위니옹" },
    { code = "rw", zh = "卢旺达"            , en = "Rwanda"              , jp = "ルワンダ"            , kr = "르완다" },
    { code = "sb", zh = "所罗门群岛"        , en = "Solomon Is."         , jp = "ソロモン諸島"        , kr = "솔로몬제도" },
    { code = "sc", zh = "塞舌尔"            , en = "Seychelles"          , jp = "セーシェル"          , kr = "세이셸" },
    { code = "sd", zh = "苏丹"              , en = "Sudan"               , jp = "スーダン"            , kr = "수단" },
    { code = "sh", zh = "圣赫勒拿"          , en = "St. Helena"          , jp = "セントヘレナ"        , kr = "세인트헬레나" },
    { code = "sj", zh = "斯瓦尔巴群岛"      , en = "Svalbard"            , jp = "スバールバル"        , kr = "스발바르" },
    { code = "sl", zh = "塞拉利昂"          , en = "Sierra Leone"        , jp = "シエラレオネ"        , kr = "시에라리온" },
    { code = "sm", zh = "圣马力诺"          , en = "San Marino"          , jp = "サンマリノ"          , kr = "산마리노" },
    { code = "sn", zh = "塞内加尔"          , en = "Senegal"             , jp = "セネガル"            , kr = "세네갈" },
    { code = "so", zh = "索马里"            , en = "Somalia"             , jp = "ソマリア"            , kr = "소말리아" },
    { code = "sr", zh = "苏里南"            , en = "Suriname"            , jp = "スリナム"            , kr = "수리남" },
    { code = "ss", zh = "南苏丹"            , en = "South Sudan"         , jp = "南スーダン"          , kr = "남수단" },
    { code = "st", zh = "圣多美和普林西比"  , en = "São Tomé"          , jp = "サントメ"            , kr = "상투메" },
    { code = "sv", zh = "萨尔瓦多"          , en = "El Salvador"         , jp = "エルサルバドル"      , kr = "엘살바도르" },
    { code = "sx", zh = "荷属圣马丁"        , en = "Sint Maarten"        , jp = "シントマールテン"    , kr = "신트마르턴" },
    { code = "sy", zh = "叙利亚"            , en = "Syria"               , jp = "シリア"              , kr = "시리아" },
    { code = "sz", zh = "斯威士兰"          , en = "Eswatini"            , jp = "エスワティニ"        , kr = "에스와티니" },
    { code = "tc", zh = "特克斯群岛"        , en = "Turks & Caicos"      , jp = "タークス"            , kr = "터크스" },
    { code = "td", zh = "乍得"              , en = "Chad"                , jp = "チャド"              , kr = "차드" },
    { code = "tf", zh = "法属南部领地"      , en = "French S. Terr."     , jp = "仏領南方領土"        , kr = "프랑스령남부" },
    { code = "tg", zh = "多哥"              , en = "Togo"                , jp = "トーゴ"              , kr = "토고" },
    { code = "tj", zh = "塔吉克斯坦"        , en = "Tajikistan"          , jp = "タジキスタン"        , kr = "타지키스탄" },
    { code = "tk", zh = "托克劳"            , en = "Tokelau"             , jp = "トケラウ"            , kr = "토켈라우" },
    { code = "tl", zh = "东帝汶"            , en = "Timor-Leste"         , jp = "東ティモール"        , kr = "동티모르" },
    { code = "tm", zh = "土库曼斯坦"        , en = "Turkmenistan"        , jp = "トルクメニスタン"    , kr = "투르크메니스탄" },
    { code = "tn", zh = "突尼斯"            , en = "Tunisia"             , jp = "チュニジア"          , kr = "튀니지" },
    { code = "to", zh = "汤加"              , en = "Tonga"               , jp = "トンガ"              , kr = "통가" },
    { code = "tt", zh = "特立尼达和多巴哥"  , en = "Trinidad"            , jp = "トリニダード"        , kr = "트리니다드" },
    { code = "tv", zh = "图瓦卢"            , en = "Tuvalu"              , jp = "ツバル"              , kr = "투발루" },
    { code = "tz", zh = "坦桑尼亚"          , en = "Tanzania"            , jp = "タンザニア"          , kr = "탄자니아" },
    { code = "ug", zh = "乌干达"            , en = "Uganda"              , jp = "ウガンダ"            , kr = "우간다" },
    { code = "um", zh = "美国本土外小岛"    , en = "U.S. Minor Is."      , jp = "米領小島"            , kr = "미국령군소제도" },
    { code = "uy", zh = "乌拉圭"            , en = "Uruguay"             , jp = "ウルグアイ"          , kr = "우루과이" },
    { code = "uz", zh = "乌兹别克斯坦"      , en = "Uzbekistan"          , jp = "ウズベキスタン"      , kr = "우즈베키스탄" },
    { code = "va", zh = "梵蒂冈"            , en = "Vatican"             , jp = "バチカン"            , kr = "바티칸" },
    { code = "vc", zh = "圣文森特"          , en = "St. Vincent"         , jp = "セントビンセント"    , kr = "세인트빈센트" },
    { code = "ve", zh = "委内瑞拉"          , en = "Venezuela"           , jp = "ベネズエラ"          , kr = "베네수엘라" },
    { code = "vg", zh = "英属维尔京群岛"    , en = "British Virgin"      , jp = "英領バージン"        , kr = "영령버진" },
    { code = "vi", zh = "美属维尔京群岛"    , en = "U.S. Virgin"         , jp = "米領バージン"        , kr = "미령버진" },
    { code = "vu", zh = "瓦努阿图"          , en = "Vanuatu"             , jp = "バヌアツ"            , kr = "바누아투" },
    { code = "wf", zh = "瓦利斯和富图纳"    , en = "Wallis & Futuna"     , jp = "ウォリス"            , kr = "왈리스" },
    { code = "ws", zh = "萨摩亚"            , en = "Samoa"               , jp = "サモア"              , kr = "사모아" },
    { code = "ye", zh = "也门"              , en = "Yemen"               , jp = "イエメン"            , kr = "예멘" },
    { code = "yt", zh = "马约特"            , en = "Mayotte"             , jp = "マヨット"            , kr = "마요트" },
    { code = "zm", zh = "赞比亚"            , en = "Zambia"              , jp = "ザンビア"            , kr = "잠비아" },
    { code = "zw", zh = "津巴布韦"          , en = "Zimbabwe"            , jp = "ジンバブエ"          , kr = "짐바브웨" },

    { code = "xx", zh = "其他地区",   en = "Other",        jp = "その他",      kr = "기타" },
}

CountryConfig.BY_CODE = {}
for _, info in ipairs(CountryConfig.List) do
    CountryConfig.BY_CODE[info.code] = info
end

-- 兜底国家码（旗帜图与显示名都必有）
CountryConfig.FALLBACK_CODE = "xx"

----------------------------------------------------------------
-- 英文名字母序（「选择国家」面板的展示顺序）
----------------------------------------------------------------
-- 用户 2026-10-20 要求：国旗面板按英文字母顺序排，而不是按录入时的人口/市场量级。
-- 排序键取 en 字段（en 缺失才退回 zh/code），因为 en 是四语里唯一必填的拉丁字母名；
-- 若改用当前语言名排，中日韩玩家看到的顺序会各不相同，跨服交流时对不上号。

--- 变音符号归并表：排序键里 Åland → aland、Côte d'Ivoire → cote d'ivoire，
--- 否则这些条目会被排到所有 ASCII 字母之后。
local DIACRITIC = {
    ["À"] = "A", ["Á"] = "A", ["Â"] = "A", ["Ã"] = "A", ["Ä"] = "A", ["Å"] = "A",
    ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a",
    ["Æ"] = "AE", ["æ"] = "ae",
    ["Ç"] = "C", ["ç"] = "c",
    ["È"] = "E", ["É"] = "E", ["Ê"] = "E", ["Ë"] = "E",
    ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["Ì"] = "I", ["Í"] = "I", ["Î"] = "I", ["Ï"] = "I",
    ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i",
    ["Ñ"] = "N", ["ñ"] = "n",
    ["Ò"] = "O", ["Ó"] = "O", ["Ô"] = "O", ["Õ"] = "O", ["Ö"] = "O", ["Ø"] = "O",
    ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o", ["ø"] = "o",
    ["Œ"] = "OE", ["œ"] = "oe",
    ["Ù"] = "U", ["Ú"] = "U", ["Û"] = "U", ["Ü"] = "U",
    ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u",
    ["Ý"] = "Y", ["Ÿ"] = "Y", ["ý"] = "y", ["ÿ"] = "y",
    ["ß"] = "ss",
}

--- 生成排序键：变音归并 + 转小写
--- 按 UTF-8「单个字符」切分再查表（逐字节 gsub 会把多字节字符拆坏）
local function MakeSortKey(name)
    if name == nil or name == "" then
        return ""
    end
    local s = string.gsub(name, "[%z\1-\127\194-\244][\128-\191]*", function(ch)
        return DIACRITIC[ch] or ch
    end)
    return string.lower(s)
end

for _, info in ipairs(CountryConfig.List) do
    info.sortKey = MakeSortKey(info.en or info.zh or info.code)
end

--- 按英文名字母序排好的列表（CountryConfig.List 本身保持原样，其他模块不受影响）
--- 「其他地区 xx」恒排最后：它不是国家，混进 O 段（Other）既不好找也不符合习惯
CountryConfig.SortedList = {}
for _, info in ipairs(CountryConfig.List) do
    CountryConfig.SortedList[#CountryConfig.SortedList + 1] = info
end
table.sort(CountryConfig.SortedList, function(a, b)
    local aOther = (a.code == CountryConfig.FALLBACK_CODE)
    local bOther = (b.code == CountryConfig.FALLBACK_CODE)
    if aOther ~= bOther then
        return bOther
    end
    if a.sortKey ~= b.sortKey then
        return a.sortKey < b.sortKey
    end
    -- 同名字母序（如两处 "St. ..."）时用国家码兜底，保证每次排序结果一致
    return a.code < b.code
end)

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

--- 取英文名（**不看当前语言**）
-- 用途：点击国旗时的提示语。用户 2026-10-19 要求这里固定显示英文，
-- 这样中/日/韩玩家点开看到的是同一个拼写，便于跨服交流。
function CountryConfig.GetEnglishName(code)
    local c = CountryConfig.Normalize(code)
    local info = CountryConfig.BY_CODE[c]
    if not info then
        return ""
    end
    -- en 是配置里的必填字段；万一缺了退回 zh，再退回国家码本身
    return info.en or info.zh or c
end

--- 按当前语言取显示名
-- 回落顺序：当前语言 → 英文 → 中文 → 国家码
-- 🔴 2026-10-19 补齐到 ISO 全量后，大量非主要国家没有 jp/kr 译文；
--    日/韩玩家看拉丁字母远比看**简体中文**可读，所以缺译文时先落 en 再落 zh。
function CountryConfig.GetName(code)
    local c = CountryConfig.Normalize(code)
    local info = CountryConfig.BY_CODE[c]
    if not info then
        return ""
    end
    local lan = GetLan and GetLan() or 0
    if lan == 1 then
        return info.en or info.zh or c
    elseif lan == 2 then
        return info.jp or info.en or info.zh or c
    elseif lan == 3 then
        return info.kr or info.en or info.zh or c
    end
    return info.zh or info.en or c
end

return CountryConfig
