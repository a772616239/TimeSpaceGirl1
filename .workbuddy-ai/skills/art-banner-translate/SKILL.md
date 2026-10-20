---
name: art-banner-translate
description: 把战令横幅里烘进图的中文艺术字换成英文版（迷雾/爬塔/深渊/魔塔/异端那批 884×544 的 *_bg_zh.png）。当需求是「这张图翻成英文」「英文版横幅缺一张」「ArtFont_en 里没有对应图」时使用。关键词：翻译图片、图片翻译、英文版横幅、战令横幅、ArtFont_zh、ArtFont_en、OperatingPanelAtlas、cn2-X1_zhanling、擦字、去文字、重绘文字、banner translate、TS-Art-Translate。
agent_created: true
---

# 战令横幅中文美术字 → 英文版

**正文在 `docs/art_banner_translate_skill.md`，先读它**（译名真源、三段配方、六条像素断言、六个坑位、案例数据都在里面）。

流水线：**①`scan` 盘点 → ②`batch --stage run` 出图 → ③`batch --stage verify` 验收 → ④`batch --stage publish` 写回**。别跳第 3 步。

执行口（都在仓库里，直接跑）：

- `scripts/image/banner_translate.py` — 唯一的实现。子命令 `scan` / `run` / `verify` / `publish` / `batch`
- `scripts/image/banner_translate_map.json` — 译名表（改译名只改这里，别改代码里的字符串）
- `.jenkins/jobs/TS-Art-Translate.groovy` — Jenkins job，`MODE=batch` 缺哪张补哪张

三条不能忘的：

1. **译名以已上线英文图为准**（`pata_bg_en` / `shenyuan_bg_en`），与语言表冲突时听图的。
   第三行「累计返利 __ 倍」不排，留给 UI 动态数字。
2. **重建区横向到 x=342 为止**，再往右是斜的深色装饰板，碰了就出直边。
   辉光也必须裁在重建区内。
3. **`.meta` 要用同族模板**（`*_zhanling*bg_en.png.meta`），随便抓一份会让横幅在 Unity 里糊掉。

只吃 `*_bg_zh.png`（884×544 那一族）。别的版面要重新量 `LINE_TOPS`，不能直接套。
