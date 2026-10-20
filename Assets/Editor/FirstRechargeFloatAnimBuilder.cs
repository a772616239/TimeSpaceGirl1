// 首充面板「浮动/呼吸动画」生成器
//
// 背景：每日首充（DailyRechargePanel）根节点挂 Animator + UI_effect_DailyRechargePanel.controller，
// 用 start（弹出）+ normal（3 秒循环呼吸）两个状态做出「整块在浮动」的观感。
// 首充（FirstRechargePanel）原来只有旧版 legacy Animation（一次性弹出，播完静止），
// 且节点路径与每日首充完全不同（frame/BG、frame/rewardBg/rewardDay1~3、frame/tabsContent…），
// 直接复用同一个 controller 会因为路径绑不上而静默不生效，所以这里按首充自己的层级重新生成。
//
// 使用：
//   菜单 Tools/UI/首充面板/生成并挂载浮动动画
//   或命令行：Unity -batchmode -quit -projectPath <工程> -executeMethod FirstRechargeFloatAnimBuilder.BuildFromCommandLine
//
// 说明：
//   * 不碰 frame 自身的位置——首充的开场滑动/淡入由 frame 上的 PlayFlyAnim(DOTween) 负责，
//     Animator 再去写 frame.anchoredPosition 会和它抢同一个属性，导致开场抖动。
//   * 不碰 rewardDay1~3 的 anchoredPosition——它们在 HorizontalLayoutGroup 下，位置由布局组重算。
//   * 不动任何 Lua 逻辑。

