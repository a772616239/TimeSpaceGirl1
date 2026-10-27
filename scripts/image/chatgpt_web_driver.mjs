// chatgpt_web_driver.mjs —— 驱动一个**已经登录**的 Chrome（CDP 连上去）在 chatgpt.com 出图。
//
// 由 gen_chatgpt_web.py 调用，不单独使用：
//   node chatgpt_web_driver.mjs --cdp http://127.0.0.1:9333 --image a.png \
//        --prompt-file p.txt --out gen.png --timeout 300 --pw /path/to/playwright-core
//
// 为什么用 CDP 而不是自己起浏览器：登录态在用户真实的 Chrome profile 里，
// 自己起 Chromium 会换掉 TLS 指纹，Cloudflare 的 cf_clearance 立刻作废。
//
// 🔴 2026-10-20 实测踩到的两个坑（照着改之前先看）：
//   1) 生成的图不是 <img src="https://...">，而是 **blob: URL**，挂在
//      [data-testid="generated-image-gallery"] 里的 BUTTON 下，alt 是「已生成图像 N」。
//      按 src 域名过滤（oaiusercontent/estuary）会一张都匹配不到。
//   2) 上传的参考图也是 blob，alt 是「用户附件」。只按 blob 过滤会拿到参考图本身。
//      ⇒ 判别必须靠 alt，不能靠 src。
//
// 退出码：0 拿到图 / 3 需要登录或被人机验证挡住 / 4 出图额度用尽 / 5 模型安全策略拒绝 / 1 其他失败
//
// 🔴 2026-10-21：额度用尽原来是「哑失败」——站点明明在页面上写了
//    「图像生成额度已用完 / 你目前的图片生成次数已用完…12:06 获得更多次数」，
//    driver 却只在 6 分半超时之后从页面尾部嗅到一句「可能是额度用尽」，还归到 rc=3，
//    Jenkins 上看起来跟网络抖动一模一样。现在每轮轮询都扫这段文案，命中立刻退出 rc=4，
//    并把站点原文 + 重置时间落进 <out>.fail.json（证据进 artifacts，不靠人翻控制台）。
import fs from 'node:fs';
import process from 'node:process';

const argv = process.argv.slice(2);
const arg = (k, d = null) => {
  const i = argv.indexOf(`--${k}`);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : d;
};

const cdp = arg('cdp', 'http://127.0.0.1:9333');
const imagePath = arg('image');
const promptFile = arg('prompt-file');
const outPath = arg('out');
const timeoutMs = Number(arg('timeout', '300')) * 1000;
const pwPath = arg('pw');
const chatUrl = arg('url', 'https://chatgpt.com/');

if (!imagePath || !promptFile || !outPath || !pwPath) {
  console.error('[driver] 参数不全');
  process.exit(1);
}

// 🔴 playwright-core 是 CJS：动态 import 拿到的是 namespace，chromium 挂在 .default 上，
//    直接解构会得到 undefined（报 "Cannot read properties of undefined (reading 'connectOverCDP')"）
const pw = await import(`${pwPath}/index.js`);
const chromium = (pw.default ?? pw).chromium;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.error('[driver]', ...a);

const prompt = fs
  .readFileSync(promptFile, 'utf8')
  .split('\n')
  .filter((l) => !l.startsWith('# theme='))
  .join('\n')
  .trim();

// 生成图的 alt 文案：**界面语言跟随账号**，所以必须多语言都认。
// 🔴 2026-10-20 踩过：只写了「已生成图像」，而 SunBrowser 里那个号是日文界面，
//    图早就画好了，driver 一直认不出 → 白等到超时 + 又重发一次，白烧一次额度。
const GEN_ALT = [
  '已生成图像', '生成图像', 'Generated image', '生成された画像', '生成画像',
  '생성된 이미지', 'Imagen generada', 'Image générée', 'Generiertes Bild', 'Imagem gerada',
];
// 用户自己传上去的参考图，alt 是「用户附件 / Attached / 添付」—— 必须排除
const UPLOAD_ALT = ['用户附件', 'Attached', 'attachment', '添付', '첨부', 'Adjunto'];

