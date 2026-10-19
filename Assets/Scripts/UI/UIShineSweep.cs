using UnityEngine;
using UnityEngine.UI;

namespace GameLogic
{
    /// <summary>
    /// UI 图标「闪光划过」循环效果。
    ///
    /// 用法：挂在任意一个带 <see cref="Image"/> 的图标节点上（例如挂机面板里的那颗钻石），
    /// 运行时组件会自己搭出这套结构：
    ///
    /// <code>
    /// 目标图标 (Image)
    /// └── ShineClip   Image=程序生成的菱形贴图 + Mask(showMaskGraphic=false)
    ///     └── Shine   Image=程序生成的斜向柔边光带
    /// </code>
    ///
    /// 为什么不直接把 Mask 挂在图标自己身上：这张「战利品」钻的贴图外面烤了一圈灰色
    /// 投影，Mask 是按贴图 alpha 写 stencil 的，阴影那圈 alpha 不为 0 ⇒ 光带扫过去会
    /// 把灰投影一起点亮，看起来像糊了一团脏雾。所以单独用一个菱形（和宝石轮廓一致）
    /// 做裁剪，干净且和贴图内容完全解耦。
    ///
    /// 贴图全部在运行时生成（见 <see cref="CreateStreakSprite"/> / <see cref="CreateRhombusSprite"/>），
    /// 不需要美术出图、不进图集、不用改 shader 打包设置，也不会多一个材质变体。
    /// 计时用 unscaledDeltaTime，战斗/暂停都不会把它卡住。
    /// </summary>
    [DisallowMultipleComponent]
    [RequireComponent(typeof(RectTransform))]
    [RequireComponent(typeof(Image))]
    public class UIShineSweep : MonoBehaviour
    {
        // ---------------- 节奏 ----------------

        [Header("节奏")]
        [Tooltip("一次光带划过所需时间（秒）")]
        [SerializeField] private float sweepDuration = 0.62f;

        [Tooltip("两次划过之间的空闲时间（秒）")]
        [SerializeField] private float interval = 2.2f;

        [Tooltip("出现后第一次划过的延迟（秒），避免和面板打开动画撞在一起")]
        [SerializeField] private float delay = 0.45f;

        // ---------------- 外观 ----------------

        [Header("外观")]
        [Tooltip("光带相对垂直方向的倾角（度）")]
        [SerializeField] private float angle = 40f;

        [Tooltip("光带宽度系数：光带矩形宽 = 图标高 * 该值，值越大光带越宽越柔")]
        [SerializeField] private float widthFactor = 0.30f;

        [Tooltip("光带长度系数：光带矩形长 = 图标高 * 该值，需大到能斜着盖住整颗宝石")]
        [SerializeField] private float lengthFactor = 3.2f;

        [Tooltip("高光颜色")]
        [SerializeField] private Color color = Color.white;

        [Range(0f, 1f)]
        [Tooltip("高光峰值不透明度")]
        [SerializeField] private float maxAlpha = 0.92f;

        // ---------------- 裁剪 ----------------

        [Header("裁剪")]
        [Tooltip("菱形裁剪框宽度系数（相对图标宽），要和宝石的实际轮廓对齐")]
        [SerializeField] private float maskWidthFactor = 0.68f;

        [Tooltip("菱形裁剪框高度系数（相对图标高），要和宝石的实际轮廓对齐")]
        [SerializeField] private float maskHeightFactor = 0.72f;

        // ---------------- 运行时 ----------------

        private RectTransform m_RectTransform;
        private RectTransform m_Clip;
        private RectTransform m_Shine;
        private Image m_ShineImage;

        private float m_Phase;
        private float m_FromX;
        private float m_ToX;

        private static Sprite s_StreakSprite;
        private static Sprite s_RhombusSprite;

        // ---------------- 程序生成的贴图 ----------------

        /// <summary>柔边斜向光带（全局共享一份）。</summary>
        public static Sprite StreakSprite
        {
            get
            {
                if (s_StreakSprite == null)
                    s_StreakSprite = CreateStreakSprite();
                return s_StreakSprite;
            }
        }

        /// <summary>实心菱形，用作 Mask 的裁剪形状（全局共享一份）。</summary>
        public static Sprite RhombusSprite
        {
            get
            {
                if (s_RhombusSprite == null)
                    s_RhombusSprite = CreateRhombusSprite();
                return s_RhombusSprite;
            }
        }

