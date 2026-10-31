# REF-aso-store —— Play 商店页 / ASO 全套细节

> 从 `MEMORY.md` 的「店面 / ASO」一节整体搬来（2026-10-30，MEMORY.md 超注入上限被截断）。
> MEMORY.md 只留「一套管线多包靠 ASO_SITE」「传图=上线」「人名必查 Language.xlsx」三条，其余在这里。
> 入口 Jenkins `TS-Store-Iteration`（发布）与 `TS-ASO-Cycle`（关键词周期）；脚本 `scripts/aso/`；
> runbook `docs/play_store_iteration_aso.md`；文案真源 `data_aso/variants/<变体>/<locale>.json`，**A = 线上快照，禁改**。

## 一、多包复用同一套管线

- 🔴 **一套管线多包靠 `ASO_SITE`**（10-24 建，第二个包 Capybara Merge `com.cocos2d.piggie`）：
  数据根切 `data_aso/sites/<名>/`，`site.json` 用 `locales_mode=replace`
  （默认 merge 会把主项目 ja/zh-TW 带进没开通的包，`listings.get` 直接 404）；
  Jenkins 两 job 加 `SITE` 参数、路径走 `${ASO_DATA:-data_aso}`、发布闸门从 `C.PACKAGE` 读包名；
  `SKIP_ASSETS` 用于无素材站点跳过 ③⑤。`_get_listing` 把 404 视为「该语言未开通 ⇒ push 可新建」。

## 二、Play API 的能力边界（别按印象说）

- 🔴 `edits.listings`（title/short/full/video）与 `edits.images`
  （phoneScreenshots/featureGraphic/icon…）**都能 API 改**；**A/B 实验无公开 API**（建/看结论只能网页）。
- 🔴 `com.warera.timespace` 是**「提交即自动送审」**：`edits.commit` 带 `changesNotSentForReview`
  直接 400，不带就进审核队列 ⇒ **传图=上线，必须先问用户**；`aso_play.py` 加 `--auto-review` 才真提交。
- 核对生效看 **sha1**（list 导出 vs `derived/`），日志「已传 1 张」只是 upload 不含 commit。
- 只换置顶图写 `--image-types featureGraphic`，否则连带覆盖 16 张截图。
- 传图张数：`phoneScreenshots` ≤**8/语**、`featureGraphic` ≤**1**；`shots.json` 8 条派生 9 张，
  全推必 400 ⇒ `--shots 0,1,...,7` 挑。`deleteall+upload` 是替换语义，推几张剩几张。
- 硬上限：标题 30 / 短描述 80 / 长描述 4000（码位）。截图最短边 ≥320、最长 ≤3840、
  **长宽比 ≤2:1**、单张 ≤8MB；置顶图固定 1024×500。

## 三、文案口径（写之前必查）

- 🔴 **人名必须从 `Language.xlsx` 的 English/Japanese 列取，不许按自己熟的写法写**（10-24 栽过）：
  我写过 `King Arthur / Li Bai / Napoleon / Qin Shi Huang`，游戏内实际是
  `Arthur / Li Taipo / Napoleone / Ying Zheng`；日文同批错 4 个
  （`チンギス・ハン`→`カン`、`ジャンヌ・ダルク`→`ジャンヌ`、`キュリー夫人`→`マリ・キュリー`、`アテナ`→`アテーナー`）。
  用户下游戏搜不到人＝虚假宣传。已加 `scripts/aso/check_hero_names.py`（消解法，不切分，
  避开日文名自带 `・`）并挂进 `aso_lint.py` 闸门（基线 A 跳过）。
  **`zh-TW` 无独立列**，走 opencc `s2t` + 台湾异译白名单（`亞森羅蘋/唐吉訶德/莫札特/蕭邦`），只警告不阻断。
- 🔴 **短描述别用「名人 A 和名人 B 同队」这个模板**（10-24 用户两次纠正：先「关羽老外听不懂」，
  再「怎么老执着于关羽」）：我一个句式套了四语（`关羽和凯撒同队` / `關羽和凱撒同隊` /
  `関羽とカエサルが同じ隊に` / `Guan Yu and Caesar on one team`）—— 换个人名不算重写。
  定稿改「阵容 + 机制」：en `90 legends from history. Nine squares, five fighters. Misplace one, run ends.`、
  zh `90 位跨时代角色，历史神话小说混编。九格五席，站错一格就团灭。`、
  ja `歴史・神話・小説の英雄90人が同じ名簿に。9マス5枠、配置で生死が決まる放置カードRPG。`。
  **具体人名只放长描述的名单段**，首屏不靠认人；名单顺序按当地认知度排（en 第一行跨文化共识名、亚洲末行；中日文反之）。
