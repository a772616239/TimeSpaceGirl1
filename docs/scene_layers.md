# 地图分层拆解（改一层不用写回图集）

地图 prefab（如 `Map1.prefab`）是若干 Quad 从**同一张图集**里按 `_Offset_WH` 取子矩形拼出来的
（`X1_backgroud_UV.shader`）。直接改图集会牵动同图集里其它层，所以改一层就先把它拆成独立文件。

## 两条命令

```bash
# 1) 拆：prefab → 每层一张 PNG + layers.json（含变换/排序/材质/shader 参数/UV 矩形/倾角）
python3 scripts/image/scene_unpack.py --prefab Assets/ManagedResources/Prefabs/Battle/Map1.prefab

# 2) 拼：看叠层 / 单看一层 / 打包回图集（默认都不碰真资源）
python3 scripts/image/scene_compose.py --dir _output/scene/Map1                      # 叠层预览
python3 scripts/image/scene_compose.py --dir _output/scene/Map1 --only 前景1          # 只出一层
python3 scripts/image/scene_compose.py --dir _output/scene/Map1 --pack               # → atlas_repacked.png
python3 scripts/image/scene_compose.py --dir _output/scene/Map1 --pack --apply       # 真写回（自动备份+台账）
```

## 改一层的正确姿势（不覆盖原导出）

把改好的 PNG 丢进 `overrides/`，文件名与 `layers/` 里同名即可 —— compose 和 pack 都会优先读它：

```
_output/scene/Map1/
  layers/          原样导出，别动（重跑 unpack 会覆盖）
  overrides/       你的改动放这里，同文件名覆盖
  layers.json      图层元数据
```

## 产出

| 文件 | 说明 |
|---|---|
| `layers/NN_<对象名>.png` | 按该层 UV 矩形从图集裁出的**原像素**（不缩放），RGBA |
| `layers.json` | `uvRect` / `pixelBox` / `sortingOrder` / `position` / `worldSize` / `tiltX` / `isFlat` / `speedTilling` / `isLoop` |
| `preview_layers.png` | 联系表，每层一段 + 棋盘底看 alpha |
| `preview_compose.png` | billboard 叠层（忽略 30° 倾角与 z 视差，只看相对关系） |
| `atlas_repacked.png` | `--pack` 产物：图层按绘制顺序回贴图集 |

## 🔴 红线

- **拆-包必须无损**：`--pack` 在没改任何层时应与原图集**逐像素相同**（实测差异 0.0000%）。这一条是能不能放心
  只改一层的前提，改完图集尺寸/模式会漂，先跑一次空包验。
- **回贴用 `paste` 硬替换**，绝不能 `alpha_composite`（会把新图透明处的旧物件留成残影）。
  同图集多层共用行时按 `sortingOrder` 回贴，前景覆盖后景，与图集现状一致。
- **这不是 2D 叠层场景**：`floor` / `floor2` 的 X 旋转是 **90°（平躺地面）**，背景板是 **30° 倾斜**、
  z 从 3 到 25。所以 2D 叠层预览只是「相对关系」，不是取景；真实构图只能进编辑器看。
  合成器默认跳过 `isFlat`（>45°）的层，要硬看内容加 `--include-flat`。
- **guid 定位别用 Python 遍历 `.meta`**：这台机器每次 open 约 7ms，46k 文件要 6 分钟（会被超时杀掉）。
  脚本用 `grep -rl` 一趟（~4s）并缓存到 `_output/cache/guid_paths.json`；空命中不入缓存，下次会重试。
