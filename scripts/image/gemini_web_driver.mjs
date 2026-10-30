// gemini_web_driver.mjs —— 驱动一个**已经登录**的浏览器（CDP 连上去）在 gemini.google.com 出图。
//
// 与 chatgpt_web_driver.mjs 是兄弟关系，接口对齐（--cdp/--image/--prompt-file/--out/--timeout/--pw），
// 上层 gen_gemini.py 只需换 DRIVER 常量即可复用同一套「rc 4 = 额度用尽」契约。
//
// 用法：
//   node gemini_web_driver.mjs --cdp http://127.0.0.1:61261 --image ref.png \
//        --prompt-file p.txt --out gen.png --timeout 300 --pw <playwright-core 目录>
//
// 退出码：0 拿到图 / 3 需要登录或被拦截 / 4 出图额度用尽 / 5 模型拒绝 / 1 其他失败
//
// 🔴 2026-10-26 实测踩到的坑（照抄前先看）：
//   1) **connectOverCDP(http URL) 在 AdsPower/SunBrowser 上会 socket hang up**：
//      它内部把 /json/version 里的 webSocketDebuggerUrl 里的端口改成另一个（实测 61261→51653，
//      那个端口根本没监听）。必须先 fetch /json/version，把 webSocketDebuggerUrl 原样传进去。
//   2) 生成的图不是 <img src="https://..."> 而是 **blob:**，挂在 `button.image-button` 下，
//      alt 是「，AI 生成」（中文界面）/「AI generated」（英文界面）。
//      上传的参考图预览 alt 是「所上传图片的预览图」/「Uploaded image preview」—— 必须靠 alt 区分，
//      只按 blob 过滤会把参考图自己当成产物（参考图预览在部分界面也是 blob）。
//   3) blob 的 naturalWidth/Height 就是**全分辨率**（实测 1024x1010），不需要点开大图再点「保存」。
//      直接 page.evaluate 里 fetch(blob).arrayBuffer() 取字节，比走下载事件稳。
//   4) 上传入口的按钮 aria-label 是「上传和工具」（中文）/「Upload and tools」（英文），
//      点开后菜单项是「上传文件」/「Upload files」。点它才会弹原生文件选择框 ⇒ 必须用
//      waitForEvent('filechooser') 包住点击，否则 setInputFiles 找不到 input。
//   5) 每个任务必须开**新对话**：同一个对话里连续发图，模型会沿用上一张的构图/配色
//      （实测同一对话第 2 张开始整体色调漂移）。新对话 = goto /app 且 URL 不带 /app/<id>。
import fs from 'node:fs';
import process from 'node:process';

const argv = process.argv.slice(2);
const arg = (k, d = null) => {
  const i = argv.indexOf(`--${k}`);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : d;
};
const flag = (k) => argv.includes(`--${k}`);

const cdp = arg('cdp', 'http://127.0.0.1:9333');
const imagePath = arg('image');
const promptFile = arg('prompt-file');
const outPath = arg('out');
const timeoutMs = Number(arg('timeout', '300')) * 1000;
const pwPath = arg('pw');
const chatUrl = arg('url', 'https://gemini.google.com/app');
const keepOpen = flag('keep-open');
// 2026-10-30：纯文本心跳模式。不建图，只发一句短文本、等一句回复。
// 用途见 gen_pace.py：出图期间每 40 分钟戳一次，保会话活跃 + 早发现登录态掉了。
const textPing = flag('text-ping');

if (!promptFile || !outPath || !pwPath) {
  console.error('[gemini] 参数不全（需要 --prompt-file --out --pw）');
  process.exit(1);
}

const pw = await import(`${pwPath}/index.js`);
const chromium = (pw.default ?? pw).chromium;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.error('[gemini]', ...a);

const say = (s) => {
  try {
    process.stdout.write(s + '\n');
  } catch {
    /* ignore */
  }
};

const prompt = fs
  .readFileSync(promptFile, 'utf8')
  .split('\n')
  .filter((l) => !l.startsWith('# theme='))
  .join('\n')
  .trim();

