-- 由 scripts/image/loading_plate_overlay.py publish 自动生成，勿手改。
-- 铭牌贴片在底图中的归一化锚点（anchorMin / anchorMax），运行时挂到 LoadBg/pic 的子节点上。
-- 一张图只存一组：bbox = 版面几何 ∪ **所有语言**译文的墨迹并集（见 plate_box），
-- 所以每种语言的贴片尺寸完全一致，运行时不用按语言分表。
return {
    ["cn2-X1_loading_01"] = { minX = 0.168129, minY = 0.785156, maxX = 0.988304, maxY = 0.962402 },
    ["cn2-X1_loading_02"] = { minX = 0.168129, minY = 0.785156, maxX = 0.929825, maxY = 0.953125 },
    ["cn2-X1_loading_03"] = { minX = 0.138889, minY = 0.76416, maxX = 1.0, maxY = 0.968262 },
    ["cn2-X1_loading_04"] = { minX = 0.168129, minY = 0.785156, maxX = 0.893275, maxY = 0.967773 },
    ["cn2-X1_loading_05"] = { minX = 0.122807, minY = 0.783203, maxX = 0.997076, maxY = 0.970215 },
    ["cn2-X1_loading_06"] = { minX = 0.156433, minY = 0.782227, maxX = 0.913743, maxY = 0.941406 },
    ["cn2-X1_loading_07"] = { minX = 0.169591, minY = 0.785645, maxX = 1.0, maxY = 0.971191 },
    ["cn2-X1_loading_08"] = { minX = 0.156433, minY = 0.782227, maxX = 0.913743, maxY = 0.936523 },
    ["cn2-X1_loading_09"] = { minX = 0.156433, minY = 0.782227, maxX = 0.950292, maxY = 0.957031 },
}
