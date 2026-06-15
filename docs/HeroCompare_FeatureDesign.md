# 英雄对比功能设计文档

## 功能概述

**功能名称**: 英雄对比 (HeroCompare)
**功能目的**: 允许玩家选择两个英雄进行全方位数据对比，帮助玩家在编队、培养、资源分配时做出更明智的决策。
**目标用户**: 所有拥有2个以上英雄的玩家
**入口位置**: 英雄主界面 (HeroMainPanel) 新增"对比"按钮

---

## UI 布局设计

```
┌─────────────────────────────────────────────────────────────┐
│  [返回]              英雄对比                    [清空]      │  topBar
├──────────┬──────────────────────────────────────────────────┤
│          │  ┌──────────┐    ┌──┐    ┌──────────┐           │
│  英雄    │  │ 英雄A     │ VS │  │    │ 英雄B     │           │  heroSlots
│  列表    │  │ 头像/星级  │    │  │    │ 头像/星级  │           │
│          │  │ 等级/战力  │    │  │    │ 等级/战力  │           │
│ (Scroll  │  └──────────┘    └──┘    └──────────┘           │
│  Cycle   │         [⇄ 交换]                                 │
│  View)   ├──────────────────────────────────────────────────┤
│          │  [属性]   [技能]   [装备]          ← Tab 切换    │  tabs
│  5列     │──────────────────────────────────────────────────│
│  滚动    │                                                  │
│          │  ┌─────────────────────────────────────────┐     │
│          │  │           雷达图 (RadarChart)            │     │
│          │  │         六维对比可视化                    │     │
│          │  └─────────────────────────────────────────┘     │
│          │──────────────────────────────────────────────────│
│          │  属性名  │ 英雄A值  │ 差值  │ 英雄B值            │
│          │  生命    │ 12500   │ +500  │ 12000              │  detailPanel
│          │  攻击    │ 850     │ -120  │ 970                │
│          │  物防    │ 320     │  +10  │ 310                │
│          │  魔防    │ 280     │   0   │ 280                │
│          │  速度    │ 145     │  +5   │ 140                │
│          │  战力    │ 58420   │ +2100 │ 56320              │
└──────────┴──────────────────────────────────────────────────┘
```

### 颜色方案

| 元素 | 颜色 | 说明 |
|------|------|------|
| 英雄A区域 | `#4DADFF` (蓝色) | 左侧英雄标识色 |
| 英雄B区域 | `#FF6B57` (红色) | 右侧英雄标识色 |
| 优势属性值 | `#FFD936` (金色高亮) | 数值较大的一方 |
| 正向差值 | `#33D933` (绿色) + ▲ | B > A |
| 负向差值 | `#FF4D4D` (红色) + ▼ | B < A |
| 相等差值 | `#B3B3B3` (灰色) + — | 数值相同 |

---

## 三个 Tab 页

### Tab 1: 属性对比 (Stats)
- 六维雷达图 (HP、攻击、物防、魔防、速度、战力)
- 数值对比表格，标注优势方和差值
- 雷达图采用 Mesh 绘制，支持半透明叠加

### Tab 2: 技能对比 (Skills)
- 主动技能逐一对比 (最多4个主动技能槽)
- 被动技能逐一对比
- 显示技能图标和名称

### Tab 3: 装备对比 (Equipment)
- 装备槽位逐一对比 (6个装备位)
- 显示装备图标和名称，空位显示"空"

---

## 数据流

```
用户点击英雄列表项
       │
       ▼
OnHeroSelected(heroData)
       │
       ├─► 判断当前选择槽位 (slotLeft / slotRight)
       │
       ├─► 更新 leftHeroData / rightHeroData
       │
       ├─► RefreshSlots()  ← 刷新顶部两个英雄槽位卡片
       │
       ├─► RefreshHeroList()  ← 刷新列表中选中状态标记
       │
       └─► RefreshComparison()  ← 根据当前Tab刷新对比内容
              │
              ├─► RefreshStatsComparison()  (Tab=1)
              ├─► RefreshSkillsComparison() (Tab=2)
              ├─► RefreshEquipComparison()  (Tab=3)
              └─► RefreshRadarChart()       (雷达图)
```

### 雷达图数值归一化

雷达图值 = `英雄属性值 / 全服该属性最大值`，范围 `[0, 1]`。
最大值从 `HeroManager.heroDataLists` 中遍历计算。

---

## 文件结构

```
Assets/ManagedResources/~Lua/Modules/HeroCompare/
├── HeroComparePanel.lua    -- 主面板 (面板生命周期、选择逻辑、对比渲染)
├── HeroCompareItem.lua     -- 子组件 (单个英雄槽位展示)
└── HeroRadarChart.lua      -- 雷达图模块 (Mesh绘制六维图)
```

### 注册信息

