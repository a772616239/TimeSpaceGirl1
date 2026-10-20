// UI 面板「弹入 + 循环浮动」动画生成器（模板）
//
// 用法：
//   1) 复制到 Assets/Editor/XxxFloatAnimBuilder.cs，把类名改成 XxxFloatAnimBuilder（必须和文件名一致）
//   2) 只改下面「配置区」：PrefabPath / MenuRoot / AssetDir / BaseName / Nodes
//   3) 菜单点一下，Unity 会自己生成 clip + controller 并把根节点的 Animation 换成 Animator
//
// 为什么用编辑器脚本生成而不是手写 .anim：
//   AnimationClip 里的 m_ClipBindingConstant 存的是层级路径的哈希，手改 path 不改哈希就静默不播。
//   让 Unity 自己写，保证绑定正确。
//
// 动画结构（与每日首充 UI_effect_DailyRechargePanel 一致）：
//   start  1.0s  一次性弹入，0.9s 处 0.1s 混合
//   normal 3.0s  循环呼吸（m_LoopTime = 1）
//
// 三条硬约束（违反会"写了但没效果"）：
//   * 布局组（HorizontalLayoutGroup 等）的子节点：位置每帧被重算，只能写 scale → animPos = false
//   * 自带 Animator 的节点（CommonButton 按钮）：它每帧写自身 m_LocalScale，父级写入被子级覆盖
//     → animScale = false，只写位置
//   * 有 PlayFlyAnim(DOTween) 在写位置的节点：Animator 再写同一属性会互相抢 → animPos = false

using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

public static class UIPanelFloatAnimBuilder
{
    // ==================== 配置区：换面板只改这一段 ====================

    private const string MenuRoot = "Tools/UI/首充面板";
    private const string PrefabPath = "Assets/ManagedResources/Prefabs/UI/FirstRecharge/FirstRechargePanel.prefab";
    private const string AssetDir = "Assets/Art/UIAni";
    private const string BaseName = "cn2-X1_UI_FirstRechargePanel_float";

    /// <summary>normal 一个循环的长度（秒）。1.5s 太急，3s 比较像呼吸。</summary>
    private const float NormalLoopTime = 3f;

    /// <summary>start 里"从下方落位"的距离（像素）。</summary>
    private const float StartDropY = 18f;

    /// <summary>start 的峰值宽度（秒）：delay → +PopUp → 峰值 → +PopDown → 1。整段约 1.0s。</summary>
    private const float PopUp = 0.12f;
    private const float PopDown = 0.10f;

    private struct NodeCfg
    {
        public string path;        // 相对面板根节点的层级路径（大小写敏感）
        public float baseY;        // anchoredPosition.y 基准值，必须和 prefab 一致
        public float breath;       // normal 缩放峰值（1 = 不呼吸）
        public float floatY;       // normal 位移峰值（负数 = 往下沉）
        public float startFrom;    // start 起始缩放（0 = 从无到有，1 = 原地顶一下）
        public float startPeak;    // start 峰值缩放
        public float startDelay;   // 这个节点在 start 里的起始时间（错开相位）
        public bool animPos;       // 是否允许写 anchoredPosition.y
        public bool animScale;     // 是否允许写 m_LocalScale
        public bool pulse;         // normal 里一个循环两次脉冲（按钮用）
    }

    private static NodeCfg N(string path, float baseY,
        float breath = 1f, float floatY = 0f,
        float startFrom = 1f, float startPeak = 1f, float startDelay = 0f,
        bool animPos = true, bool animScale = true, bool pulse = false)
    {
        NodeCfg n = new NodeCfg();
        n.path = path;
        n.baseY = baseY;
        n.breath = breath;
        n.floatY = floatY;
        n.startFrom = startFrom;
        n.startPeak = startPeak;
        n.startDelay = startDelay;
        n.animPos = animPos;
        n.animScale = animScale;
        n.pulse = pulse;
        return n;
    }

    // 样例 = 首充面板。换成新面板时整块替换。
    private static readonly NodeCfg[] Nodes =
    {
        // 根容器：只做缩放弹跳，位置归 PlayFlyAnim(DOTween) 管
        N("frame",              0f,       1f,     0f,   1f,   1.2f,  0f,   false, true),
        N("hero",               0f,       1f,     0f,   1f,   1.3f,  0f,   false, true),

        // 标题条：往上飘（与内容区反相）
        N("frame/tabsContent",  156.64f,  1f,     5f,   0.85f, 1.06f, 0.30f),

        // 内容区：往下沉 + 轻微呼吸
        N("frame/rewardBg",    -226.18f,  1.015f, -10f, 0f,   1.05f, 0.40f),

        // 内容区里被布局组摆好的卡片：只能缩放，不能写位置
        N("frame/rewardBg/rewardDay1", 0f, 1f, 0f, 0f, 1.12f, 0.50f, false, true),
        N("frame/rewardBg/rewardDay2", 0f, 1f, 0f, 0f, 1.12f, 0.58f, false, true),
        N("frame/rewardBg/rewardDay3", 0f, 1f, 0f, 0f, 1.12f, 0.66f, false, true),

        // 按钮：自带 CommonButton（每帧写自身缩放）⇒ 只写位置，缩放交给它自己
        N("frame/rechargeBtn",  -600f,    1f,     0f,   1f,   1f,    0.72f, true, false, true),

        // 底部提示
        N("frame/tips",         -462f,    1f,    -3f,   1f,   1f,    0.78f),
    };