        /// <summary>
        /// 光带贴图：横向高斯衰减（中间亮、两边散开），纵向两端收口，
        /// 这样旋转之后不会出现上下硬边。
        /// </summary>
        private static Sprite CreateStreakSprite()
        {
            const int W = 64;
            const int H = 128;

            var tex = new Texture2D(W, H, TextureFormat.RGBA32, false);
            tex.name = "UIShineSweep_Streak";
            tex.wrapMode = TextureWrapMode.Clamp;
            tex.filterMode = FilterMode.Bilinear;

            var pixels = new Color32[W * H];
            for (int y = 0; y < H; y++)
            {
                float v = (y + 0.5f) / H;
                // 两端 30% 做淡出，避免光带两头被切成一条直线
                float taper = Mathf.InverseLerp(0f, 0.3f, v) * Mathf.InverseLerp(1f, 0.7f, v);
                taper = Mathf.SmoothStep(0f, 1f, taper);

                for (int x = 0; x < W; x++)
                {
                    float u = (x + 0.5f) / W;
                    float d = (u - 0.5f) * 2f;
                    float band = Mathf.Exp(-(d * d) / 0.05f);
                    float a = Mathf.Clamp01(band * taper);
                    pixels[y * W + x] = new Color32(255, 255, 255, (byte)(a * 255f + 0.5f));
                }
            }

            tex.SetPixels32(pixels);
            tex.Apply(false, true);

            var sprite = Sprite.Create(tex, new Rect(0f, 0f, W, H), new Vector2(0.5f, 0.5f), 100f, 0,
                SpriteMeshType.FullRect);
            sprite.name = "UIShineSweep_Streak";
            return sprite;
        }

        /// <summary>
        /// 菱形贴图：|dx| + |dy| &lt;= 1 的实心菱形，边缘留 1.5px 羽化抗锯齿。
        /// 钻石这种「上下左右四个尖角」的轮廓用菱形裁剪刚好贴合。
        /// </summary>
        private static Sprite CreateRhombusSprite()
        {
            const int S = 64;
            const float Feather = 1.6f / S;

            var tex = new Texture2D(S, S, TextureFormat.RGBA32, false);
            tex.name = "UIShineSweep_Rhombus";
            tex.wrapMode = TextureWrapMode.Clamp;
            tex.filterMode = FilterMode.Bilinear;

            var pixels = new Color32[S * S];
            for (int y = 0; y < S; y++)
            {
                float dy = Mathf.Abs(((y + 0.5f) / S) * 2f - 1f);
                for (int x = 0; x < S; x++)
                {
                    float dx = Mathf.Abs(((x + 0.5f) / S) * 2f - 1f);
                    float d = dx + dy;
                    float a = Mathf.Clamp01((1f - d) / Feather);
                    pixels[y * S + x] = new Color32(255, 255, 255, (byte)(a * 255f + 0.5f));
                }
            }

            tex.SetPixels32(pixels);
            tex.Apply(false, true);

            var sprite = Sprite.Create(tex, new Rect(0f, 0f, S, S), new Vector2(0.5f, 0.5f), 100f, 0,
                SpriteMeshType.FullRect);
            sprite.name = "UIShineSweep_Rhombus";
            return sprite;
        }

        // ---------------- 生命周期 ----------------

        private void Awake()
        {
            Build();
        }

        private void OnEnable()
        {
            if (m_Shine == null)
                return;

            m_Phase = -Mathf.Max(0f, delay);
            if (m_Shine.gameObject.activeSelf)
                m_Shine.gameObject.SetActive(false);
        }

        private void OnDestroy()
        {
            m_Clip = null;
            m_Shine = null;
            m_ShineImage = null;
        }