- 🔴 **文案事实口径（写之前必查）**：90 个可玩角色（`HeroConfig` 110 行 − 20 个克隆体）、
  **9 格 5 席**（`FormationConfig.pos` 只到 9、6 套预设）、全角色独立 Live2D、4 种职业。
  **禁止再写** 7x7 战棋（不存在）、纯赛博少女（关羽/凯撒/爱因斯坦男角混编）、零付费墙（不可核）、100+（现为 90）。
- 🔴 **长描述走「成品整体替换」不走替换对**：`data_aso/keywords/fulltext/<locale>.txt` + `--with-fulltext`
  （Jenkins 参数 `FULLTEXT`，默认 false）。替换对撑不起缺口，成段补内容必须语义连贯。
  落盘前强检 ≤4000 字 + 字符集。`audit` 体检「字数/首屏80/品类词覆盖/字符集」，`probe` 字段在 `seed_terms.json`。
- 🔴 **重写长描述后必须跑 `aso_keyword_cycle.py audit`，品类词覆盖是硬指标**（10-31 栽过）：
  变体 N 把 L 已补到 **en 16/16、zh 14/14** 的覆盖打回 **2/16、2/14**，理由是"重写成文学化叙事更好读"
  ⇒ 等于自己关掉长描述这条唯一能承载长尾词的搜索入口。修法见变体 O：首屏先陈述机制、再自然植入 probe 词。
  另：**首屏不许用「名人 A vs. 名人 B」/「关公战秦琼」**（用户 10-24 两次否决「关羽老外听不懂」，
  且该成语在中文含贬义＝自贬）——当时只改了短描述，长描述漏改，一直留到 10-31。

- 🔴 **线上与变体的长描述不是同一份**：`audit` 查**线上**，`plan` 查**父本**。
  10-24 线上 zh-TW 曾简体混排（29 字，繁体品类词 3/15 ⇒ 搜「放置/陣容/聲優」匹配不到，
  属**搜索可见性故障**，不参与 A/B 只能直修），已随 L 修好。
  另「利用率低」**≠** 该加字：中文 900 字已装完卖点，堆到 3000 是注水降转化，收益只在「缺的品类词补上」。

## 四、关键词周期 `TS-ASO-Cycle`

- 🔴 **`TS-ASO-Cycle`（每 3 日，10-24 建）**：补原三件套缺的「设计」环。`aso_keyword_cycle.py`
  （gate 未到期 rc=3 / plan 无变更 rc=4 / lint-gate **增量口径** / record+ledger）；
  词表 `data_aso/keywords/{seed_terms,rewrite_rules}.json`（规则默认 `enabled=false` 人审关口）。
  cron 每 6h 探针 + 72h 闸门（**别用日字段 `*/3`，跨月会抖成 1~3 天**）。
  派生父本默认最新 treatment 而非 A。发布双确认 `PUBLISH=review` + `CONFIRM_PACKAGE`=包名。
- 分词红线：**片假名整段当一个词**（切了就出 `クター`/`ラク`）；汉字段才 n-gram + 词表最长优先遮蔽；
  来源分按**种类**不按份数（快照越攒越多会让所有词都变「来源 10」）。`repeat_warning` 只跟「真动过」的轮次比。
- 🔴 **`seed_terms.json` 的 `brand` 必须与线上 `title` 逐字一致**（10-31 发现）：改名后 brand 仍留着
  `neon valkyries`/`時空`/`超时空美少女` ⇒ 品牌词命中恒为 0、三轮 cycle 全 blocked、关键词环**一次都没动过线上**。
  同时词表会残留已作废事实词（`7x7`、`100体`、`零付费墙`），且 `banned` 里禁着线上标题自己在用的词（`卡牌`）⇒ 自相矛盾。
  **改名/改标题后必做：同步 brand + 扫一遍 core/modifier/banned 是否与新标题打架**。

## 五、截图 / 店面图

- 🔴 这游戏**纯竖版**（`defaultScreenOrientation=0`）但线上 4 张手机截图是 1920×1080 横版
  ⇒ 两条黑边、首图浪费一半面积。竖版源图在 `时空美少女物料/`（597~720px 宽，要放大 1.8×）。
- 🔴 截图底部 1/3 常挂**中文世界聊天**，必须按图配 `crop_bottom` 裁；
  卖点条**预留**在画布下方，不能叠画面（会被聊天行糊穿）。
