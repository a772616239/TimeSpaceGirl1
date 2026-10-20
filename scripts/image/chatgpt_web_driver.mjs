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
// 退出码：0 拿到图 / 3 需要登录或被人机验证挡住 / 1 其他失败
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

const snapshot = (alts) => {
  const uploads = ['用户附件', 'Attached', 'attachment', '添付', '첨부', 'Adjunto'];
  const isGen = (im) =>
    alts.some((a) => (im.alt || '').includes(a)) ||
    // 兜底：结构上就在「生成图」容器里（alt 文案没覆盖到的语言走这条）
    (!!im.closest('[data-testid*="generated-image"]') &&
      !uploads.some((a) => (im.alt || '').includes(a)));
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
    // 生成中：停止按钮 / 进度百分比 / 「正在勾勒草图」
    busy:
      !!document.querySelector('[data-testid="stop-button"]') ||
      /\d{1,3}\s*%/.test(document.body.innerText || '') ||
      /正在(勾勒|生成|绘制|创建)|Creating image|Generating image|画像を(生成|作成)|그림을 그리는/i.test(
        document.body.innerText || ''
      ),
    text: (document.body.innerText || '').slice(-600),
  };
};

const sig = (imgs) => imgs.map((i) => `${i.w}x${i.h}`).sort().join(',');

let browser;
try {
  browser = await chromium.connectOverCDP(cdp);
  const ctx = browser.contexts()[0];
  // 复用外部浏览器（如 AdsPower 的 SunBrowser）时，那个 profile 里可能开着七八个标签页。
  // 直接拿 pages()[0] 会把用户正在看的页面导航走，所以：已登录的 chatgpt 标签优先复用，
  // 没有就新开一个，绝不抢别人的 tab。
  const pages = ctx.pages();
  const page =
    pages.find((p) => /chatgpt\.com/.test(p.url())) ??
    (pages.length && !process.env.PW_KEEP_BROWSER ? pages[0] : null) ??
    (await ctx.newPage());
  page.setDefaultTimeout(60000);

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

  // 1) 上传参考图
  if (!grabExisting) {
    log('上传参考图', imagePath);
    const fileInput = page.locator('input[type="file"]').first();
    await fileInput.setInputFiles(imagePath);
    await sleep(4000);

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
      await sendBtn.click();
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
  while (Date.now() < deadline) {
    const st = await page.evaluate(snapshot, GEN_ALT);
    const s = sig(st.imgs);
    if (st.imgs.length && !st.busy && s === lastSig) {
      stable++;
    } else {
      stable = 0;
    }
    if (s !== lastSig) {
      log('候选', st.imgs.length, s || '(无)', st.busy ? '生成中' : '空闲');
      lastSig = s;
    }
    if (stable >= 2) {
      // grab 模式取「最后一张」（当前对话最新的结果）；正常模式取面积最大的那张
      picked = grabExisting
        ? st.imgs[st.imgs.length - 1]
        : st.imgs.reduce((a, b) => (a.w * a.h >= b.w * b.h ? a : b));
      break;
    }
    await sleep(4000);
  }

  if (!picked) {
    const tail = await page.evaluate(() => (document.body.innerText || '').slice(-800));
    log('超时仍未拿到图。页面尾部：', tail.replace(/\n+/g, ' | '));
    if (/limit|上限|quota|额度/i.test(tail)) {
      log('⚠ 可能是出图额度用尽');
      process.exit(3);
    }
    process.exit(1);
  }
  log('选中', `${picked.w}x${picked.h}`, picked.alt);

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