        private void Build()
        {
            m_RectTransform = transform as RectTransform;
            if (m_RectTransform == null || GetComponent<Image>() == null)
                return;

            // 幂等：重复 Build（例如改了参数或图标尺寸重建）先把上一套节点清掉
            var old = transform.Find("ShineClip");
            if (old != null)
            {
                old.gameObject.SetActive(false);
                if (Application.isPlaying)
                    Destroy(old.gameObject);
                else
                    DestroyImmediate(old.gameObject);
            }

            // --- 裁剪层 ---
            var clipGo = new GameObject("ShineClip", typeof(RectTransform), typeof(CanvasRenderer), typeof(Image),
                typeof(Mask));
            clipGo.layer = gameObject.layer;
            m_Clip = clipGo.GetComponent<RectTransform>();
            m_Clip.SetParent(transform, false);
            m_Clip.anchorMin = new Vector2(0.5f, 0.5f);
            m_Clip.anchorMax = new Vector2(0.5f, 0.5f);
            m_Clip.pivot = new Vector2(0.5f, 0.5f);
            m_Clip.localRotation = Quaternion.identity;
            m_Clip.localScale = Vector3.one;

            var clipImage = clipGo.GetComponent<Image>();
            clipImage.sprite = RhombusSprite;
            clipImage.type = Image.Type.Simple;
            clipImage.raycastTarget = false;

            var mask = clipGo.GetComponent<Mask>();
            mask.showMaskGraphic = false; // 只往 stencil 里写形状，自己不画

            // --- 光带层 ---
            var shineGo = new GameObject("Shine", typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
            shineGo.layer = gameObject.layer;
            m_Shine = shineGo.GetComponent<RectTransform>();
            m_Shine.SetParent(m_Clip, false);
            m_Shine.anchorMin = new Vector2(0.5f, 0.5f);
            m_Shine.anchorMax = new Vector2(0.5f, 0.5f);
            m_Shine.pivot = new Vector2(0.5f, 0.5f);
            m_Shine.localRotation = Quaternion.Euler(0f, 0f, angle);
            m_Shine.localScale = Vector3.one;

            m_ShineImage = shineGo.GetComponent<Image>();
            m_ShineImage.sprite = StreakSprite;
            m_ShineImage.type = Image.Type.Simple;
            m_ShineImage.raycastTarget = false;
            m_ShineImage.maskable = true;
            m_ShineImage.color = new Color(color.r, color.g, color.b, 0f);

            ApplyLayout();
            shineGo.SetActive(false);
        }

        /// <summary>按图标当前尺寸重算裁剪框、光带大小和扫过范围。</summary>
        private void ApplyLayout()
        {
            if (m_RectTransform == null || m_Clip == null || m_Shine == null)
                return;

            var size = m_RectTransform.rect.size;
            if (size.x <= 0f || size.y <= 0f)
                return;

            var clipSize = new Vector2(size.x * maskWidthFactor, size.y * maskHeightFactor);
            m_Clip.sizeDelta = clipSize;

            float bandWidth = size.y * widthFactor;
            float bandLength = size.y * lengthFactor;
            m_Shine.sizeDelta = new Vector2(bandWidth, bandLength);

            // 斜着的光带按裁剪框对角线算跨度，再加自身半宽，保证完全走出宝石再收尾
            float halfSpan = clipSize.magnitude * 0.5f;
            float travel = halfSpan + bandWidth * 0.5f;
            m_FromX = -travel;
            m_ToX = travel;
        }

        // 图标被布局改尺寸（不同分辨率 / 被 Adapter 重新排版）时同步重算
        private void OnRectTransformDimensionsChange()
        {
            if (m_Clip != null && m_Shine != null)
                ApplyLayout();
        }

        private void Update()
        {
            if (m_Shine == null)
                return;

            float cycle = Mathf.Max(0.05f, sweepDuration) + Mathf.Max(0f, interval);
            m_Phase += Time.unscaledDeltaTime;
            if (m_Phase >= cycle)
                m_Phase %= cycle; // 长挂机时别让浮点精度被时间累积吃掉

            if (m_Phase < 0f)
            {
                SetShineVisible(false);
                return;
            }

            float p = m_Phase % cycle;
            if (p > sweepDuration)
            {
                SetShineVisible(false);
                return;
            }

            Evaluate(p / sweepDuration);
        }

        /// <summary>
        /// 按 0~1 的进度摆放光带（0 = 完全在左侧外面，1 = 完全在右侧外面）。
        /// 单独抽出来，便于在编辑器里逐帧预览/截图验收，不依赖 Update 的节奏。
        /// </summary>
        public void Evaluate(float progress01)
        {
            if (m_Shine == null || m_ShineImage == null)
                return;

            float k = Mathf.Clamp01(progress01);
            float eased = k * k * (3f - 2f * k); // smoothstep：两头慢、中间快

            var pos = m_Shine.anchoredPosition;
            pos.x = Mathf.Lerp(m_FromX, m_ToX, eased);
            m_Shine.anchoredPosition = pos;

            // 起手淡入、收尾淡出，光带不会在边界突兀地出现/消失
            float fade = Mathf.Min(Mathf.InverseLerp(0f, 0.16f, k), Mathf.InverseLerp(1f, 0.76f, k));
            m_ShineImage.color = new Color(color.r, color.g, color.b, maxAlpha * fade);

            SetShineVisible(true);
        }

        private void SetShineVisible(bool visible)
        {
            if (m_Shine != null && m_Shine.gameObject.activeSelf != visible)
                m_Shine.gameObject.SetActive(visible);
        }
    }
}