| 配置项 | 值 |
|--------|-----|
| UIName ID | `1009` |
| UIName 键 | `HeroComparePanel` |
| SubUI 注册 | `HeroCompareItem` → `Modules/HeroCompare/HeroCompareItem` |
| Prefab 名称 | `HeroComparePanel` |
| Prefab 路径 | `Assets/Art/UI/` (需美术制作) |

---

## 集成步骤

### 1. UIConfig 数据配置
在 `UIConfig.lua` (Excel→JSON) 中添加一行:

| id | type | name | assetName | script | noDestory | sortingOrder |
|----|------|------|-----------|--------|-----------|--------------|
| 1009 | 2 | HeroComparePanel | HeroComparePanel | Modules/HeroCompare/HeroComparePanel | 0 | 10 |

### 2. 入口按钮
在 `HeroMainPanel` 或 `BtView` 中添加入口按钮:

```lua
-- 在 BtView.lua 或 HeroMainPanel 合适位置添加
Util.AddClick(btnHeroCompare, function()
    UIManager.OpenPanelWithSound(UIName.HeroComparePanel)
end)
```

### 3. Prefab 制作
需要美术/TA 在 Unity Editor 中制作 `HeroComparePanel` Prefab，包含以下节点:

```
HeroComparePanel (Canvas + BasePanel)
├── topBar
│   ├── btnBack (Button)
│   └── title (Text)
├── content
│   ├── heroList
│   │   └── rect
│   │       └── heroPre (Prefab: icon, name, lv, star, pro, frame, selectMask)
│   ├── heroSlots
│   │   ├── slotLeft (Button → heroRoot: icon, name, lv, star, warPower, pro, tag)
│   │   │   └── emptyTip/Text
│   │   ├── slotRight (Button → heroRoot: icon, name, lv, star, warPower, pro, tag)
│   │   │   └── emptyTip/Text
│   │   ├── vsText (Text: "VS")
│   │   ├── btnSwap (Button: "⇄")
│   │   └── btnClear (Button: "清空")
│   ├── tabs
│   │   ├── btnStats (Button: "属性")
│   │   ├── btnSkills (Button: "技能")
│   │   ├── btnEquip (Button: "装备")
│   │   └── indicator (Image: 选中标记)
│   ├── radarChart (Image: 雷达图容器)
│   └── detailPanel
│       ├── statsPanel
│       │   └── statPre (Prefab: label, leftVal, rightVal, diff, diffArrow)
│       ├── skillsPanel
│       │   └── skillPre (Prefab: slotLabel, leftSkill(icon,name), rightSkill(icon,name))
│       └── equipPanel
│           └── equipPre (Prefab: slotLabel, leftEquip(icon,name,empty), rightEquip(icon,name,empty))
```

### 4. 多语言配置
在 `Language_data` Excel 中添加:

| ID | 中文 | 英文 | 韩文 | 日文 |
|----|------|------|------|------|
| 11900 | 英雄对比 | Hero Compare | 영웅 비교 | ヒーロー比較 |
| 11901 | 技能1 | Skill 1 | 스킬1 | スキル1 |
| 11902 | 技能2 | Skill 2 | 스킬2 | スキル2 |
| 11903 | 技能3 | Skill 3 | 스킬3 | スキル3 |
| 11904 | 技能4 | Skill 4 | 스킬4 | スキル4 |
| 11911 | 装备1 | Equip 1 | 장비1 | 装備1 |
| 11912 | 装备2 | Equip 2 | 장비2 | 装備2 |
| ... | ... | ... | ... | ... |

---

## 交互说明

| 操作 | 行为 |
|------|------|
| 点击英雄列表项 | 自动填入当前选择的槽位 (A或B)，两个槽满后默认替换A |
| 点击槽位A/B | 切换当前选择槽位 |
| 点击交换按钮 | A/B英雄数据互换 |
| 点击清空按钮 | 清除两个英雄选择 |
| 切换Tab | 切换属性/技能/装备对比视图 |
| 点击返回 | 关闭面板 |

---

## 技术要点

1. **雷达图渲染**: 使用 `MeshFilter` + `MeshRenderer` + `UI/Default` Shader 绘制，避免额外 DrawCall
2. **对象池复用**: 属性行/技能行/装备行均使用缓存池，避免频繁 Instantiate/Destroy
3. **数据监听**: 监听 `GameEvent.CustomEvent.OnUpdateHeroDatas` 事件，英雄数据变化时自动刷新
4. **排序策略**: 英雄列表按星级降序 → 战力降序排列
5. **归一化计算**: 雷达图数值基于玩家全英雄最大值归一化到 [0,1]

---

## 后续迭代方向

1. **装备详情对比**: 点击单个装备可查看属性详细对比
2. **历史对比**: 记录玩家上次对比的英雄，方便连续比较
3. **推荐对比**: 同属性/同职业英雄自动推荐对比对象
4. **分享截图**: 一键生成对比截图分享到聊天频道