// 站点「额度用尽」的原文。🔴 必须逐条列、且不能只用宽泛的 /limit/（提示词本身也带 "limit"）。
// 🔴 也不能只写中文：同一个 bug 犯了两次 —— 本机 Chrome 是中文界面（第一次），
//    SunBrowser 那个号是**日文**界面，原文是「現在、無料の画像生成枠を使い切っています。
//    …⁨19:12⁩に無料枠が回復するまでお待ちください。」，中文判据一条都不命中 ⇒ 又白等 6 分钟。
//    这段用字符串存，snapshot（在页面上下文里跑）和超时兜底（在 node 里跑）共用同一份。
const QUOTA_SRC = [
  // 中文
  '图像生成额度已用完', '图片生成次数已用完', '生成次数已用完', '额度已用完',
  '已达到[^。\\n]{0,24}(Free|免费)[^。\\n]{0,24}(上限|限额)',
  '上限将在[^。\\n]{0,12}(重置|恢复)', '无法调用图像生成工具',
  // 英文
  'image generation (limit|quota)', 'reached your (free )?(plan\'?s )?limit',
  'limit will reset', 'out of (free )?image generations',
  'used up your (free )?image', 'upgrade to plus to (continue|keep|create)',
  // 日文
  '画像生成(の)?上限', '画像生成枠を使い切', '無料枠が回復するまで',
  '上限に達しました', 'アップグレードすると',
  // 韩文
  '이미지 생성 (한도|횟수)', '무료 (이미지 )?(생성 )?한도',
];

// 安全策略拒绝的原文。🔴 2026-10-21 实测（日文界面）：
//   「大変申し訳ございません。生成された画像が、詐欺・詐取行為が疑われるコンテンツに関する
//     安全基準に違反している可能性があります。誤判定と思われる場合は、再度お試しいただくか、
//     プロンプトを修正してください。」
//   当时没有这条判据 ⇒ 被当成「环境抖动」重试一次，白等 7 分钟（第二次还撞上 CDP 超时）。
//   被拒 ≠ 网络问题：同一个提示词再发基本还是拒，要么改 LAYOUT，要么换参考图。
const REFUSAL_SRC = [
  // 日文
  '安全基準に違反', '詐欺・詐取行為', '誤判定と思われる場合は', 'コンテンツポリシー',
  // 中文
  '安全(标准|政策|准则)', '内容(政策|准则)', '违反.{0,12}(政策|准则|标准)', '无法(生成|创建)这张',
  // 英文
  'content policy', 'violates our (policies|usage policies)',
  "can'?t (create|generate|help with) (that|this) image", 'not able to (create|generate) that',
  'may violate', 'safety (standards|guidelines)',
  // 韩文
  '정책을 위반', '안전 기준',
];

