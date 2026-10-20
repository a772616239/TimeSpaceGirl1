---
name: ui-panel-float-anim
description: 给任意 UI 面板加「弹入 + 循环浮动/呼吸」动画（每日首充 DailyRechargePanel / UI_effect_DailyRechargePanel 那套观感）。当需求是「把 X 面板改成 Y 面板那种浮动动画」「面板太死板加个呼吸」「抄每日首充的动画」时使用。关键词：浮动动画、呼吸动画、弹入、start normal、Animator、AnimatorController、AnimationClip、UI_effect_DailyRechargePanel、FirstRechargePanel、DailyRechargePanel、PlayFlyAnim、CommonButton、legacy Animation、m_ClipBindingConstant。
agent_created: true
---

# UI 面板浮动 / 呼吸动画

**正文在 `docs/ui_panel_float_anim_skill.md`，先读它**（配方、四问判断、两条落地路径、六个坑、验收清单、每日首充原始曲线数据都在里面）。

本目录只放能直接跑的东西：

- `scripts/UIPanelFloatAnimBuilder.template.cs` — Unity 可用时的生成器模板（复制到 `Assets/Editor/`，改类名 + 配置区）
- `scripts/gen_float_anim_yaml.py` — Unity 被占用时的后路，直接写 `.anim`/`.controller` 并改 prefab（输出与 Unity 逐字节一致）
- `scripts/dump_prefab_tree.py` — 打印 prefab 层级 + anchoredPosition + 组件名，用来取 `baseY` 和确认路径