- 🔴 **用户偏好横版截图**（10-24 否决竖版）⇒ 走 `fusion_shots.py`：置顶图 1024×500 比例 2.048 只超 0.048，
  **补边到 1024×520（1.969）即可**，画面不动、补边用首末行高斯模糊。
  **定稿 6 组序 `0102,2019,1013,0922,0715,1821`**；`0823`/`1624` 素材不合格已 `_retired`，`1125`/`1426` 没上。
- 换皮：`aso_art.py plan/seed/trigger/ingest`；`TS-Art-Restyle` 的 `ASSET` 是相对工程根路径，
  `WRITE_BACK` 必须 false；并行靠浏览器租约 `TSG_LEASE_OWNER=$JOB_NAME-$BUILD_NUMBER`。
  ⚠ 出图现在还会被 `scripts/image/gen_pace.py` 按账号限速（见 MEMORY.md 美术管线节）。
- 🎨 全流程 → **详见 `REF-promo-shots.md`**（可复用链路、③ 阶段顺序、选角色、三层拼装、`band` 取景、
  店面图三坑、合规、验收页）。两条必记：**两侧角色禁止直接贴立绘**（按特征卡重绘）；
  **特征卡禁写 `bare legs/bare feet`**（会画高开叉露胯，Play 必拒）。

## 六、A/B 读数

- 单窗口 ≥7 天且 ≥1000 访问才读，否则直接报「数据不足」；是顺序窗口对比，非随机分流。
- 🔴 **但 1000 访问门槛对本包已失效**（10-31 实测）：日均商店页访问仅 **16 人**（455/28 天），
  凑满 1000 需 **62 天** ⇒ 任何 14 天窗口在设计上就读不出数。**别再拿「等窗口到期」当不换版的理由**；
  这个量级只能按「周环比 + 只看转化率」，转化率是比值、不受绝对量影响。
- 基线值（2026-10-31，28 天窗口）：访问者 455 / 安装点击 50 / 点击率 11% / **商品详情转化率 7.2%**。
  7.2% 偏低（休闲品类常见 15~30%），这是唯一还能在小样本下判读的指标。
- 实验状态机的坑：N 从创建到被截断**全程 `planned`、`readout` 恒空**（5 个实验文件无一读过数）
  ⇒ 这套东西目前只记录不测量。改版前至少手工存一份 Console 三数快照。

## 七、改名与变体时间线（截至 10-24）

- 🟢 **10-24 09:41 变体 N 已送审：游戏改名为《群星列阵》/`Starhost`**（四语 title+short+full 全量重写，
  `data_aso/variants/N/`，lint 红 0 黄 0，edit 已 commit ⇒ 进审核队列）。
  旧名 时空群英／超时空美少女／Neon Valkyries／時空を旅する美少女 **全部作废**。
  实验 `aso-20261024-rename-N`（A→N，14 天）；L 与 M 均标 `superseded`（M 的中文窗口只活 16 分钟）。
  ⚠️ 改名不可 A/B 且与文案纠错同批 ⇒ 只能回答「N 整体是否优于 A」，不能归因到名字。
  命名依据：现名是不可独占的通用词堆叠，且「时空/裂隙/赛博霓虹」整条赛道已被《时隙之旅/时之裂隙》逐项占满。
- 🟢 **10-24 已上线变体 L（四语全量文案）**：title/short 沿用 B，长描述换成 `fulltext` 成品。
  实验 `aso-20261024-copy-L`（已被 N 取代）；旧 B 窗口标 `superseded`（从未上线，别用 `close`——它强制填 winner）。
- 🟢 **10-24 02:12 中文标题曾换为「时空群英：放置阵型RPG」**（变体 `M` = L + 只换 zh 标题，用户拍板；
  线上已核验）。实验 `aso-20261024-title-zh-M`（L→M，14 天）。
  ⚠️ L 的中文窗口只活了 16 分钟 ⇒ `aso-20261024-copy-L` 的 locales 已收窄为 en-US/ja-JP。
  **中文短描述仍是旧口径（赛博少女/7x7战棋/零付费墙）与标题打架，未改。**
- ✅ **com.warera.timespace 四语各 6 张截图 + 1 张置顶图**（`aso_play list` 实测，
  `phoneScreenshots:6/featureGraphic:1`）。「0 截图 0 置顶图」是 **capybara 包**的状态，
  别串包（10-24 曾因此误判成阻塞项）。
- ⚠️ Jenkins META 布尔参数**必须写 `type:"bool"`**，写 `"boolean"` 会变字符串参数
  ⇒ `when { expression { params.X } }` 恒真。
