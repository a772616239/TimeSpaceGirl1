# 📢 《超时空美少女》运营公告多语言配置与调试手册

本手册详细记录了游戏运营公告（Notice）系统的多语言支持方案、Java 后端崩溃根因分析以及 MongoDB 的标准数据结构重建流程，以便后续维护与快速排查。

---

## 🛠️ 一、问题回顾与根因分析

在进行公告的配置与展示调试时，曾遇到以下两个关键技术故障：

### 1. 客户端解析多语言时空指针/类型不匹配崩溃
*   **异常表现**：
    ```
    LuaException: Modules/Login/NoticePopup:96: attempt to concatenate local 'langCode' (a nil value)
    ```
*   **根因分析**：
    *   Lua 中的正则匹配操作 `string.match(part, "^(%w+):(.+)$")` 依靠换行符划分时，由于公告内容中存在物理换行符 `\n`，导致匹配规则被破坏，解析出 `langCode` 为 `nil` 并引发字符串拼接报错。
    *   **解决方案**：客户端做 `pcall` 与安全解析防御。同时，**数据库内存储的物理换行符必须双斜杠转义存为 `\\n` 文本形式**，待客户端取到多语言片段后，再通过 Lua 进行 `string.gsub(localizedContent, "\\n", "\n")` 转换为 UI 内的换行符。

### 2. Java 后端请求公告接口返回空字符串崩溃
*   **异常表现**：
    ```
    [NetworkManager]::HttpGet_Co succ result:
    ```
*   **根因分析**：
    *   反编译 Tomcat 后端 `GetNoticeController.class` 发现，后台在获取数据库文档时，采取了**强校验**类型和字段：
        ```java
        notice.setTitle(dbObject.get("title").toString());
        notice.setContent(dbObject.get("content").toString());
        notice.setLeve(Integer.parseInt(dbObject.get("grade").toString()));
        notice.setStartTime(Long.parseLong(dbObject.get("publish_time").toString()));
        ```
    *   如果数据库的 `notice_info` 集合中，存在任意一条**缺少 `grade` 或 `publish_time`** 的旧测试数据，或者在 Mongo Shell 中以浮点数形式存入了数值（如 `grade: 1` 存为 `1.0`），Java 会触发 `NullPointerException` 或 `NumberFormatException` 异常。
    *   后端捕获该异常后进行了拦截并打印，但未输出任何有效的 JSON 回包，导致接口返回空文本，使客户端在 `json.decode(str)` 时抛出 `Expected value but found T_END` 错误。

---

## 💾 二、MongoDB 数据结构标准定义

通过剖析前端 Lua 与后端 Java 逻辑，我们完成了前后端数据映射的整理。正确的字段定义如下：

| MongoDB 字段 | 数据类型 | 映射 POJO / 前端字段 | 作用及配置规范 |
| :--- | :--- | :--- | :--- |
| **`title`** | `String` | `data.parms.title` | **前端实际展示的公告具体内容**。必须写入带有语言标识的 `|` 分割字符串，例如：`10001:中文内容\|10101:English`。 |
| **`content`** | `String` | `data.parms.content` | **公告标题**。仅作后台管理展示和前端简短标识用，例如 `"开服公告"`。 |
| **`grade`** | `String` (推荐) | `leve` | **公告优先级**。有效优先级为 `0`, `1`, `2`。采用字符串包裹 `\"1\"` 能 100% 免疫数字存储精度溢出及转换问题。 |
| **`publish_time`**| `String` (推荐) | `startTime` | **发布时间戳**（毫秒值）。TreeSet 依此进行排序，获取最新、最大值的公告进行展示。 |

---

## 🚀 三、数据库快速重建与插入脚本

当需要更新公网/测试服公告时，请**务必先清空损坏的旧脏数据**，再执行兼容形式的强字符串插入：

### 1. 清空集合所有数据（关键步骤）
```javascript
use x1_cn_test_login;
db.notice_info.deleteMany({});
```