// ── 多语言文案（界面语言跟随账号，不能只认中文） ──────────────────────────
const L = {
  // 🔴 2026-10-26 实测：英文界面的按钮 aria-label 是「Upload & tools」——
  //    之前只写了「Upload and tools」，匹配不到就**静默降级成纯文生图**，
  //    于是 i2i 的构图锁直接失效（画出来人物大小/位置全看 prompt 心情）。
  addBtn: ['上传和工具', 'Upload & tools', 'Upload and tools', '添加文件', 'Add files',
          '新增檔案和工具', 'Upload'],
  upItem: ['上传文件', 'Upload files', 'Upload file', '上傳檔案'],
  send: ['发送', 'Send', '提交'],
  stop: ['停止', 'Stop', '停止生成'],
  genAlt: ['AI 生成', 'AI generated', 'AI 生成图片'],
  refAlt: ['预览图', 'preview', 'Preview'],
  limit: ['已达到上限', '达到上限', '已达上限', '次数已用完', '今日额度', '无法再生成',
          'you’ve reached', "you've reached", 'limit reached', 'quota', 'try again later', '稍后再试'],
  login: ['登录', 'Sign in', '登录以继续'],
  // 🔴 2026-10-30 实测：被封的号打开 gemini 会落到 myaccount.google.com/restrictions/280，
  //    以前这种页面只会被判成「未登录」，于是上层以为是登录态问题去反复换浏览器 —— 换到天荒地老。
  //    这些词是「号被停用」，跟「没登录」是两种处置（一个换号、一个重新登录）。
  restricted: ['账号已被停用', '账号已停用', '账号受限', '账号已被暂时停用', '违反了《服务条款》',
               'account has been disabled', 'account has been suspended', 'account is suspended',
               'アカウントは停止', 'アカウントが無効', 'アカウントが一時停止'],
};

const hasAny = (text, list) => list.some((k) => text.includes(k));

function failJson(reason, message, extra = {}) {
  const body = {
    reason,
    message: (message || '').slice(0, 1200),
    url: '',
    at: new Date().toISOString(),
    ...extra,
  };
  try {
    fs.writeFileSync(`${outPath}.fail.json`, JSON.stringify(body, null, 2));
  } catch (e) {
    log('写 fail.json 失败', e.message);
  }
  return body;
}

/** 取页面尾部正文（失败取证用） */
async function tailText(page, n = 700) {
  try {
    const t = await page.evaluate(() => document.body.innerText || '');
    return t.replace(/\n{2,}/g, '\n').slice(-n);
  } catch {
    return '';
  }
}

/** 纯文本心跳：在这个标签页里发一句短文本，等一句回复。**不建图、不传图。**
 *
 * 为什么要它（2026-10-30，账号被封之后）：长时间「只建图、不说话」的会话更容易被判成
 * 自动化；而且登录态掉了只有等下一次出图才暴露（白等 5 分钟）。心跳两个作用一起拿。
 *
 * 判定顺序：额度/登录文本 → 停止生成按钮消失 → 拿到 model-response 正文。
 * 🔴 基线要在**发送之后**取：发送前取的话，我们自己那句提示词就够触发「正文变长」的弱判据，
 *    于是把提问当成回复（假阳性），心跳永远报成功、登录态掉了也发现不了。
 */
async function runTextPing(page, editor, text, browser) {
  await editor.click();
  await page.keyboard.insertText(text);
  await sleep(800);

  const sendSel = L.send.map((t) => `button[aria-label*="${t}"]`).join(', ');
  let sent = false;
  for (let i = 0; i < 10; i++) {
    const btn = page.locator(sendSel).first();
    if (await btn.count()) {
      try {
        await btn.click({ timeout: 5000 });
        sent = true;
        break;
      } catch {
        /* 按钮还没启用，等一下再点 */
      }
    }
    await sleep(500);
  }
  if (!sent) {
    await editor.press('Enter').catch(() => {});
    log('⚠ 没找到发送按钮，心跳改用回车');
  }
  log('心跳已发送，等回复');

  await sleep(1200);
  const base = await page.evaluate(() => document.body.innerText || '');
  const deadline = Date.now() + timeoutMs;
  let reply = '';
  let polls = 0;
  while (Date.now() < deadline) {
    await sleep(2000);
    polls += 1;
    let txt = '';
    try {
      txt = await page.evaluate(() => document.body.innerText || '');
    } catch {
      continue;
    }
    if (hasAny(txt, L.limit)) {
      failJson('quota', txt);
      return 4;
    }
    if (hasAny(txt, L.login) && !txt.includes('发起新对话')) {
      failJson('login', txt);
      return 3;
    }
    const stopping = await page
      .evaluate(
        (stops) => [...document.querySelectorAll('button')].some((b) => stops.some((k) => (b.getAttribute('aria-label') || '').includes(k))),
        L.stop
      )
      .catch(() => false);
    if (stopping) continue;
    const got = await page
      .evaluate(() => {
        const nodes = [...document.querySelectorAll('model-response, .model-response-text, message-content')];
        const last = nodes.length ? nodes[nodes.length - 1] : null;
        return last ? (last.innerText || '').trim() : '';
      })
      .catch(() => '');
    if (got) {
      reply = got;
      break;
    }
    // 选择器又变了（Gemini 前端隔三差五改类名）：退回弱判据，但至少等 3 轮，别把回显当回复
    if (polls >= 3 && txt.length > base.length + 10) {
      reply = txt.slice(base.length).trim();
      if (reply) break;
    }
  }

  try {
    fs.writeFileSync(
      `${outPath}.ping.json`,
      JSON.stringify(
        { ok: Boolean(reply), mode: 'text-ping', prompt: text,
          reply: reply.slice(0, 500), url: page.url(), at: new Date().toISOString() },
        null,
        2
      )
    );
  } catch (e) {
    log('写 ping.json 失败', e.message);
  }

  if (!reply) {
    say('心跳没拿到回复（可能被拦/需要登录）');
    failJson('ping-no-reply', await tailText(page, 800));
    return 1;
  }
  say(`✅ 心跳有回复：${reply.replace(/\s+/g, ' ').slice(0, 80)}`);
  if (!keepOpen && browser) await browser.close().catch(() => {});
  return 0;
}