const snapshot = ({ alts, quota, refusal }) => {
  const uploads = ['用户附件', 'Attached', 'attachment', '添付', '첨부', 'Adjunto'];
  const isGen = (im) =>
    alts.some((a) => (im.alt || '').includes(a)) ||
    // 兜底：结构上就在「生成图」容器里（alt 文案没覆盖到的语言走这条）
    (!!im.closest('[data-testid*="generated-image"]') &&
      !uploads.some((a) => (im.alt || '').includes(a)));
  // 🔴 侧栏历史会话标题会复述「画像生成上限通知」这类字眼（上一轮真额度提示被站点自动命名），
  //    全文扫描会把**标题**当成**当前回复** ⇒ 之后每次进来都秒判「额度用尽」，号明明能画也画不了。
  //    2026-10-25 实测：构建 #13 一进来就命中「画像生成上限通知 / 画像生成依頼」，44 秒即停、连换号链都没走。
  //    按行剔除 nav 里的文本（不能整段删：innerText 顺序不同，整段匹配删不掉）。
  const navLine = new Set();
  document.querySelectorAll('nav').forEach((n) => {
    (n.innerText || '').split('\n').forEach((s) => {
      const t = s.trim();
      if (t) navLine.add(t);
    });
  });
  const body = (document.body.innerText || '')
    .split('\n')
    .filter((l) => !navLine.has(l.trim()))
    .join('\n');
  const QUOTA = quota.map((s) => new RegExp(s, 'i'));
  const REFUSAL = refusal.map((s) => new RegExp(s, 'i'));
  const lines = body.split('\n').map((s) => s.trim()).filter(Boolean);
  const qi = lines.findIndex((l) => QUOTA.some((re) => re.test(l)));
  let hit = { hit: false };
  if (qi >= 0) {
    // 命中行 + 下一行（站点把「用完了」和「什么时候重置」拆成两段）
    const msg = [lines[qi], lines[qi + 1] || ''].filter(Boolean).join(' / ');
    const resetM =
      msg.match(/(\d{1,2}:\d{2})/) ||
      body.match(/在\s*(\d{1,2}:\d{2})\s*获得/) ||
      body.match(/(\d{1,2}:\d{2})\s*に(無料枠|フリー)/);
    // 短周期重置（「12 分後」「12 分钟后」「in 12 minutes」）必须单独认：
    // 站点在「刚用完不久」时只给分钟数，认不出来就落到 +6h 兜底，白等半天。
    const minsM =
      body.match(/(\d+)\s*分\s*(?:後|后)/) ||
      body.match(/in\s*(\d+)\s*min/i) ||
      body.match(/(\d+)\s*minutes?\b/i);
    const hoursM = body.match(/(\d+)\s*小时\s*(后)?\s*重置/) || body.match(/(\d+)\s*時間後/);
    hit = {
      hit: true,
      message: msg.slice(0, 300),
      reset: [
        resetM && `约 ${resetM[1]}`,
        minsM && `${minsM[1]} 分钟后`,
        hoursM && `${hoursM[1]} 小时后`,
      ]
        .filter(Boolean)
        .join(' / '),
    };
  }
  // 安全策略拒绝：模型明确说「这张不画」。与额度/网络是两回事 —— 重试同一句话基本还是拒，
  // 要么改提示词（去掉可能触发的描述），要么换参考图。
  const ri = lines.findIndex((l) => REFUSAL.some((re) => re.test(l)));
  let refused = { hit: false };
  if (ri >= 0) {
    refused = {
      hit: true,
      message: [lines[ri], lines[ri + 1] || ''].filter(Boolean).join(' / ').slice(0, 300),
    };
  }
  return {
    // 只认生成图：靠 alt 区分「已生成图像 N」与「用户附件」
    imgs: Array.from(document.querySelectorAll('img'))
      .filter(isGen)
      .map((im) => ({
        src: im.currentSrc || im.src,
        w: im.naturalWidth,
        h: im.naturalHeight,
        alt: im.alt,
      }))
      .filter((o) => o.w >= 300 && o.h >= 300),
    // 生成中判据。🔴 2026-10-21 实测：body 里**包含用户自己的提示词**，所以任何「数字+%」
    //   都可能是提示词里的约束（例如 "keep everything inside a 4% safe margin"）——
    //   一命中就 busy=true ⇒ 图其实早就画完了（页面尾部明确写着「回答已完成」）却永远等不到
    //   连续两轮 stable，最后白等 7 分钟超时、白烧一次额度（design 档首跑就是这么废的）。
    //   所以：① 完成标记优先，② 百分比只认进度组件，绝不扫全文。
    busy: (() => {
      // 🔴 2026-10-27 实测：SunBrowser 以 `-AppleLanguages (zh-TW)` 启动，界面是**繁体**，
      //    完成标记写的是「回覆已完成」而不是简体「回答已完成」。以前只认简体 ⇒ busy 永远为 true
      //    ⇒ 图明明画完了也要等到 timeout 才报「未拿到图」，白烧一次额度（dan_2_0 就这么废的）。
      //    所以这里必须把简/繁/日/韩/英的完成文案**全部**列上。
      const DONE =
        /回答已完成|已完成回答|回覆已完成|已完成回覆|已回覆|生成已完成|已完成生成|圖像已生成|图片已生成|回答が完了しました|生成が完了しました|画像を生成しました|생성 완료|응답 완료|Response (now )?complete|Answer (now )?complete|Image (now )?ready/i;
      if (DONE.test(body) && !document.querySelector('[data-testid="stop-button"]')) return false;
      return (
        !!document.querySelector('[data-testid="stop-button"]') ||
        !!document.querySelector('[role="progressbar"], [data-testid*="progress"], [aria-valuenow]') ||
        /正在(勾勒|生成|绘制|繪製|创建|建立|生成圖片)|Creating image|Generating image|画像を(生成|作成)|그림을 그리는/i.test(
          body
        )
      );
    })(),
    quota: hit,
    refusal: refused,
    text: body.slice(-600),
  };
};

