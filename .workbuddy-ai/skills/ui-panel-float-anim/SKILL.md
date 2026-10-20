---
name: ui-panel-float-anim
description: 给任意 UI 面板加「弹入 + 循环浮动/呼吸」动画（每日首充 DailyRechargePanel / UI_effect_DailyRechargePanel 那套观感）。当需求是「把 X 面板改成 Y 面板那种浮动动画」「面板太死板加个呼吸」「抄每日首充的动画」时使用。关键词：浮动动画、呼吸动画、弹入、start normal、Animator、AnimatorController、AnimationClip、UI_effect_DailyRechargePanel、FirstRechargePanel、DailyRechargePanel、PlayFlyAnim、CommonButton、legacy Animation、m_ClipBindingConstant。
agent_created: true
---

# UI 面板浮动 / 呼吸动画

**正文在 `docs/ui_panel_float_anim_skill.md`，先读它**（体检、配方、六问、两条落地路径、十坑、三层验收、四个面板的落地曲线都在里面）。

流水线：**①体检 → ②挑配方 → ③dry-run 到 /tmp 并解析 → ④落盘 + 回读校验 → ⑤打 AB**。别跳第 1 步。

本目录只放能直接跑的东西：

- `scripts/audit_panel.py` — **开工前体检**：从 prefab 读 `m_IsActive` / Image 有无 sprite / 锚点是否四边拉伸 /
  LayoutGroup / ScrollRect / 自带 Animator / PlayFlyAnim，打 `INACTIVE|MASK|OWN_ANIM|LEGACY|LAYOUT|SCROLL_DESC|PLAYFLY|CODE_POS`
  标记并给结论；同时告诉你锚点该选谁、其它节点上有多少 Animator 不能碰
- `scripts/gen_float_anim_yaml.py` — Unity 被占用时的后路，直接写 `.anim`/`.controller` 并改 prefab（输出与 Unity 逐字节一致）；
  锚点只由层级决定、目标节点无组件则新增 Animator、写盘前 `check_paths` 不过就直接退出
- `scripts/dump_prefab_tree.py` — 打印 prefab 层级 + anchoredPosition + 组件名，用来取 `baseY`（曲线 y 是绝对值）和确认路径
- `scripts/configs/*.json` — 已落地面板的配方（`expert_panel` / `supreme_hero_popup`）
- `scripts/UIPanelFloatAnimBuilder.template.cs` — Unity 可用时的生成器模板（复制到 `Assets/Editor/`，改类名 + 配置区）