/** 统计「已经出现的生成图」数量 —— 用来判断这一轮有没有新图 */
async function countGenerated(page) {
  return page.evaluate((alts) => {
    const imgs = [...document.querySelectorAll('button.image-button img, img.image')];
    return imgs.filter((e) => {
      const a = e.alt || '';
      return alts.some((k) => a.includes(k)) && e.src.startsWith('blob:');
    }).length;
  }, L.genAlt);
}

async function main() {
  // 🔴 坑 1：必须用 /json/version 里原样的 webSocketDebuggerUrl
  let wsUrl = null;
  try {
    const v = await (await fetch(`${cdp.replace(/\/$/, '')}/json/version`)).json();
    wsUrl = v.webSocketDebuggerUrl;
  } catch (e) {
    say(`CDP 不可达：${cdp}（${e.message}）`);
    failJson('cdp-unreachable', `无法读取 ${cdp}/json/version：${e.message}`);
    return 1;
  }
  log('ws', wsUrl);
  const browser = await chromium.connectOverCDP(wsUrl);
  // 🔴 浏览器被关掉/崩掉时，轮询里的 page.evaluate 只会一直抛（或干脆挂住），
  //    以前要等满 --timeout 300 才发现没图（2026-10-26 白躺 5 分钟）。
  //    这里挂一个断连标记 + 连续失败计数：一旦确认断了立刻 rc=3，让上层马上换号。
  let dead = false;
  browser.on('disconnected', () => { dead = true; });
  const ctx = browser.contexts()[0] || (await browser.newContext());

  // 复用已有的 gemini 标签，没有就新开一个
  let page = ctx.pages().find((p) => p.url().includes('gemini.google.com'));
  if (!page) {
    page = await ctx.newPage();
  }
  await page.bringToFront();
  await page.goto(chatUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await sleep(4000);

  // 关掉可能残留的大图预览层
  await page.keyboard.press('Escape').catch(() => {});
  await sleep(500);

  // 登录态检查
  const body0 = await page.evaluate(() => document.body.innerText || '');
  // 🔴 「号被停用」优先于「未登录」：2026-10-30 实测被封的号打开 gemini 会落到
  //    myaccount.google.com/restrictions/280 —— 以前这种页面只会被判成「未登录」，
  //    上层于是以为是登录态问题，反复换浏览器/换 profile，换了半天才发现是号没了。
  //    两种处置完全不同：停用只能换号，未登录还能重登。所以先按下这条判据。
  const url0 = page.url();
  if (url0.includes('/restrictions')) {
    say('Google 账号受限/被停用（落在受限页）');
    failJson('account-restricted', body0.slice(0, 800), { url: url0 });
    return 3;
  }
  if (hasAny(body0, ['登录以继续', 'Sign in to continue']) && !body0.includes('发起新对话')) {
    say('需要登录');
    failJson('login', body0.slice(0, 500));
    return 3;
  }

  const editor = page.locator('div.ql-editor[contenteditable="true"]').first();
  if (!(await editor.count())) {
    const t = await tailText(page);
    // 正文里有停用措辞 + 连输入框都没有 ⇒ 同样是号被停用，别报成「未登录」
    if (hasAny(t, L.restricted) || url0.includes('myaccount.google.com')) {
      say('Google 账号受限/被停用（无输入框 + 停用措辞）');
      failJson('account-restricted', t, { url: url0 });
      return 3;
    }
    say('找不到输入框（可能需要登录/被拦截）');
    failJson('no-composer', t);
    return 3;
  }

  // ── ⓞ 纯文本心跳（--text-ping）：发一句话、要一句回复，全程不传图 ──────────
  if (textPing) {
    log('文本心跳模式：不建图');
    return await runTextPing(page, editor, prompt, browser);
  }

  // ── ① 上传参考图（有就传） ────────────────────────────────────────────
  if (imagePath && fs.existsSync(imagePath)) {
    const addSel = L.addBtn.map((t) => `button[aria-label*="${t}"]`).join(', ');
    let addBtn = page.locator(addSel).first();
    if (!(await addBtn.count())) {
      // 页面可能还在渲染（尤其刚 goto /app）：等一拍再找一次，别急着降级
      await sleep(2500);
      addBtn = page.locator(addSel).first();
    }
    if (await addBtn.count()) {
      await addBtn.click();
      await sleep(900);
      const upSel = L.upItem.map((t) => `button[aria-label^="${t}"], [role="menuitem"]:has-text("${t}")`).join(', ');
      const upItem = page.locator(upSel).first();
      try {
        const [fc] = await Promise.all([
          page.waitForEvent('filechooser', { timeout: 20000 }),
          upItem.click(),
        ]);
        await fc.setFiles(imagePath);
        log('已上传参考图', imagePath);
      } catch (e) {
        // 菜单没弹文件框：直接找隐藏 input 兜底
        const inp = page.locator('input[type="file"]').first();
        if (await inp.count()) {
          await inp.setInputFiles(imagePath);
          log('参考图走隐藏 input 上传');
        } else {
          say('上传参考图失败');
          failJson('upload-failed', e.message);
          return 1;
        }
      }
      // 等缩略图出现（说明上传完成，不是还在传）
      const refSel = L.refAlt.map((t) => `img[alt*="${t}"]`).join(', ');
      for (let i = 0; i < 20; i++) {
        if (await page.locator(refSel).count()) break;
        await sleep(500);
      }
      await sleep(800);
    } else {
      // 到这儿就是**参考图没传上去**：i2i 的构图锁失效，画面全靠 prompt。
      // 以前只打一行 warning 就往下画，结果「画出来的头身比不对」要人肉比对原图才发现。
      log('⚠⚠ 没找到上传按钮（aria-label 又变了？）—— 本次纯文生图，构图可能跑偏');
      // 单独落一个 .noref.json：**不能写 .fail.json** —— 那是失败证据，成功出图却留个
      // fail 文件会污染上层的额度/拒画判据。这个文件只用来事后核对「哪几张没吃到参考图」。
      try {
        fs.writeFileSync(`${outPath}.noref.json`,
          JSON.stringify({ reason: 'no-upload-button', tried: L.addBtn, at: new Date().toISOString() }, null, 2));
      } catch { /* 记不下也不影响出图 */ }
    }
  }

  // ── ② 输入 prompt 并发送 ──────────────────────────────────────────────
  const base = await countGenerated(page);
  log('发送前已有生成图', base);

  await editor.click();
  await page.keyboard.insertText(prompt);
  await sleep(1200);

  const sendSel = L.send.map((t) => `button[aria-label*="${t}"]`).join(', ');
  let sent = false;
  for (let i = 0; i < 12; i++) {
    const btn = page.locator(sendSel).first();
    if (await btn.count()) {
      try {
        await btn.click({ timeout: 5000 });
        sent = true;
        break;
      } catch {
        /* 按钮还没启用，等一下再点 */
      }
    }
    await sleep(500);
  }
  if (!sent) {
    // 兜底：回车提交
    await editor.press('Enter').catch(() => {});
    sent = true;
    log('⚠ 没找到发送按钮，改用回车');
  }
  log('已发送，开始等图');

  // ── ③ 轮询等图 ────────────────────────────────────────────────────────
  const deadline = Date.now() + timeoutMs;
  let got = null;
  let lastTxt = '';
  let broken = 0;
  while (Date.now() < deadline) {
    await sleep(2500);
    if (dead || page.isClosed()) {
      say('浏览器已断开（被关闭/崩溃）');
      failJson('browser-closed', `CDP ${cdp} 连接已断开或标签页被关闭`);
      return 3;
    }
    let txt = '';
    try {
      txt = await tailText(page, 900);
    } catch (e) {
      broken += 1;
      if (broken >= 3) {
        say('浏览器已断开（页面连续取不到）');
        failJson('browser-closed', `页面连续 ${broken} 次求值失败：${e.message}`);
        return 3;
      }
      continue;
    }
    broken = 0;
    lastTxt = txt;

    // 额度/拒绝先判，别等到超时才发现
    if (hasAny(txt, L.limit)) {
      say('额度/频率受限');
      failJson('quota', txt, { reset: (txt.match(/\d{1,2}[:：]\d{2}/) || [''])[0] });
      return 4;
    }

    const n = await countGenerated(page).catch(() => -1);
    const stopping = await page.evaluate(
      (stops) => [...document.querySelectorAll('button')].some((b) => stops.some((k) => (b.getAttribute('aria-label') || '').includes(k))),
      L.stop
    ).catch(() => false);
    if (n > base && !stopping) {
      // 图出来了，再稳 1.5s 让 blob 落定
      await sleep(1500);
      got = await page.evaluate((alts) => {
        const imgs = [...document.querySelectorAll('button.image-button img, img.image')].filter((e) => {
          const a = e.alt || '';
          return alts.some((k) => a.includes(k)) && e.src.startsWith('blob:');
        });
        if (!imgs.length) return null;
        // 多张时取面积最大的那张
        imgs.sort((a, b) => b.naturalWidth * b.naturalHeight - a.naturalWidth * a.naturalHeight);
        const e = imgs[0];
        return { src: e.src, w: e.naturalWidth, h: e.naturalHeight, alt: e.alt || '' };
      }, L.genAlt);
      if (got) break;
    }
  }

  if (!got) {
    // 没图：区分「模型只回了文字」和「纯粹超时」
    const refused = /无法|不能|抱歉|Sorry|can't|cannot|无法生成/.test(lastTxt);
    say(refused ? '模型拒绝/只回了文字' : '超时未出图');
    failJson(refused ? 'refused' : 'timeout', lastTxt);
    return refused ? 5 : 1;
  }

  // ── ④ 取字节（blob 全分辨率） ─────────────────────────────────────────
  // 🔴 坑 6：直接 fetch(blob:) 会 `TypeError: Failed to fetch` —— 消息渲染完页面会把
  //    blob URL revoke 掉（或 CSP 拦）。改用 canvas drawImage + toDataURL，绕开 fetch，
  //    拿到的仍是 naturalWidth/Height 的真实分辨率。canvas 被跨域污染时才回退 fetch。
  let b64 = await page.evaluate(async (src) => {
    const imgs = [...document.querySelectorAll('button.image-button img, img.image')].filter((e) => e.src === src);
    const img = imgs[0];
    if (!img) return null;
    const w = img.naturalWidth, h = img.naturalHeight;
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0, w, h);
    try {
      return c.toDataURL('image/png').split(',')[1];
    } catch {
      return null;
    }
  }, got.src);

  if (!b64) {
    // 回退：fetch 原 blob
    b64 = await page.evaluate(async (src) => {
      try {
        const r = await fetch(src);
        const buf = await r.arrayBuffer();
        const bytes = new Uint8Array(buf);
        let s = '';
        const CH = 0x8000;
        for (let i = 0; i < bytes.length; i += CH) s += String.fromCharCode.apply(null, bytes.subarray(i, i + CH));
        return btoa(s);
      } catch {
        return null;
      }
    }, got.src);
  }

  if (!b64) {
    say('图已生成但取字节失败（blob 被回收）');
    failJson('blob-lost', lastTxt, { src: got.src });
    return 1;
  }

  const buf = Buffer.from(b64, 'base64');
  fs.mkdirSync(outPath.replace(/\/[^/]+$/, '') || '.', { recursive: true });
  fs.writeFileSync(outPath, buf);
  say(`✅ 出图 ${got.w}x${got.h}  ${(buf.length / 1024).toFixed(0)} KB → ${outPath}`);
  fs.writeFileSync(
    `${outPath}.meta.json`,
    JSON.stringify({ w: got.w, h: got.h, alt: got.alt, url: page.url(), at: new Date().toISOString() }, null, 2)
  );

  if (!keepOpen) {
    // 只断开，不关窗口（窗口是用户的浏览器）
    await browser.close().catch(() => {});
  }
  return 0;
}

let rc = 1;
try {
  rc = await main();
} catch (e) {
  say(`驱动异常：${e.message}`);
  failJson('exception', e.stack || e.message);
  rc = 1;
}
process.exit(rc);