const sig = (imgs) => imgs.map((i) => `${i.w}x${i.h}`).sort().join(',');

// 🔴 2026-10-21 实测：复用 SunBrowser 时，标签页一多 Chromium 会把后台标签**冻结**
//    （Runtime.evaluate 3s 无响应）。playwright 的 connectOverCDP 要逐个 attach 全部页面，
//    碰到冻结页就整体超时 —— 报「browserType.connectOverCDP: Timeout 30000ms exceeded」，
//    而 /json/version 明明是通的，很容易误判成「浏览器挂了」。
//    解法：连之前先用**浏览器级 CDP** 把所有 page target 激活一遍（activateTarget 会解冻），
//    实测同一个端口从 30s 超时变成 369ms 连上。
const thawFrozenTabs = async (cdpUrl) => {
  const base = cdpUrl.replace(/\/+$/, '');
  try {
    const ver = await (await fetch(`${base}/json/version`)).json();
    const list = await (await fetch(`${base}/json/list`)).json();
    const pages = (Array.isArray(list) ? list : []).filter((t) => t.type === 'page');
    if (!pages.length || !ver.webSocketDebuggerUrl) return 0;
    const ws = new WebSocket(ver.webSocketDebuggerUrl);
    await new Promise((res, rej) => {
      ws.onopen = res;
      ws.onerror = rej;
      setTimeout(() => rej(new Error('ws open timeout')), 5000);
    });
    let id = 0;
    const send = (method, params) =>
      new Promise((res) => {
        const myId = ++id;
        const h = (m) => {
          const d = JSON.parse(m.data);
          if (d.id === myId) {
            ws.removeEventListener('message', h);
            res(true);
          }
        };
        ws.addEventListener('message', h);
        ws.send(JSON.stringify({ id: myId, method, params }));
        setTimeout(() => res(false), 3000);
      });
    let n = 0;
    for (const t of pages) if (await send('Target.activateTarget', { targetId: t.id })) n++;
    ws.close();
    return n;
  } catch (e) {
    log('解冻标签页失败（忽略，继续直连）：', e?.message ?? e);
    return 0;
  }
};

// 失败证据：<out>.fail.json。让上层（gen_chatgpt_web.py / Jenkins）不必去解析控制台文本，
// 也能把「为什么没图」当成结构化数据归档。
const failPath = `${outPath}.fail.json`;
const safeUrl = () => {
  try {
    return page?.url?.() ?? '';
  } catch {
    return '';
  }
};
const writeFail = (obj) => {
  try {
    fs.writeFileSync(failPath, JSON.stringify({ ...obj, url: safeUrl(), at: new Date().toISOString() }, null, 2));
    log('失败证据已落盘', failPath);
  } catch (e) {
    log('失败证据落盘失败', e?.message ?? e);
  }
};
// 🔴 上一轮的失败证据必须清掉：否则「这次其实成功了」也会被上层读成额度用尽。
try {
  fs.rmSync(failPath, { force: true });
} catch {
  /* ignore */
}