using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class FirstRechargeFloatAnimBuilder
{
    private const string PrefabPath = "Assets/ManagedResources/Prefabs/UI/FirstRecharge/FirstRechargePanel.prefab";
    private const string AnimDir = "Assets/Art/UIAni";
    private const string ControllerPath = AnimDir + "/cn2-X1_UI_FirstRechargePanel_float.controller";
    private const string StartClipPath = AnimDir + "/cn2-X1_UI_FirstRechargePanel_float_start.anim";
    private const string NormalClipPath = AnimDir + "/cn2-X1_UI_FirstRechargePanel_float_normal.anim";
    private const string LegacyClipPath = AnimDir + "/cn2-X1_UI_FirstRechargePanel.anim";

    // 基准值 = prefab 里对应 RectTransform 的 anchoredPosition.y，曲线写的是绝对值，必须对齐
    // BaseTabsY 只用于注释对照：tabsContent 现在不允许做位置动画（它压在底图镂空上，见 BuildNormalClip 注释）
    private const float BaseTabsY = 153.5f;
    private const float BaseRewardBgY = -226.18f;
    private const float BaseRechargeBtnY = -600f;
    private const float BaseTipsY = -462f;

    private const float NormalLoopTime = 3f;

    [MenuItem("Tools/UI/首充面板/生成并挂载浮动动画")]
    public static void Build()
    {
        if (AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath) == null)
        {
            Debug.LogError("[FirstRechargeFloat] 找不到 prefab：" + PrefabPath);
            return;
        }

        AnimationClip startClip = CreateClip(StartClipPath, false, 1f);
        AnimationClip normalClip = CreateClip(NormalClipPath, true, NormalLoopTime);

        BuildStartClip(startClip);
        BuildNormalClip(normalClip);

        EditorUtility.SetDirty(startClip);
        EditorUtility.SetDirty(normalClip);
        AssetDatabase.SaveAssets();

        AnimatorController controller = BuildController(startClip, normalClip);
        AttachToPrefab(controller);

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("[FirstRechargeFloat] 完成：start=" + StartClipPath + " normal=" + NormalClipPath +
                  " controller=" + ControllerPath + "，已挂到 " + PrefabPath);
        Debug.Log("[FirstRechargeFloat] 状态机 start(" + startClip.length.ToString("0.00") + "s, loop=" + IsLooping(startClip) +
                  ") → normal(" + normalClip.length.ToString("0.00") + "s, loop=" + IsLooping(normalClip) + ")");
    }

    /// <summary>供 -executeMethod 调用（批处理模式下不能靠菜单）。</summary>
    public static void BuildFromCommandLine()
    {
        Build();
    }

    [MenuItem("Tools/UI/首充面板/还原为旧版 Animation")]
    public static void RestoreLegacyAnimation()
    {
        AnimationClip legacy = AssetDatabase.LoadAssetAtPath<AnimationClip>(LegacyClipPath);
        GameObject contents = PrefabUtility.LoadPrefabContents(PrefabPath);
        try
        {
            Animator animator = contents.GetComponent<Animator>();
            if (animator != null)
            {
                UnityEngine.Object.DestroyImmediate(animator, true);
            }

            Animation animation = contents.GetComponent<Animation>();
            if (animation == null)
            {
                animation = contents.AddComponent<Animation>();
            }
            animation.clip = legacy;
            animation.playAutomatically = true;

            PrefabUtility.SaveAsPrefabAsset(contents, PrefabPath);
        }
        finally
        {
            PrefabUtility.UnloadPrefabContents(contents);
        }

        AssetDatabase.SaveAssets();
        Debug.Log("[FirstRechargeFloat] 已还原为旧版 Animation：" + LegacyClipPath);
    }

    private static bool IsLooping(AnimationClip clip)
    {
        SerializedObject so = new SerializedObject(clip);
        SerializedProperty settings = so.FindProperty("m_AnimationClipSettings");
        SerializedProperty loopProp = settings != null ? settings.FindPropertyRelative("m_LoopTime") : null;
        return loopProp != null && loopProp.boolValue;
    }

    private static AnimationClip CreateClip(string path, bool loop, float stopTime)
    {
        AssetDatabase.DeleteAsset(path);

        AnimationClip clip = new AnimationClip();
        clip.frameRate = 30f;
        AssetDatabase.CreateAsset(clip, path);

        // 循环标志存在 m_AnimationClipSettings.m_LoopTime 里，用 SerializedObject 改比
        // AnimationUtility.Get/SetAnimationClipSettings 更稳（后者跨版本类型名有变动风险）
        SerializedObject so = new SerializedObject(clip);
        SerializedProperty settings = so.FindProperty("m_AnimationClipSettings");
        if (settings != null)
        {
            SerializedProperty loopProp = settings.FindPropertyRelative("m_LoopTime");
            if (loopProp != null)
            {
                loopProp.boolValue = loop;
            }
            SerializedProperty stopProp = settings.FindPropertyRelative("m_StopTime");
            if (stopProp != null)
            {
                stopProp.floatValue = stopTime;
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        return clip;
    }

    // ---------------------------------------------------------------- start：弹出

    private static void BuildStartClip(AnimationClip clip)
    {
        // 保留旧 clip 里的两处缩放弹跳（frame 整体、hero 立绘），位置动画交给 PlayFlyAnim
        Scale(clip, "frame", new[] { 0f, 0.1333f, 0.2167f, 0.3167f }, new[] { 1f, 1.2f, 0.95f, 1f });
        Scale(clip, "hero", new[] { 0f, 0.0667f, 0.2667f, 0.3667f }, new[] { 1f, 1.3f, 0.95f, 1f });

        // tab 条：底图 BG 在 y 101.5~156.5 是一整条全透明镂空，tab 条就贴在这个洞上。
        // 所以它只能"放大"（永远盖住洞），绝不能缩小或上移，否则洞的底边会漏出背景，
        // 看起来就是一条 1~2px 的杂色缝（踩过一次，别再加 Float）。
        Scale(clip, "frame/tabsContent", new[] { 0.30f, 0.42f, 0.52f }, new[] { 1f, 1.08f, 1f });

        // 奖励区
        Scale(clip, "frame/rewardBg", new[] { 0.40f, 0.52f, 0.62f }, new[] { 0.88f, 1.05f, 1f });
        Float(clip, "frame/rewardBg", "m_AnchoredPosition.y", new[] { 0.40f, 0.62f }, new[] { BaseRewardBgY - 18f, BaseRewardBgY });

        // 三张奖励卡依次弹出（只做缩放，位置由 HorizontalLayoutGroup 接管，不能动）
        Scale(clip, "frame/rewardBg/rewardDay1", new[] { 0.50f, 0.60f, 0.70f }, new[] { 0f, 1.12f, 1f });
        Scale(clip, "frame/rewardBg/rewardDay2", new[] { 0.58f, 0.68f, 0.78f }, new[] { 0f, 1.12f, 1f });
        Scale(clip, "frame/rewardBg/rewardDay3", new[] { 0.66f, 0.76f, 0.86f }, new[] { 0f, 1.12f, 1f });

        // 充值按钮：只做位移。按钮自己挂着 CommonButton 控制器，它的 clip 每帧都在写
        // 自身 m_LocalScale，父级 Animator 再写缩放会被子级覆盖，等于白写。
        Float(clip, "frame/rechargeBtn", "m_AnchoredPosition.y", new[] { 0.72f, 0.96f }, new[] { BaseRechargeBtnY - 18f, BaseRechargeBtnY });

        // 底部提示
        Float(clip, "frame/tips", "m_AnchoredPosition.y", new[] { 0.78f, 0.96f }, new[] { BaseTipsY - 18f, BaseTipsY });
    }

    // ---------------------------------------------------------------- normal：3 秒循环呼吸

    private static void BuildNormalClip(AnimationClip clip)
    {
        float t0 = 0f;
        float t1 = NormalLoopTime * 0.5f;
        float t2 = NormalLoopTime;

        // 面板主体呼吸：对齐每日首充 normal 里 frame/bg 的 1→1.02→1。
        // BG 是 1080x1253 的整块底板（frame 第一个子节点，压在所有内容下面），
        // 只放大不缩小，不会露边；觉得过头把 1.02 调小即可。
        Scale(clip, "frame/BG", new[] { t0, t1, t2 }, new[] { 1f, 1.02f, 1f });

        // 奖励区：呼吸 + 下沉（对应每日首充的 rewardContent 缩放 0.99 / y -10）
        Scale(clip, "frame/rewardBg", new[] { t0, t1, t2 }, new[] { 1f, 1.015f, 1f });
        Float(clip, "frame/rewardBg", "m_AnchoredPosition.y", new[] { t0, t1, t2 }, new[] { BaseRewardBgY, BaseRewardBgY - 10f, BaseRewardBgY });

        // tab 条反向轻抬，与奖励区错开相位
        Float(clip, "frame/tabsContent", "m_AnchoredPosition.y", new[] { t0, t1, t2 }, new[] { BaseTabsY, BaseTabsY + 5f, BaseTabsY });

        // 按钮：一个循环内两次脉冲（和每日首充 dealBtn 同节奏）；缩放交给 CommonButton 控制器，这里只动位置
        float[] btnT = { 0f, NormalLoopTime * 0.2444f, t1, NormalLoopTime * 0.7778f, t2 };
        Float(clip, "frame/rechargeBtn", "m_AnchoredPosition.y", btnT, new[] { BaseRechargeBtnY, BaseRechargeBtnY + 3f, BaseRechargeBtnY, BaseRechargeBtnY + 3f, BaseRechargeBtnY });

        // 底部提示
        Float(clip, "frame/tips", "m_AnchoredPosition.y", new[] { t0, t1, t2 }, new[] { BaseTipsY, BaseTipsY - 3f, BaseTipsY });
    }

    // ---------------------------------------------------------------- 工具

    private static void Float(AnimationClip clip, string path, string property, float[] times, float[] values)
    {
        AddCurve(clip, path, property, times, values, typeof(RectTransform));
    }

    private static void Scale(AnimationClip clip, string path, float[] times, float[] values)
    {
        // 和 Unity 自己写出来的一致：缩放走 Transform(classID 4)，不是 RectTransform
        AddCurve(clip, path, "m_LocalScale.x", times, values, typeof(Transform));
        AddCurve(clip, path, "m_LocalScale.y", times, values, typeof(Transform));
    }

    private static void AddCurve(AnimationClip clip, string path, string property, float[] times, float[] values, System.Type type)
    {
        Keyframe[] keys = new Keyframe[times.Length];
        for (int i = 0; i < times.Length; i++)
        {
            // 切线全 0 ⇒ 每个关键帧处速度为零，呈现「缓入缓出」的呼吸感（与每日首充 clip 的 tangentMode 一致）
            keys[i] = new Keyframe(times[i], values[i], 0f, 0f);
        }

        AnimationCurve curve = new AnimationCurve(keys);
        EditorCurveBinding binding = EditorCurveBinding.FloatCurve(path, type, property);
        AnimationUtility.SetEditorCurve(clip, binding, curve);
    }

    private static AnimatorController BuildController(AnimationClip startClip, AnimationClip normalClip)
    {
        AssetDatabase.DeleteAsset(ControllerPath);

        AnimatorController controller = AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);
        AnimatorStateMachine stateMachine = controller.layers[0].stateMachine;

        AnimatorState startState = controller.AddMotion(startClip);
        startState.name = "start";
        startState.writeDefaultValues = true;

        AnimatorState normalState = controller.AddMotion(normalClip);
        normalState.name = "normal";
        normalState.writeDefaultValues = true;

        stateMachine.defaultState = startState;

        // start 播完自动进 normal 循环；0.9 秒处开始 0.1 秒混合（start 尾部与 normal 首帧同值，混合无感）
        AnimatorStateTransition transition = startState.AddTransition(normalState);
        transition.hasExitTime = true;
        transition.exitTime = 0.9f;
        transition.duration = 0.1f;
        transition.hasFixedDuration = true;

        return controller;
    }

    private static void AttachToPrefab(AnimatorController controller)
    {
        GameObject contents = PrefabUtility.LoadPrefabContents(PrefabPath);
        try
        {
            // Animator 和旧版 Animation 不能共存在同一个 GameObject 上，先摘掉旧的
            Animation legacy = contents.GetComponent<Animation>();
            if (legacy != null)
            {
                UnityEngine.Object.DestroyImmediate(legacy, true);
            }

            Animator animator = contents.GetComponent<Animator>();
            if (animator == null)
            {
                animator = contents.AddComponent<Animator>();
            }

            animator.runtimeAnimatorController = controller;
            animator.applyRootMotion = false;
            animator.cullingMode = AnimatorCullingMode.AlwaysAnimate;

            PrefabUtility.SaveAsPrefabAsset(contents, PrefabPath);
        }
        finally
        {
            PrefabUtility.UnloadPrefabContents(contents);
        }
    }
}