### 2. 执行数据写入
```javascript
db.notice_info.insertOne({
  title: "10001:<size=32><color=#FF66CC><b>🎉《超时空美少女》全次元盛大启航！🎉</b></color></size>\\n\\n<color=#FFCC00>亲爱的指挥官：</color>\\n次元之门正式开启！即刻登录，集结你的<color=#FF99FF>Live2D女神战队</color>，开启超时空冒险！\\n\\n<color=#FF9900>⚔️ 独创9×9深度策略</color>\\n► 战场布局定胜负，激活<color=#99FF99>专属阵容羁绊</color>逆转战局！\\n\\n<color=#66CCFF>限时开服庆典</color>\\n► <color=#00FF00>全剧情+PvP奖励0付费墙</color>！\\n► <color=#FFD700>开服8日登录签到</color>：每日领豪华资源，第8天必得SSR美少女！\\n► <color=#99FF99>活动免费送强力角色</color>：收藏家福音！\\n► <color=#FFA500>限时开服馈赠</color>：大量奖励等你抽取！\\n► <color=#FF6347>超值首次豪送</color>：登录即领超强传说装备套装！\\n► <color=magenta>高SSR概率+保底</color>：良心概率透明无忧！\\n\\n<color=#FF99FF> 沉浸视听盛宴</color>\\n► 全角色<color=#FF66CC>Live2D动态</color>跃然眼前\\n► <color=#66FFFF>多张精美赛博科技地图</color>挑战更高难度即可解锁|10101:<size=32><color=#FF66CC><b>🎉 Time-Space Girl: Grand Launch Across Dimensions! 🎉</b></color></size>\\n\\n<color=#FFCC00>Dear Commander:</color>\\nThe dimensional gates are officially open! Log in now, assemble your <color=#FF99FF>Live2D Goddess Squad</color>, and embark on a time-space adventure!\\n\\n<color=#FF9900>⚔️ Unique 9x9 Tactical Strategy</color>\\n► Grid placement determines victory. Activate <color=#99FF99>exclusive faction synergies</color> to turn the tide of battle!\\n\\n<color=#66CCFF>Limited-Time Launch Celebration</color>\\n► <color=#00FF00>Full Story & PvP rewards - 0 paywalls</color>!\\n► <color=#FFD700>8-Day Launch Log-in</color>: Claim daily rewards, guaranteed SSR girl on Day 8!\\n► <color=#99FF99>Free SSR Events</color>: Collector\'s paradise!\\n► <color=#FFA500>Special Launch Summon</color>: Tons of resources to summon your favorite characters!\\n► <color=#FF6347>Ultimate First Log-in Gift</color>: Claim a powerful legendary gear set instantly!\\n► <color=magenta>High SSR Rates + Pity System</color>: Honest rates and guaranteed success!\\n\\n<color=#FF99FF> Immersive Audio-Visual Feast</color>\\n► All characters brought to life with vibrant <color=#FF66CC>Live2D animation</color>\\n► <color=#66FFFF>Multiple gorgeous cyberpunk sci-fi maps</color> unlocked as you progress!|10201:<size=32><color=#FF66CC><b>🎉《時空美少女》全次元盛大ローンチ！🎉</b></color></size>\\n\\n<color=#FFCC00>親愛なる指揮官へ：</color>\\n次元の門が正式に開かれました！今すぐログインして、あなたの<color=#FF99FF>Live2D女神チーム</color>を結成し、時空を超える冒険に出かけましょう！\\n\\n<color=#FF9900>⚔️ 独創的な9×9奥深い戦略</color>\\n► 戦場の配置が勝敗を決める。専用の<color=#99FF99>編成絆</color>を有効化して、戦局を逆転させましょう！\\n\\n<color=#66CCFF>期間限定リリース記念キャンペーン</color>\\n► <color=#00FF00>全ストーリー＋PvP報酬は完全無課金で獲得可能</color>！\\n► <color=#FFD700>リリース記念8日ログインボーナス</color>：毎日豪華な資源を獲得でき、8日目には必ずSSR美少女をプレゼント！\\n► <color=#99FF99>イベントで強力なキャラクターを無料プレゼント</color>：コレクター必見！\\n► <color=#FFA500>期間限定リリース特別召喚</color>：お気に入りキャラを獲得する大チャンス！\\n► <color=#FF6347>超豪华・初回ログインプレゼント</color>：強力な伝説装備セットがすぐに貰える！\\n► <color=magenta>高SSR確率＋天井システム</color>：安心の確率と保証！\\n\\n<color=#FF99FF> 没入感あふれる視聴覚の饗宴</color>\\n► 全キャラクターが美麗な<color=#FF66CC>Live2Dアニメーション</color>で躍動\\n► <color=#66FFFF>複数の豪華なサイバーパンクマップ</color>が進捗に合わせて解放！",
  content: "开服公告",
  grade: "1",
  publish_time: "1753142400000"
});
```

---

## 🌐 四、多语言语系映射对照

在客户端 Lua 校验模块（如 `NameManager.lua` / `functions.lua`）中，系统支持的语言标识映射如下：

*   **`10001`** -> 简体中文 (`ZH_CN`)
*   **`10101`** -> 英语 (`EN`)
*   **`10201`** -> 日语 (`JA`)

---

## 🔍 五、本地调试补充说明

如果需要在本地搭建 Tomcat 联调测试环境：
1. **修改客户端连接**：打开 `Assets/Resources/version.txt` 将 `"serverUrl"` 指向 `http://127.0.0.1:8080/`。
2. **Mac 本地命令行快捷更新**（在 Mac 命令行直接一键注入本地 MongoDB）：
   ```bash
   mongo admin -u admin -p 123456 --eval "db.getSiblingDB('x1_cn_test_login').notice_info.updateOne({ _id: '1' }, { \$set: { title: '10001:中文公告...|10101:English...|10201:Japanese...', content: '开服公告', grade: '1', publish_time: '1753142400000' } }, { upsert: true })"
   ```