let browser;
let page = null; // 提到模块作用域：writeFail 要在异常路径上也能取到当前 url
try {
  // 连之前先解冻后台标签（见 thawFrozenTabs 的注释：不解冻就必然 30s 超时）
  const thawed = await thawFrozenTabs(cdp);
  if (thawed) log(`已激活 ${thawed} 个标签页（防止后台冻结把 CDP attach 卡死）`);
  browser = await chromium.connectOverCDP(cdp);
  const ctx = browser.contexts()[0];
  // 复用外部浏览器（如 AdsPower 的 SunBrowser）时，那个 profile 里可能开着七八个标签页。
  // 直接拿 pages()[0] 会把用户正在看的页面导航走，所以：已登录的 chatgpt 标签优先复用，
  // 没有就新开一个，绝不抢别人的 tab。
  const pages = ctx.pages();
  page =
    pages.find((p) => /chatgpt\.com/.test(p.url())) ??
    (pages.length && !process.env.PW_KEEP_BROWSER ? pages[0] : null) ??
    (await ctx.newPage());
  page.setDefaultTimeout(60000);

  // 🔴 2026-10-20 实测：ChatGPT 会弹一个 codex 推广对话框（`.codex-dialog-overlay`），
  //    遮罩吃掉 pointer events ⇒ 「发送」按钮 click 必然 60s 超时，整轮白跑。
  //    这里在「上传前 / 发送前 / 取图前」各清一次：先按 Esc，再点遮罩左上角（点遮罩即关）。
  const clearOverlays = async () => {
    const SEL = '.codex-dialog-overlay, [role="dialog"][data-state="open"]';
    for (let i = 0; i < 3; i++) {
      let has = false;
      try {
        has = await page.evaluate((sel) => !!document.querySelector(sel), SEL);
      } catch {
        return false; // 页面已经没了，交给上层按异常处理
      }
      if (!has) return true;
      log('发现遮挡对话框，尝试关闭');
      await page.keyboard.press('Escape').catch(() => {});
      await sleep(500);
      const ov = page.locator('.codex-dialog-overlay').first();
      if (await ov.count().catch(() => 0)) {
        // 点遮罩自身（不是对话框内部）即可关闭；坐标取 4,4 保证落在对话框之外
        await ov.click({ position: { x: 4, y: 4 }, force: true }).catch(() => {});
        await sleep(400);
      }
    }
    try {
      return !(await page.evaluate((sel) => !!document.querySelector(sel), SEL));
    } catch {
      return false;
    }
  };

  log('打开新对话');
  const grabExisting = argv.includes('--grab-existing');
  if (grabExisting) {
    // 图已经画好了，只是上次没认出来（或进程被杀）。再发一次就白烧一次额度。
    log('--grab-existing：不发送，直接取当前对话里已有的生成图', page.url());
  } else {
    await page.goto(chatUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await sleep(5000);
  }

  const url = page.url();
  if (/\/auth\/|\/log[-_]?in/.test(url)) {
    log(`未登录（${url}）—— 请先在常用 Chrome 里登录 chatgpt.com`);
    process.exit(3);
  }
  const head = await page.evaluate(() => (document.body.innerText || '').slice(0, 600));
  if (/Just a moment|Checking your browser|verify you are human|确认您是人类/i.test(head)) {
    log('被人机验证挡住（Cloudflare challenge），需要人工过一次');
    process.exit(3);
  }
  // 免费版/未登录的落地页会带「登录」按钮；已登录时侧栏有历史对话
  if (/^\s*Skip to content\s*\|/i.test(head) || /Get responses tailored to you/i.test(head)) {
    log('页面是未登录营销页 —— 登录态没生效');
    process.exit(3);
  }

  // 🔴 强制空对话：标签页常停在上一次跑完的 /c/<id> 上，ChatGPT 会把上一张参考图一起带进上下文，
  //    表现是「新图里凭空出现上一张的角色/道具」（2026-10-21 商店配图里多出一只球鞋 + 蹲姿）。
  //    宁可多花 5 秒确认，也不要烧一次额度画错一张图。
  if (!grabExisting) {
    const hasMsgs = async () => {
      try {
        return await page.evaluate(() => document.querySelectorAll('[data-message-author-role]').length > 0);
      } catch { return false; }
    };
    if (page.url().includes('/c/') || await hasMsgs()) {
      log(`⚠ 不是空对话（${page.url()}）—— 先切新对话，避免串上一张图`);
      await page.goto('https://chatgpt.com/?new=1', { waitUntil: 'domcontentloaded', timeout: 60000 });
      await sleep(4000);
      if (page.url().includes('/c/') || await hasMsgs()) {
        const btn = page.locator('[data-testid="create-new-chat-button"], a[href="/"], ' +
          'button[aria-label*="New chat"], button[aria-label*="新しいチャット"], button[aria-label*="新規チャット"]').first();
        try {
          if (await btn.count()) { await btn.click(); await sleep(3000); }
        } catch { /* 点不到就落到下面的硬失败 */ }
      }
      if (page.url().includes('/c/') || await hasMsgs()) {
        log('🔴 仍然不是空对话，拒绝发送（会串上一张图，等于白烧一次额度）');
        process.exit(3);
      }
      log('✅ 已切到空对话');
    }
  }

  // 1) 上传参考图
  if (!grabExisting) {
    // 🔴 2026-10-22 实测（就是这条把 02 的成品写成了 01 的图）：
    //    复用已登录的 SunBrowser 时，切完「新对话」页面仍可能短暂渲染出**上一轮的生成图**；
    //    而选图按「面积最大」挑，两张同尺寸时 reduce 保留第一个 ⇒ 拿回上一张旧图。
    //    两张任务的 gen.png 因此逐字节相同，verify 还全绿（尺寸/墨迹量都对）。
    //    现在：发送前先记下页面上已有的生成图（按 blob src），之后只认「新出现的」，并取最后一张。
    try {
      const pre = await page.evaluate(snapshot, { alts: GEN_ALT, quota: QUOTA_SRC, refusal: REFUSAL_SRC });
      staleSrcs = new Set(pre.imgs.map((i) => i.src));
      if (staleSrcs.size) log(`⚠ 发送前页面上已有 ${staleSrcs.size} 张旧生成图，本次只认新出现的`);
    } catch { /* 取不到就退化成旧行为，保险由上层的内容去重兜 */ }
    await clearOverlays();
    log('上传参考图', imagePath);
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.setInputFiles(imagePath);
    await sleep(4000);
    await clearOverlays();

    // 2) 填提示词并发送
    const composer = page.locator('#prompt-textarea, div[contenteditable="true"]').first();
    await composer.waitFor({ state: 'visible', timeout: 40000 });
    await composer.click();
    // insertText 比 fill 稳：contenteditable 里 fill 有时只写进第一行
    await page.keyboard.insertText(prompt);
    await sleep(1200);

    const sendBtn = page
      .locator('button[data-testid="send-button"], button[aria-label*="Send"], button[aria-label*="发送"]')
      .first();
    if (await sendBtn.count()) {
      // 遮罩没清干净时 click 会等满 60s 才失败 ⇒ 短超时 + 清遮罩 + force + Enter 四连兜底
      const clicked = await sendBtn
        .click({ timeout: 15000 })
        .then(() => true)
        .catch(async () => {
          await clearOverlays();
          return sendBtn
            .click({ force: true, timeout: 10000 })
            .then(() => true)
            .catch(async () => {
              await page.keyboard.press('Enter').catch(() => {});
              return true;
            });
        });
      if (!clicked) log('⚠ 发送按钮点击失败，已尝试 Enter');
    } else {
      await page.keyboard.press('Enter');
    }
    log('已发送，等出图…');
    await sleep(4000);
  }

  // 3) 等图：既要「有生成图」，又要「不在生成中」，还要连续两轮稳定
  const deadline = Date.now() + timeoutMs;
  let picked = null;
  let lastSig = '';
  let stable = 0;
  let pollFails = 0;
  let lastSt = null;
  // 发送前就在页面上的生成图（上一轮的），本次一律不认，见上传那段的注释
  let staleSrcs = new Set();

  // 🔴 2026-10-20 实测：等图过程中整页偶发被关（Target page/context/browser has been closed），
  //    那一次图其实已经生成好了，只是再也取不到 ⇒ 白等 + 白烧额度。
  //    这里页面没了就先在同一浏览器里另找一个 chatgpt 标签接着等；找不到再让上层重试。
  const recoverPage = async () => {
    try {
      const alive = browser.contexts()[0].pages().filter((p) => !p.isClosed());
      const alt = alive.find((p) => /chatgpt\.com/.test(p.url()));
      if (alt) {
        page = alt;
        page.setDefaultTimeout(60000);
        log('原页面已关闭，切到另一个 chatgpt 标签继续等');
        return true;
      }
    } catch {
      /* ignore */
    }
    return false;
  };

  while (Date.now() < deadline) {
    let st;
    try {
      st = await page.evaluate(snapshot, { alts: GEN_ALT, quota: QUOTA_SRC, refusal: REFUSAL_SRC });
      pollFails = 0;
      lastSt = st;
    } catch (e) {
      pollFails++;
      log(`取图轮询异常（${pollFails}）：${e?.message ?? e}`);
      if (pollFails > 3 || !(await recoverPage())) break;
      continue;
    }
    // 只认「本次新出现」的生成图：发送前就在页面上的那几张是上一轮的成果
    const fresh = staleSrcs.size ? st.imgs.filter((i) => !staleSrcs.has(i.src)) : st.imgs;
    const s = sig(fresh);
    // grab 模式不再看 busy：那一轮已经确认出过图（页面都写着「回答が完了しました」），
    // 只是 busy 判据被页面上某个 "NN%" 文本骗住 ⇒ 再等只会等到超时，等于白丢一张图。
    if (fresh.length && (!st.busy || grabExisting) && s === lastSig) {
      stable++;
    } else {
      stable = 0;
    }
    if (s !== lastSig) {
      log('候选', fresh.length, s || '(无)', st.busy ? '生成中' : '空闲');
      lastSig = s;
    }
    if (stable >= 2) {
      // 🔴 一律取「最后一张」= 最新那一张。以前正常模式取「面积最大」，两张同尺寸时
      //    reduce 会保留第一个（旧图），把上一张的成品当成本次的（2026-10-22 踩过）。
      picked = fresh[fresh.length - 1];
      break;
    }
    // 🔴 站点已经明确说「额度用尽」了：这不是慢，是根本不会出图。
    //    放在「稳定取图」之后判定：万一图真的画完了（额度是这一轮之前用掉的），别把好图扔掉。
    if (st.quota && st.quota.hit) {
      log('🔴 站点返回「出图额度已用尽」——不是网络/登录问题，继续等也不会出图');
      log(`   站点原文：${st.quota.message}`);
      if (st.quota.reset) log(`   重置提示：${st.quota.reset}`);
      writeFail({ reason: 'quota_exhausted', message: st.quota.message, reset: st.quota.reset });
      process.exit(4);
    }
    // 安全策略拒绝：模型明确不画。再等也不会变，直接判死（rc=5），别当环境抖动去重试。
    if (st.refusal && st.refusal.hit) {
      log('🔴 模型安全策略拒绝生成（不是额度/网络问题）');
      log(`   站点原文：${st.refusal.message}`);
      writeFail({ reason: 'policy_refused', message: st.refusal.message });
      process.exit(5);
    }
    // 4s → 2.5s：页面被关的窗口越小越好，图一稳定就立刻取
    await sleep(2500);
  }

  if (!picked) {
    // 最后一轮 snapshot 里已经有结论就直接用（别再去抓一次 DOM：页面可能已经被关了）
    if (lastSt?.refusal?.hit) {
      log(`🔴 超时前已确认模型拒绝生成：${lastSt.refusal.message}`);
      writeFail({ reason: 'policy_refused', message: lastSt.refusal.message });
      process.exit(5);
    }
    if (lastSt?.quota?.hit) {
      log(`🔴 超时前已确认额度用尽：${lastSt.quota.message}`);
      writeFail({ reason: 'quota_exhausted', message: lastSt.quota.message, reset: lastSt.quota.reset });
      process.exit(4);
    }
    let tail = '';
    try {
      tail = await page.evaluate(() => (document.body.innerText || '').slice(-800));
    } catch (e) {
      log('页面已关闭，取不到尾部文本：', e?.message ?? e);
      process.exit(1);
    }
    log('超时仍未拿到图。页面尾部：', tail.replace(/\n+/g, ' | '));
    // 兜底再嗅一次：判据与 snapshot 共用同一份（同一个 bug 不能修两次）
    if (REFUSAL_SRC.some((src) => new RegExp(src, 'i').test(tail))) {
      log('🔴 页面尾部含「安全策略拒绝」文案，按拒绝处理（重试同一句话没用）');
      writeFail({ reason: 'policy_refused', message: tail.replace(/\n+/g, ' | ').slice(-300) });
      process.exit(5);
    }
    if (QUOTA_SRC.some((src) => new RegExp(src, 'i').test(tail))) {
      log('🔴 页面尾部含「额度用尽」文案，按额度用尽处理');
      writeFail({ reason: 'quota_exhausted', message: tail.replace(/\n+/g, ' | ').slice(-300), reset: '' });
      process.exit(4);
    }
    process.exit(1);
  }
  log('选中', `${picked.w}x${picked.h}`, picked.alt);
  try {
    fs.rmSync(failPath, { force: true }); // 成功了就别留失败证据
  } catch {
    /* ignore */
  }

  // 4) 同源 fetch 取回二进制（blob: 只能在页面上下文里读；签名 URL 直接 curl 会 403）
  const b64 = await page.evaluate(async (u) => {
    const r = await fetch(u);
    if (!r.ok) return `ERR:${r.status}`;
    const bytes = new Uint8Array(await r.arrayBuffer());
    let bin = '';
    for (let i = 0; i < bytes.length; i += 0x8000) {
      bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    }
    return btoa(bin);
  }, picked.src);

  if (typeof b64 !== 'string' || b64.startsWith('ERR:')) {
    log('下载失败', b64);
    process.exit(1);
  }
  fs.writeFileSync(outPath, Buffer.from(b64, 'base64'));
  log(`已保存 ${outPath}（${(fs.statSync(outPath).size / 1024).toFixed(0)} KB）`);
  process.exit(0);
} catch (e) {
  log('异常', e?.message ?? e);
  process.exit(1);
} finally {
  // 🔴 复用别人的浏览器时只断开连接，绝不能把它关掉（browser.close() 对 CDP 连接
  //    可能真的把浏览器关掉，用户手上就少了一个登录好的窗口）
  if (!process.env.PW_KEEP_BROWSER) {
    try {
      await browser?.close();
    } catch {
      /* ignore */
    }
  }
}
