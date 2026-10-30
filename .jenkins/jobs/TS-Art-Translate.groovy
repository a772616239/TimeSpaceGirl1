/**@META
{
  "description": "中文美术字 → 英文版流水线，四族资源共用一条链。① 战令横幅（ArtFont_zh/OperatingPanelAtlas/*_bg_zh.png，884x544）：标题+两行文案烘进图里，走写死的三段版面锚点；② 图集大图（Atlas/<面板>/*.png）：中文标题烘在一块纯色黑板上，走白字核+纯色板自动定位；③ 美术字块（ArtFont_zh/** 小型单色图，如 180x96 的页签）：只有纯白字 + alpha，本地排字会换掉笔画风格 ⇒ 必须交给模型重绘；④ 活动海报（**/banner/*_zh.png，884x856 不透明）：插画+斜切彩带+两行美术字，没有纯色底板可补也没锚点可写死 ⇒ 整幅交给模型重绘，再等比 cover 回原尺寸。出图方式由 PROVIDER 决定：chatgpt_web（默认，Chrome 登录态 / AdsPower 换号链驱动 chatgpt.com 出图）/ local（纯 OpenCV+PIL，可复现）/ manual（人交图）。无论谁画的，归位（尺寸/alpha/字块 bbox）、验收（尺寸/透明边/墨迹量/纯白/落位）、写回 ArtFont_en + .meta 都是同一套本地硬断言（写回一律平铺在族目录根，且校验目标目录在 resPathList 白名单里，否则当场 rc=1 —— 未登记的目录重扫会整目录跳过，是「图就位但真机白图」的唯一成因）。缺哪张补哪张，已存在的不动。译文对不对需要人眼看：glyph 与整幅图重绘都会把验收标黄（硬项全过但无 OCR 闸门）。",
  "concurrent": true,
  "params": [
    {"name":"MODE","type":"choice","choices":["batch","one"],"default":"batch","description":"batch=扫描全量（ArtFont_zh 横幅全目录 + 译名表里的 Atlas/glyph/poster 白名单），只补缺英文版且译名表里有条目的；one=只做 ASSET 指定的那一张"},
    {"name":"ASSET","type":"string","default":"","description":"MODE=one 时必填：源图相对工程根的路径。横幅如 Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas/cn2-X1_zhanling_mota_bg_zh.png；图集如 Assets/ManagedResources/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png；字块如 Assets/ManagedResources/ArtFont_zh/DynamicActivityPanelAtlas/tab/cn2-X1_zhutihuodong_yuanliaoshouji_01_zh.png；海报如 Assets/ManagedResources/ArtFont_zh/DynamicActivityPanelAtlas/banner/cn2-X1_ciyuanyinqing_banner_zh.png"},
    {"name":"PROVIDER","type":"choice","choices":["chatgpt_web","local","manual"],"default":"chatgpt_web","description":"出图方式。chatgpt_web=参考绘图管线：打开 Chrome/AdsPower 用 GPT 重绘（消耗包月额度，额度用尽自动换号）；local=原来的纯本地像素工序（只能做横幅/图集大图，字块/海报会被跳过）；manual=人把图放进 GEN_IMAGE（留空则输出提示词等人出图）"},
    {"name":"GEN_IMAGE","type":"string","default":"","description":"PROVIDER=manual 时显式指定出图（相对工程根或绝对路径）；留空则只生成参考图与提示词，不写回"},
    {"name":"CDP_PORT","type":"string","default":"","description":"复用已在运行的已登录浏览器（AdsPower/SunBrowser）的调试端口，find_browser_cdp.py 反查。留空=用本机 Chrome 的登录态副本"},
    {"name":"ADSPOWER_PROFILES","type":"string","default":"","description":"换号顺序（逗号分隔的 AdsPower user_id，排最前）。留空=按额度台账自动排。🔴 号池有 6 个但换号链默认只试 3 个，要覆盖就得显式写这里"},
    {"name":"PROVIDER_TIMEOUT","type":"string","default":"240","description":"单次等图上限（秒）。默认 240 而不是 driver 自带的 360：实测第一次常撞 5 分钟超时、重试 60s 就成，把第一轮压短能让最坏耗时从 10 分钟降到 7 分钟"},
    {"name":"SECOND_PROVIDER","type":"choice","choices":["gemini","none"],"default":"gemini","description":"仅 chatgpt_web：GPT 额度用尽后**不换号**，在同一台浏览器上换哪条通道接着画（默认 gemini）。两条通道都画不了才进换号链；none=老行为（GPT 空即换号，白扔这个号的 Gemini 额度）"},
    {"name":"GEM_TIMEOUT","type":"string","default":"300","description":"gemini 那条单张等图上限（秒）。超时即判这条通道不可用、继续换号"},
    {"name":"GEN_PACE","type":"boolean","default":true,"description":"出图节奏闸门（scripts/image/gen_pace.py）。开着=按账号限速（最小间隔/小时上限/日上限）。本 job 并发，闸门按账号记，所以并行构建会自己排队，不会叠加成高速率"},
    {"name":"GEN_MIN_GAP","type":"string","default":"180","description":"同一个 Gemini/Google 账号两张图之间至少隔多少秒（带 ±30% 抖动）。默认 180；被封前实测是 46 秒"},
    {"name":"GEN_MAX_PER_HOUR","type":"string","default":"10","description":"单个账号每小时最多出几张（默认 10；被封前实测 32）"},
    {"name":"GEN_MAX_PER_DAY","type":"string","default":"50","description":"单个账号每天最多出几张（默认 50）。撞上了把这个号标成「明天再来」，换号链接手"},
    {"name":"GEN_MAX_WAIT","type":"string","default":"1800","description":"一次出图最多等多久的节奏窗口（秒，默认 1800）。超了把这一步标黄收工，别硬等到撞 job 超时"},
    {"name":"HEARTBEAT_MIN","type":"string","default":"40","description":"会话保活心跳间隔（分钟，默认 40，±15%）：出图期间用同一台浏览器发一条纯文本请求，防长时间只建图被判成自动化，也早发现登录态掉了。0=关"},
    {"name":"BUDGET","type":"string","default":"","description":"本轮最多真出几张图（留空=不限）。batch 补图时给个上限，别一口气把包月额度烧完——额度用尽要等次日恢复"},
    {"name":"FORCE","type":"boolean","default":false,"description":"已有英文版的也重做（会先把旧图备份到 ResBackpack/备份 再覆盖）。改了口径/译名时才勾"},
    {"name":"WRITE","type":"boolean","default":true,"description":"验收通过后写回 Assets/ManagedResources/ArtFont_en/... 并补 .meta。传 false 则只出图、不动工程里的资源（构建页的 compare.png 照样能看）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    // 🔴 2026-10-22 起**允许并发**（用户要求「能同时画几张」）。
    //    以前这里是 disableConcurrentBuilds()，理由是「只有一份登录态」——那个前提已经不成立：
    //    号池里有 4~5 个 AdsPower profile，每个号是独立的浏览器实例 + 独立额度。
    //    并发的正确性不再靠「串行」保证，而是靠占用租约（provider_ledger.lease_claim）：
    //      · 每个构建开画前抢「某台浏览器」的独占权，抢不到就换下一个号，绝不挤同一台；
    //      · 同一张资源（asset）也只允许一个构建在画（复用 work 目录会互相覆盖证据）；
    //      · 额度用尽立刻关掉那台浏览器 + 记台账（什么时候恢复）+ 放租约，接着画下一张。
    //    ⚠ 仍然不要「同一张图点两次」：第二次会被 asset 租约挡成 skip（这是预期行为）。
    //    ⚠ 并行路数上限 = 台账里没封锁的号数（当前 4~5 路），别再手工开更多。
    //    2026-10-30 起还叠了「出图节奏闸门」：同号两张图至少 180s、每小时 ≤10 张、
    //    每天 ≤50 张 ⇒ batch 补图会比以前慢 3~4 倍，超时从 75 抬到 150 分钟。
    timeout(time: 150, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
    // 占用租约的身份 = 构建号。同一条构建里每张图都是独立进程，用 pid 认不出「自己人」，
    // 第 2 张图就会去抢第 1 张图正开着的那台浏览器（并行时等于自己跟自己抢）。
    TSG_LEASE_OWNER = "art-translate-${BUILD_NUMBER}"
  }

  stages {

    stage('① 环境与清单体检') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TR_ONLY = ''
          env.TR_ASSET_NAME = ''
          if (params.MODE == 'one') {
            def asset = (params.ASSET ?: '').trim()
            if (!asset) {
              error('MODE=one 时必须填 ASSET')
            }
            // 路径写错 / 指到别的目录时，②③④ 会因为「目标 0 张」全绿 —— 假绿球。
            // 所以先在这里把源图存在性钉死，再谈翻译。
            if (!fileExists("${env.PROJ}/${asset}")) {
              error("ASSET 不存在：${asset}\n（要相对工程根的完整路径，如 Assets/ManagedResources/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png）")
            }
            // 两种命名都要认：战令横幅带 _zh.png，Atlas 图集里的图没有后缀。
            def base = asset.replaceAll('^.*/', '').replaceAll('\\.png$', '')
            if (base.endsWith('_zh')) {
              base = base.substring(0, base.length() - 3)
            }
            env.TR_ONLY = base
            env.TR_ASSET_NAME = base
          }
          // 🔴 构建描述里必须带资源名（2026-10-22）：原来只有「one · 7/8 环节通过」，
          //   并行会话同时触发时，队列里几个构建长得一模一样，只能去 grep 控制台那行「模式：」
          //   才知道哪个是自己的（这次为此确认错过两轮）。
          currentBuild.description = (env.TR_ASSET_NAME
            ? "one · ${env.TR_ASSET_NAME}".toString() : "batch".toString())
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "模式：$MODE   ${TR_ONLY:+只做 $TR_ONLY   }强制重做：$FORCE   写回资源：$WRITE"
  echo "出图：${PROVIDER}${CDP_PORT:+  CDP=${CDP_PORT}}${ADSPOWER_PROFILES:+  号序=${ADSPOWER_PROFILES}}"
  echo "占用身份：${TSG_LEASE_OWNER}（并行时每个构建只抢自己那台浏览器，抢不到就换下一个号）"
  echo ""
  echo "🔴 中文是烘进图里的艺术字（带发光/渐变/立体阴影），不是 TMP 文本 —— 只能重出一张图。"
  echo "🔴 四族共用一条链，靠源图自身特征自动分派（尺寸带互不重叠）："
  echo "     ArtFont_zh/** 884x544 横幅 → artfont 族（三段文字，版面锚点写死）"
  echo "     Atlas/**                   → atlas 族（中文压在一块纯色黑板上，白字核+纯色板自动定位）"
  echo "     ArtFont_zh/** 小型单色图   → glyph 族（纯白字+alpha 的页签/竖排标题，只能模型重绘）"
  echo "     **/banner/*.png 884x856    → poster 族（插画+彩带+两行字，整幅重绘后 cover 回原尺寸）"
  echo "🔴 出图那一步不可复现、要花额度 ⇒ 单独摘出去：provider 只负责「把图给我」，"
  echo "     尺寸 / alpha / 字块落位 / 验收 / 写回全部是本地硬断言（与 TS-Art-Restyle 同一套切法）。"
  echo "🔴 喂给模型的参考图是「合成到深底的版本」：原始 PNG 是白字+透明底，"
  echo "     浏览器按白底预览 ⇒ 模型看到一张白纸，画出来必然是白底白字。"
  echo "🔴 模型出的图要**归位**：等比缩进源图字块 bbox（不是拉伸、不是整幅 cover），再抠墨迹 → 纯白 + alpha。"
  echo "🔴 擦字一律按像素判据圈区域，不按矩形硬切 —— 硬切会把暗板/图集装饰切出直边。"
  echo "🔴 artfont 族第三行「累计返利 __ 倍」不排：已上线的 pata_bg_en / shenyuan_bg_en 都把它删了，留给 UI 动态数字。"
  echo "🔴 写回路径：**平铺在族目录根**（ArtFont_en/<族目录>/<名>_en.png），zh 侧的 tab/ banner/ 子目录一律压平。"
  echo "     既有 60+ 张 en 图全是这个布局；而 ArtFont_en/DynamicActivityPanelAtlas/tab 这种子目录"
  echo "     根本不在 ResourcePathConfig.resPathList（868 条手工白名单，一个目录=一个 AB）里 ⇒"
  echo "     重扫整目录跳过 ⇒ resName 不登记 ⇒ 图就位了也白图。publish 现在会当场拦下这种路径。"
  echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）。"
  echo "     publish 会顺手查 resName 是否已在 resInfoList，没登记就打 ⏳ 提示该重打哪个目录。"
  echo "🔴 字块写回只是「英文图就位」；客户端真显示英文还要求调用点走 GetPictureFont(...)"
  echo "     ＋ 该 resName 在 ResourcePathConfig.asset 有登记 —— 缺一步都是白图。"
  echo "🟢 译文对不对已有自动闸门（2026-10-22 起）：artfont / poster 族出图会把成品 flatten 到黑底、反相后"
  echo "     过 tesseract --psm 6，与译名表的 lines 做滑窗相似度（归一化只留 A-Z0-9，手写体大小写不分）。"
  echo "     相似度 ≥0.55 过、0.35~0.55 标黄、<0.35 判红。实测合格品 0.78~1.00，模型自造译名 0.29"
  echo "     （#27 把 Ave Verum Corpus 写成 DIVINE JUDGMENT）。glyph 族仍是人眼确认（字块太小未标定）。"
  echo "🔴 字的完整性也是自动闸门：refit 在 putalpha 之前量「墨迹落在 alpha=0 区」的像素，"
  echo "     压回安全框后仍有 >0.4% 越界才判红 —— 这条挡的是 #14/#19/#30 的「末字母被切」。"
  echo "     注意它只对出图族生效；glyph 族由 postprocess_glyph 按墨迹 bbox 归位，不走 refit。"
} | tee "$TS_RUN_DIR/context.txt"
''')
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 这里是「开工前的盘点」，永远算通过（--strict-ok）：
# 有活要干不是缺陷，本轮的最终颜色交给 ⑤ 的「收尾清单」定。
"$BASH" .jenkins/lib/run_stage.sh --name "开工盘点" \
  --group "美术翻译链" --slug tr-scan --timeout 120 \
  -- "$PY" scripts/image/banner_translate.py scan --strict-ok

# 出图额度预检（2026-10-22 新增）：台账里所有号都在封锁中就直接红。
# 不预检的代价是 driver 挨个号试一遍才肯退 —— 实测白等 5~9 分钟，而这件事上一轮就记在台账里了。
# 2026-10-22 起还会报「可并行几路」：并行构建时若所有通道都被别的构建占着，quota 返回 3（黄），
# 说明「不是没额度，是现在排不上」，本轮会快速跳过而不是排队干等。
if [[ "${PROVIDER:-chatgpt_web}" == "chatgpt_web" && -z "${GEN_IMAGE:-}" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "出图额度" \
    --group "美术翻译链" --slug tr-quota --timeout 120 --warn-rc 3 \
    -- "$PY" scripts/image/banner_translate.py quota || {
      echo "🔴 出图额度全封锁 ⇒ 本轮不出图（等台账里最早那个恢复时间再来）"
      exit 1
    }
fi
''')
      }
    }

    stage('② 生成英文图（出图 + 归位）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

# ── 出图节奏闸门 + 会话保活心跳（2026-10-30 账号被封之后加的；口径与 TS-Art-Restyle 一致）──
# 🔴 本 job 允许并发，闸门是按**账号**记的，所以并行的几条构建会自己排队，
#    「多开两条构建就能多画」这条捷径自动失效 —— 要提速只能加号。
export TSG_GEN_MAX_WAIT="${GEN_MAX_WAIT:-1800}"
if [[ "${GEN_PACE:-true}" == "false" ]]; then
  export TSG_GEN_PACE=off
  echo "⚠⚠ 出图节奏：已关闸（GEN_PACE=false）—— 会回到小时级 30+ 张的节奏，只用于人工验证"
else
  export TSG_GEMINI_MIN_GAP="${GEN_MIN_GAP:-180}"
  export TSG_GEMINI_MAX_PER_HOUR="${GEN_MAX_PER_HOUR:-10}"
  export TSG_GEMINI_MAX_PER_DAY="${GEN_MAX_PER_DAY:-50}"
  if [[ "${HEARTBEAT_MIN:-40}" == "0" ]]; then
    export TSG_HB_OFF=1
    echo "会话保活：关闭（HEARTBEAT_MIN=0）"
  else
    export TSG_HB_MINUTES="${HEARTBEAT_MIN:-40}"
    echo "会话保活：每 ${TSG_HB_MINUTES} 分钟（±15%）发一条纯文本请求 —— 防止长时间只建图被判成自动化"
  fi
  echo "出图节奏：同号两张图至少隔 ${TSG_GEMINI_MIN_GAP}s（±30% 抖动）｜≤${TSG_GEMINI_MAX_PER_HOUR} 张/小时｜≤${TSG_GEMINI_MAX_PER_DAY} 张/天"
fi
"$PY" scripts/image/gen_pace.py status 2>/dev/null | sed 's/^/  /' || true

# MODE=one 必须 --asset 直指源图：候选池按特征分派（glyph 单色 / poster ≥800x700 /
# artfont=OperatingPanelAtlas glob / atlas=译名表），译名表里有条目但落不进任何池的图
# （如 ArtFont_zh/font 下的 512x256 特写横幅，既不是单色 glyph 也不够 poster 尺寸）
# 用 --only 会在②③④「目标 0 张」全绿 —— 假绿球（#6 实测）。
ASSET_ARG=""
[[ "${MODE:-batch}" == "one" && -n "${ASSET:-}" ]] && ASSET_ARG="--asset ${ASSET}"
ONLY=""
[[ -z "$ASSET_ARG" && -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# 出图方式：chatgpt_web 要开浏览器等模型，单张 3~8 分钟 ⇒ 给到 2400s（与 TS-Art-Restyle 一致）
PROV_ARGS="--provider ${PROVIDER:-chatgpt_web}"
[[ -n "${GEN_IMAGE:-}" ]] && PROV_ARGS="${PROV_ARGS} --gen-image ${GEN_IMAGE}"
[[ -n "${CDP_PORT:-}" ]] && PROV_ARGS="${PROV_ARGS} --cdp-port ${CDP_PORT}"
[[ -n "${ADSPOWER_PROFILES:-}" ]] && PROV_ARGS="${PROV_ARGS} --adspower-profiles ${ADSPOWER_PROFILES}"
[[ -n "${PROVIDER_TIMEOUT:-}" ]] && PROV_ARGS="${PROV_ARGS} --provider-timeout ${PROVIDER_TIMEOUT}"
# 🔴 2026-10-26（用户要求）：GPT 额度用尽**不换号**，先在同一台浏览器上换 gemini 接着画，
#    两条都空了才换号。参考图/提示词沿用本张的（ref_flat 白底黑字 + 本张版面要求）。
if [[ "${PROVIDER:-chatgpt_web}" == "chatgpt_web" && "${SECOND_PROVIDER:-gemini}" != "none" ]]; then
  if [[ -f scripts/image/gen_gemini.py && -f scripts/image/gemini_web_driver.mjs ]]; then
    PROV_ARGS="${PROV_ARGS} --second-provider ${SECOND_PROVIDER:-gemini} --second-timeout ${GEM_TIMEOUT:-300}"
    echo "第二通道：${SECOND_PROVIDER:-gemini}（GPT 空了 → 同一台浏览器接着画，都空了才换号）"
  else
    echo "⚠ SECOND_PROVIDER=${SECOND_PROVIDER:-gemini}，但 gen_gemini.py / gemini_web_driver.mjs 不在 ⇒ 本轮只有 GPT"
  fi
elif [[ "${PROVIDER:-chatgpt_web}" == "chatgpt_web" ]]; then
  echo "第二通道：关闭（SECOND_PROVIDER=none ⇒ GPT 额度空了直接换号）"
fi
BUDGET_ARG=""
[[ -n "${BUDGET:-}" ]] && BUDGET_ARG="--budget ${BUDGET}"
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "生成英文图" \
  --group "美术翻译链" --slug tr-run --timeout 2400 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py batch --stage run \
       --run "$TS_RUN_DIR" $ASSET_ARG $ONLY $FORCE_ARG $PROV_ARGS $BUDGET_ARG
''')
      }
    }

    stage('③ 像素级验收') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ASSET_ARG=""
[[ "${MODE:-batch}" == "one" && -n "${ASSET:-}" ]] && ASSET_ARG="--asset ${ASSET}"
ONLY=""
[[ -z "$ASSET_ARG" && -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# 断言口径按「provider 出的图 × family 的画法」两维选：
#   local + artfont = 尺寸/alpha/重建区外零改动/粉色标题零残留/黄色文案零残留/英文白字已落版
#   local + atlas   = 尺寸/alpha/重建区外零改动/板内墨迹零残留/板底平整/英文白字已落版/板外条带无残字
#   chatgpt_web + glyph = 尺寸/四角仍透明/墨迹量/纯白 RGB255/主体不是小标记（字形 IoU 只记录）
#   chatgpt_web + poster = 尺寸/alpha/确实重画过/没有整幅重画/色差可控/上 45% 彩带区动过
#   chatgpt_web + 整幅图 = 尺寸/alpha/确实重画过/没有整幅重画/色差可控
#                        + 笔画全部落在可见区内（lock 前逐像素量）+ 译文与译名表一致（OCR）
# 🔴 2026-10-22 补了两条硬闸门（原来只有「英文是否正确需人眼确认」一句话，等于把两次
#    最贵的失败——字被 alpha 切掉、模型自造译名——全推给人眼；#14/#19/#27 就是这么白烧的）：
#    · 笔画越界：lock 之前量 `ink & (alpha<=8)`，越界就先横向压窄字带，压不下去判红；
#    · 译文一致性：tesseract --psm 6 读图，与译名表滑窗比对（合格品实测 0.78~1.00，
#      #27 的 DIVINE JUDGMENT 只有 0.29）。
#    剩下只有「观感/风格」需要人眼看 compare.png。
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "像素级验收" \
  --group "美术翻译链" --slug tr-verify --timeout 300 \
  -- "$PY" scripts/image/banner_translate.py batch --stage verify \
       --run "$TS_RUN_DIR" $ASSET_ARG $ONLY $FORCE_ARG
''')
      }
    }

    stage('④ 写回资源（ArtFont_en + .meta）') {
      // 布尔参数经 buildWithParameters 进来可能是字符串 "false"，
      // Groovy 里非空字符串为真 ⇒ 统一按字符串比 'true'（TS-Art-Restyle 踩过这个坑）
      when { expression { (params.WRITE ?: 'true').toString().toLowerCase() == 'true' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ASSET_ARG=""
[[ "${MODE:-batch}" == "one" && -n "${ASSET:-}" ]] && ASSET_ARG="--asset ${ASSET}"
ONLY=""
[[ -z "$ASSET_ARG" && -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "写回英文版资源" \
  --group "交付" --slug tr-publish --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py batch --stage publish \
       --run "$TS_RUN_DIR" $ASSET_ARG $ONLY $FORCE_ARG
''')
      }
    }

    stage('⑤ 收尾复核与证据归档') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 收尾再盘一次：还有没翻的横幅就标黄（这才是「本轮有没有干完」的结论），
# 全齐了就绿。WRITE=false 时图只落在 _output，这里自然会黄。
"$BASH" .jenkins/lib/run_stage.sh --name "收尾清单" \
  --group "交付" --slug tr-left --timeout 120 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py scan --quiet

# 中英对照图要跟着构建走：构建页直接能看「这张翻成什么样」，不用去翻 _output
shopt -s nullglob
for d in "$PROJ"/_output/art_translate/*/; do
  name="$(basename "$d")"
  for f in compare.png out.png state.json; do
    [[ -f "$d$f" ]] && cp -f "$d$f" "$TS_RUN_DIR/artifacts/${name}__${f}" 2>/dev/null || true
  done
done
shopt -u nullglob
{
    echo "本次产物："
    ls -1 "$TS_RUN_DIR/artifacts" 2>/dev/null | sed 's/^/  - /'
  } | tee "$TS_RUN_DIR/artifacts/manifest.txt"

# 通道占用收尾（2026-10-22）：本轮用过的浏览器租约必须放掉，否则并行的另一轮会一直
# 以为这个号「有人在用」而拿不到（浏览器本身刻意留着，下一轮直接接入省一次启动）。
"$PY" scripts/image/provider_ledger.py lease-release --owner "${TSG_LEASE_OWNER:-}" | sed 's/^/  /' || true
{
  echo "通道占用（还开着的浏览器 / 谁在用）："
  "$PY" scripts/image/provider_ledger.py lease-list 2>&1 | sed 's/^/  /' || true
  echo "最近 8 条浏览器事件（开关 / 额度用尽）："
  "$PY" scripts/image/provider_ledger.py events --tail 8 2>&1 | sed 's/^/  /' || true
} | tee "$TS_RUN_DIR/browser_leases.txt"

"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "证据归档" --group "交付" --status pass \
  --detail "artifacts 已就绪（$(ls -1 "$TS_RUN_DIR/artifacts" 2>/dev/null | wc -l | tr -d ' ') 个文件）"
''')
      }
    }
  }

  post {
    always {
      script {
        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
mkdir -p "$TS_RUN_DIR/logs"
"$PY" .jenkins/lib/stage_report.py junit --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" .jenkins/lib/stage_report.py summary --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/summary.md" --title "$JOB_NAME #$BUILD_NUMBER" || true
# workspace 不做 cleanWs，而 cp -R 只增不删 ⇒ 上几次的证据会被一起归档，
# 看起来像「同一个环节跑了两遍」，所以每次都重建 evidence/
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
# 🔴 无论哪一步失败都要放租约：构建中途红掉时 ⑤ 收尾不会执行，
#    不放的话这个号会被「占用」到 TTL 过期（20 分钟），并行的另一轮白等。
#    只放自己的（--owner 是构建号），绝不动别的构建/别的会话。
"$PY" scripts/image/provider_ledger.py lease-release --owner "${TSG_LEASE_OWNER:-}" >/dev/null 2>&1 || true
''')

        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'evidence/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
''').trim()
        if (desc) {
          // 资源名放前面：队列/历史里一眼认领（原来只有「one · 7/8 环节通过」）
          def who = (env.TR_ASSET_NAME ?: params.MODE).toString()
          currentBuild.description = "${who} · ${desc}".toString()
        }

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py status --run "$TS_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        archiveArtifacts allowEmptyArchive: true, artifacts: 'evidence/**', fingerprint: false
      }
    }
  }
}