    // ==================== 配置区结束 ====================

    private static string ControllerPath { get { return AssetDir + "/" + BaseName + ".controller"; } }
    private static string StartClipPath { get { return AssetDir + "/" + BaseName + "_start.anim"; } }
    private static string NormalClipPath { get { return AssetDir + "/" + BaseName + "_normal.anim"; } }

    [MenuItem("Tools/UI/首充面板/生成并挂载浮动动画")]
    public static void Build()
    {
        if (AssetDatabase.LoadAssetAtPath<GameObject>(PrefabPath) == null)
        {
            Debug.LogError("[FloatAnim] 找不到 prefab：" + PrefabPath);
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
        Debug.Log("[FloatAnim] 完成：" + BaseName + " → " + PrefabPath);
        Debug.Log("[FloatAnim] 状态机 start(" + startClip.length.ToString("0.00") + "s, loop=" + IsLooping(startClip) +
                  ") → normal(" + normalClip.length.ToString("0.00") + "s, loop=" + IsLooping(normalClip) + ")");
    }

    /// <summary>供 -executeMethod 调用（编辑器开着时不能用）。</summary>
    public static void BuildFromCommandLine()
    {
        Build();
    }

    [MenuItem("Tools/UI/首充面板/还原为旧版 Animation")]
    public static void RestoreLegacyAnimation()
    {
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
            animation.playAutomatically = true;

            PrefabUtility.SaveAsPrefabAsset(contents, PrefabPath);
        }
        finally
        {
            PrefabUtility.UnloadPrefabContents(contents);
        }

        AssetDatabase.SaveAssets();
        Debug.Log("[FloatAnim] 已移除 Animator，恢复 legacy Animation 组件");
    }

    private static void BuildStartClip(AnimationClip clip)
    {
        for (int i = 0; i < Nodes.Length; i++)
        {
            NodeCfg n = Nodes[i];
            float d = n.startDelay;

            if (n.animScale && !(Mathf.Approximately(n.startFrom, 1f) && Mathf.Approximately(n.startPeak, 1f)))
            {
                Scale(clip, n.path,
                    new[] { d, d + PopUp, d + PopUp + PopDown },
                    new[] { n.startFrom, n.startPeak, 1f });
            }

            if (n.animPos && Mathf.Abs(n.floatY) > 0.001f)
            {
                Float(clip, n.path, "m_AnchoredPosition.y",
                    new[] { d, d + PopUp + PopDown },
                    new[] { n.baseY - StartDropY, n.baseY });
            }
        }
    }

    private static void BuildNormalClip(AnimationClip clip)
    {
        float t0 = 0f;
        float t1 = NormalLoopTime * 0.5f;
        float t2 = NormalLoopTime;

        for (int i = 0; i < Nodes.Length; i++)
        {
            NodeCfg n = Nodes[i];

            if (n.animScale && !Mathf.Approximately(n.breath, 1f))
            {
                Scale(clip, n.path, new[] { t0, t1, t2 }, new[] { 1f, n.breath, 1f });
            }

            if (!n.animPos || Mathf.Abs(n.floatY) < 0.001f)
            {
                continue;
            }

            if (n.pulse)
            {
                // 一个循环两次脉冲：0 → 1/4 → 1/2 → 3/4 → 1
                float[] times = { t0, NormalLoopTime * 0.2444f, t1, NormalLoopTime * 0.7778f, t2 };
                float[] values = { n.baseY, n.baseY + n.floatY, n.baseY, n.baseY + n.floatY, n.baseY };
                Float(clip, n.path, "m_AnchoredPosition.y", times, values);
            }
            else
            {
                // 首尾同值，循环处不跳
                Float(clip, n.path, "m_AnchoredPosition.y", new[] { t0, t1, t2 }, new[] { n.baseY, n.baseY + n.floatY, n.baseY });
            }
        }
    }

    // ---------------------------------------------------------------- 工具

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

        // 循环标志存在 m_AnimationClipSettings.m_LoopTime，用 SerializedObject 改最稳
        // （AnimationUtility.Get/SetAnimationClipSettings 的类型名跨版本有变动风险）
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

    private static void Float(AnimationClip clip, string path, string property, float[] times, float[] values)
    {
        AddCurve(clip, path, property, times, values, typeof(RectTransform));
    }

    private static void Scale(AnimationClip clip, string path, float[] times, float[] values)
    {
        // 与 Unity 自己写出的一致：缩放绑 Transform(classID 4)，不是 RectTransform
        AddCurve(clip, path, "m_LocalScale.x", times, values, typeof(Transform));
        AddCurve(clip, path, "m_LocalScale.y", times, values, typeof(Transform));
    }

    private static void AddCurve(AnimationClip clip, string path, string property, float[] times, float[] values, System.Type type)
    {
        Keyframe[] keys = new Keyframe[times.Length];
        for (int i = 0; i < times.Length; i++)
        {
            // 切线全 0 ⇒ 每个关键帧处速度为零，缓入缓出，就是"呼吸"的手感
            keys[i] = new Keyframe(times[i], values[i], 0f, 0f);
        }

        AnimationCurve curve = new AnimationCurve(keys);
        AnimationUtility.SetEditorCurve(clip, EditorCurveBinding.FloatCurve(path, type, property), curve);
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

        // start 播到 0.9s 开始 0.1s 混合进 normal；start 尾部与 normal 首帧同值，混合无感
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
            // Animator 和 legacy Animation 不能共存，先摘掉旧的
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
