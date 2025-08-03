using UnityEngine;
using System;
using System.Collections.Generic;
using LuaInterface;
using UnityEditor;
using BindType = ToLuaMenu.BindType;
using System.Reflection;
//using UnityEngine.PostProcessing;
using Colorful;
using GameCore;
using GameLogic;
using ResUpdate;
using Spine.Unity;
using UnityEngine.UI;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnrealM;
using UnityEngine.Video;
using UnityEngine.Rendering;

public static class CustomSettings
{
    public static string saveDir = Application.dataPath + "/Source/Generate/";    
    public static string toluaBaseType = Application.dataPath + "/ToLua/BaseType/";
    public static string baseLuaDir = Application.dataPath + "/Tolua/Lua/";
    public static string injectionFilesPath = Application.dataPath + "/ToLua/Injection/";

    //导出时强制做为静态类的类型(注意customTypeList 还要添加这个类型才能导出)
    //unity 有些类作为sealed class, 其实完全等价于静态类
    public static List<Type> staticClassTypes = new List<Type>
    {        
        typeof(UnityEngine.Application),
        typeof(UnityEngine.Time),
        typeof(UnityEngine.Screen),
        typeof(UnityEngine.SleepTimeout),
        typeof(UnityEngine.Input),
        typeof(UnityEngine.Resources),
        typeof(UnityEngine.Physics),
        typeof(UnityEngine.RenderSettings),
        typeof(UnityEngine.QualitySettings),
        typeof(UnityEngine.GL),
        typeof(iPhoneUtils),
        typeof(UnityEngine.SceneManagement.SceneManager),
        typeof(UnityEngine.Caching),
        typeof(UnityEngine.Graphics),
        //typeof(cn.sharesdk.unity3d.ShareSDK),
    };

    //附加导出委托类型(在导出委托时, customTypeList 中牵扯的委托类型都会导出， 无需写在这里)
    public static DelegateType[] customDelegateList = 
    {       
        _DT(typeof(Action)),  
        _DT(typeof(Action<ByteBuffer>)),
        _DT(typeof(DG.Tweening.TweenCallback)),
        _DT(typeof(UnityEngine.Events.UnityAction)),
        _DT(typeof(UnityEngine.Events.UnityAction<int>)),
        _DT(typeof(UnityEngine.Events.UnityAction<string>)),
        _DT(typeof(UnityEngine.Events.UnityAction<float>)),
        _DT(typeof(UnityEngine.Events.UnityAction<bool>)),
        _DT(typeof(UnityEngine.Events.UnityAction<Vector2>)),
        _DT(typeof(UnityActionInt)),
        _DT(typeof(UnityActionFloat)),
        _DT(typeof(UnityActionString)),
        _DT(typeof(UnityActionBool)),
        _DT(typeof(ColliderEventDelegate)),
        _DT(typeof(PointerEventDelegate)),
        _DT(typeof(BaseEventDelegate)),
        _DT(typeof(AxisEventDelegate)),
        _DT(typeof(System.Predicate<int>)),
        _DT(typeof(System.Action<int>)),
        _DT(typeof(System.Comparison<int>)),
        _DT(typeof(GameEventHandler)),
		_DT(typeof(System.Func<int, int>))
    };

    //在这里添加你要导出注册到lua的类型列表
    public static BindType[] customTypeList =
    {                
        //------------------------为例子导出--------------------------------
        //_GT(typeof(TestEventListener)),
        //_GT(typeof(TestProtol)),
        //_GT(typeof(TestAccount)),
        //_GT(typeof(Dictionary<int, TestAccount>)).SetLibName("AccountMap"),
        //_GT(typeof(KeyValuePair<int, TestAccount>)),
        //_GT(typeof(Dictionary<int, TestAccount>.KeyCollection)),
        //_GT(typeof(Dictionary<int, TestAccount>.ValueCollection)),
        //_GT(typeof(TestExport)),
        //_GT(typeof(TestExport.Space)),
        //-------------------------------------------------------------------        
        _GT(typeof(GameCore.FileToCRC32)),
        _GT(typeof(LuaInjectionStation)),
        _GT(typeof(InjectType)),
        _GT(typeof(Debugger)).SetNameSpace(null),

//#if USING_DOTWEENING
        _GT(typeof(DG.Tweening.DOTween)),
        _GT(typeof(DG.Tweening.Tween)).SetBaseType(typeof(System.Object)).AddExtendType(typeof(DG.Tweening.TweenExtensions)),
        _GT(typeof(DG.Tweening.Sequence)).AddExtendType(typeof(DG.Tweening.TweenSettingsExtensions)),
        _GT(typeof(DG.Tweening.Tweener)).AddExtendType(typeof(DG.Tweening.TweenSettingsExtensions)),
        _GT(typeof(DG.Tweening.LoopType)),
        _GT(typeof(DG.Tweening.PathMode)),
        _GT(typeof(DG.Tweening.PathType)),
        _GT(typeof(DG.Tweening.RotateMode)),
        _GT(typeof(DG.Tweening.Ease)),
        _GT(typeof(DG.Tweening.Core.TweenerCore<UnityEngine.Vector2,UnityEngine.Vector2,DG.Tweening.Plugins.Options.VectorOptions>)),
        _GT(typeof(DG.Tweening.Core.TweenerCore<float,float,DG.Tweening.Plugins.Options.FloatOptions>)),
        _GT(typeof(DG.Tweening.Core.TweenerCore<UnityEngine.Vector3,UnityEngine.Vector3,DG.Tweening.Plugins.Options.VectorOptions>)),
        _GT(typeof(UnityEngine.UI.EmptyRaycast)),
        _GT(typeof(DG.Tweening.Core.TweenerCore<UnityEngine.Vector3,UnityEngine.Vector3[],DG.Tweening.Plugins.Options.Vector3ArrayOptions>)),
        _GT(typeof(DG.Tweening.Core.TweenerCore<UnityEngine.Color,UnityEngine.Color,DG.Tweening.Plugins.Options.ColorOptions>)),
        _GT(typeof(Component)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(Transform)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(Light)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(Material)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(Rigidbody)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(Camera)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        _GT(typeof(AudioSource)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        //_GT(typeof(LineRenderer)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),
        //_GT(typeof(TrailRenderer)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions)),    
//#else
                                         
        //_GT(typeof(Component)),
        //_GT(typeof(Transform)),
        //_GT(typeof(Material)),
        //_GT(typeof(Light)),
        //_GT(typeof(Rigidbody)),
        //_GT(typeof(Camera)),
        //_GT(typeof(AudioSource)),
        //_GT(typeof(LineRenderer))
        //_GT(typeof(TrailRenderer))
//#endif
        _GT(typeof(PlayerPrefs)),
        _GT(typeof(Behaviour)),
        _GT(typeof(MonoBehaviour)),
        //_GT(typeof(GameObject)),
        _GT(typeof(GameObject)).AddExtendType(typeof(GlobalExtension)),
        _GT(typeof(TrackedReference)),
        _GT(typeof(Application)),
        _GT(typeof(Physics)),
        _GT(typeof(Collider)),
        _GT(typeof(Time)),
        _GT(typeof(Texture)),
        _GT(typeof(Texture2D)),
        _GT(typeof(Shader)),
        _GT(typeof(Renderer)),
        _GT(typeof(WWW)),
        _GT(typeof(Screen)),
        _GT(typeof(CameraClearFlags)),
        _GT(typeof(AudioClip)),        
        _GT(typeof(AssetBundle)),
        _GT(typeof(ParticleSystem)),
        _GT(typeof(AsyncOperation)).SetBaseType(typeof(System.Object)),
        _GT(typeof(LightType)),
        _GT(typeof(SleepTimeout)),
        _GT(typeof(PointerEventData)),
        _GT(typeof(ShadowProjector)),
        _GT(typeof(Projector)),
        _GT(typeof(RenderTextureFormat)),
        _GT(typeof(FilterMode)),
        _GT(typeof(SystemInfo)),
        _GT(typeof(SortingGroup)),
#if UNITY_5_3_OR_NEWER && !UNITY_5_6_OR_NEWER
        _GT(typeof(UnityEngine.Experimental.Director.DirectorPlayer)),
#endif
        _GT(typeof(Animator)),
        _GT(typeof(AnimatorStateInfo)),
        _GT(typeof(Input)),
        _GT(typeof(KeyCode)),
        _GT(typeof(SkinnedMeshRenderer)),
        _GT(typeof(Space)),


        _GT(typeof(MeshRenderer)),
#if !UNITY_5_4_OR_NEWER
        _GT(typeof(ParticleEmitter)),
        _GT(typeof(ParticleRenderer)),
        _GT(typeof(ParticleAnimator)), 
#endif

        _GT(typeof(BoxCollider)),
        _GT(typeof(MeshCollider)),
        _GT(typeof(SphereCollider)),
        _GT(typeof(CharacterController)),
        _GT(typeof(CapsuleCollider)),

        _GT(typeof(Animation)),
        _GT(typeof(AnimationClip)).SetBaseType(typeof(UnityEngine.Object)),
        _GT(typeof(AnimationState)),
        _GT(typeof(AnimationBlendMode)),
        _GT(typeof(QueueMode)),
        _GT(typeof(PlayMode)),
        _GT(typeof(WrapMode)),

        _GT(typeof(QualitySettings)),
        _GT(typeof(RenderSettings)),
        _GT(typeof(SkinWeights)),
        _GT(typeof(RenderTexture)),
        _GT(typeof(Resources)),
        _GT(typeof(LuaProfiler)),


        _GT(typeof(Canvas)),
        // _GT(typeof(MaskableGraphic)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions46)),
        // _GT(typeof(RectTransform)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions46)),
        // _GT(typeof(Text)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions46)),
        _GT(typeof(Sprite)),
        _GT(typeof(Outline)),
        // _GT(typeof(SpriteRenderer)).AddExtendType(typeof(DG.Tweening.ShortcutExtensions43)),
        _GT(typeof(Image)),
        _GT(typeof(RawImage)),
        _GT(typeof(Rect)),
        _GT(typeof(InputField)),
        _GT(typeof(Dropdown)),
        _GT(typeof(Toggle)),
        _GT(typeof(Selectable)).AddExtendType(typeof(GlobalExtension)),
        _GT(typeof(Button)),
        _GT(typeof(TextHelper)),
        _GT(typeof(Gradient)),
        _GT(typeof(ImageHelper)),
        _GT(typeof(Slider)),
        _GT(typeof(Scrollbar)),
        _GT(typeof(GridLayoutGroup)),
        _GT(typeof(HorizontalLayoutGroup)),
        _GT(typeof(VerticalLayoutGroup)),
        _GT(typeof(LayoutElement)),
        _GT(typeof(ContentSizeFitter)),
        _GT(typeof(AnimationCurve)),
        _GT(typeof(AnimationCurveContainer)),        

        _GT(typeof(App)),
        _GT(typeof(Util)),
        //_GT(typeof(LuaGOUtil)),
        _GT(typeof(AppConst)),
        _GT(typeof(LuaHelper)),
        _GT(typeof(LuaLoader)),
        _GT(typeof(ByteBuffer)),
        _GT(typeof(LuaBehaviour)),
        _GT(typeof(GameManager)),
        _GT(typeof(LuaManager)),
        //_GT(typeof(SoundManager)),
       _GT(typeof(NetworkManager)),
       _GT(typeof(SocketClient)),
       _GT(typeof(ResourcesManager)),	
       _GT(typeof(IAPManager)),
       _GT(typeof(SuperTextMesh)),
       _GT(typeof(IAPResult)),	
       _GT(typeof(ReviewMgr)),	
       _GT(typeof(GoogleSignMgr)),
       _GT(typeof(LoginData)),
       _GT(typeof(PurchasedInfo)),	
	   _GT(typeof(SceneController)),
       _GT(typeof(SpeakManager)),
       _GT(typeof(LayoutRebuilder)),
       _GT(typeof(SDK.SDKManager)),
       _GT(typeof(SDK.SDKPayArgs)),
       _GT(typeof(SDK.SDKSubmitExtraDataArgs)),
       _GT(typeof(AndroidDeviceInfo)),
       _GT(typeof(NotchScreenUtil)),
       _GT(typeof(DownLoadProgress)),
       _GT(typeof(ResUpdateProgress)),
       _GT(typeof(UIDepthAdapter)),
       _GT(typeof(UITweenSpring)),
       _GT(typeof(PlayFlyAnim)),
       _GT(typeof(RadarChart)),
       _GT(typeof(RoleProperty)),
       _GT(typeof(ResourcesUpdateState)),
       _GT(typeof(ImageDownloadManager)),
       _GT(typeof(VersionManager)),
       _GT(typeof(ConfigManager)),
       _GT(typeof(UpdateManager)),
       _GT(typeof(SetInternetPic)),
       _GT(typeof(SkeletonGraphic)),
       _GT(typeof(Spine.Skeleton)),
       _GT(typeof(SkeletonAnimation)),
       _GT(typeof(Spine.AnimationState)),
       _GT(typeof(PhoneManager)),
       _GT(typeof(EventTriggerListener)),
       _GT(typeof(UnityEvent)),
       _GT(typeof(Button.ButtonClickedEvent)),
       _GT(typeof(Toggle.ToggleEvent)),
       _GT(typeof(Slider.SliderEvent)),
       _GT(typeof(Scrollbar.ScrollEvent)),
       _GT(typeof(InputField.SubmitEvent)),
       _GT(typeof(InputField.OnChangeEvent)),
       _GT(typeof(ScrollRect.ScrollRectEvent)),
       _GT(typeof(Dropdown.DropdownEvent)),
       _GT(typeof(LuaFileUtils)),
       _GT(typeof(RectTransformUtility)),
       _GT(typeof(LayoutUtility)),
       _GT(typeof(ShadowUtils)),
       _GT(typeof(ConvertUtil)),
       _GT(typeof(GlobalEvent)),
       _GT(typeof(UVChainLightning)),
       _GT(typeof(ObjectPoolManager)),
       _GT(typeof(GameObjectPool)),
       //_GT(typeof(WaterWaveEffect)),
       _GT(typeof(SimplePool)),
       _GT(typeof(ImageAnimation)),
       _GT(typeof(SpriteAnimation)),
       _GT(typeof(AniEvent)),
       _GT(typeof(Dropdown.OptionData)),
#region PostProcessing
       //_GT(typeof(PostProcessingBehaviour)),
       //_GT(typeof(PostProcessingProfile)),
       //_GT(typeof(FogModel)),
       // _GT(typeof(FogModel.Settings)),
       //_GT(typeof(AntialiasingModel)),
       //_GT(typeof(AntialiasingModel.FxaaConsoleSettings)),
       //_GT(typeof(AntialiasingModel.FxaaPreset)),
       //_GT(typeof(AntialiasingModel.FxaaQualitySettings)),
       //_GT(typeof(AntialiasingModel.FxaaSettings)),
       //_GT(typeof(AntialiasingModel.Method)),
       //_GT(typeof(AntialiasingModel.Settings)),
       //_GT(typeof(AntialiasingModel.TaaSettings)),

       //_GT(typeof(AmbientOcclusionModel)),
       //_GT(typeof(AmbientOcclusionModel.SampleCount)),
       //_GT(typeof(AmbientOcclusionModel.Settings)),

       //_GT(typeof(ScreenSpaceReflectionModel)),
       //_GT(typeof(ScreenSpaceReflectionModel.IntensitySettings)),
       //_GT(typeof(ScreenSpaceReflectionModel.ReflectionSettings)),
       //_GT(typeof(ScreenSpaceReflectionModel.ScreenEdgeMask)),
       //_GT(typeof(ScreenSpaceReflectionModel.Settings)),
       //_GT(typeof(DepthOfFieldModel)),
       //_GT(typeof(DepthOfFieldModel.KernelSize)),
       //_GT(typeof(DepthOfFieldModel.Settings)),
       //_GT(typeof(MotionBlurModel)),
       //_GT(typeof(MotionBlurModel.Settings)),
       //_GT(typeof(EyeAdaptationModel)),
       //_GT(typeof(EyeAdaptationModel.EyeAdaptationType)),
       //_GT(typeof(EyeAdaptationModel.Settings)),
       //_GT(typeof(BloomModel)),
       //_GT(typeof(BloomModel.BloomSettings)),
       //_GT(typeof(BloomModel.LensDirtSettings)),
       //_GT(typeof(BloomModel.Settings)),
       //_GT(typeof(ColorGradingModel)),
       //_GT(typeof(ColorGradingModel.ChannelMixerSettings)),
       //_GT(typeof(ColorGradingModel.BasicSettings)),
       //_GT(typeof(ColorGradingModel.ColorWheelMode)),
       //_GT(typeof(ColorGradingModel.ColorWheelsSettings)),
       //_GT(typeof(ColorGradingModel.CurvesSettings)),
       //_GT(typeof(ColorGradingModel.LinearWheelsSettings)),
       //_GT(typeof(ColorGradingModel.LogWheelsSettings)),
       //_GT(typeof(ColorGradingModel.Tonemapper)),
       //_GT(typeof(ColorGradingModel.TonemappingSettings)),
       //_GT(typeof(ColorGradingModel.Settings)),
       //_GT(typeof(UserLutModel)),
       //_GT(typeof(UserLutModel.Settings)),
       //_GT(typeof(ChromaticAberrationModel)),
       //_GT(typeof(ChromaticAberrationModel.Settings)),
       //_GT(typeof(GrainModel)),
       //_GT(typeof(GrainModel.Settings)),
       //_GT(typeof(VignetteModel)),
       //_GT(typeof(VignetteModel.Mode)),
       //_GT(typeof(VignetteModel.Settings)),
       //_GT(typeof(DitheringModel)),
       //_GT(typeof(DitheringModel.Settings)),
       //_GT(typeof(PostProcessingModel)),
#endregion
#region Colorful
       _GT(typeof(AnalogTV)),
       _GT(typeof(BilateralGaussianBlur)),
       _GT(typeof(BleachBypass)),
       _GT(typeof(Blend)),
       _GT(typeof(BrightnessContrastGamma)),
       _GT(typeof(ChannelClamper)),
       _GT(typeof(ChannelMixer)),
       _GT(typeof(ChannelSwapper)),
       _GT(typeof(ChromaticAberration)),
       _GT(typeof(ComicBook)),
       _GT(typeof(ContrastVignette)),
       _GT(typeof(Convolution3x3)),
       _GT(typeof(CrossStitch)),
       _GT(typeof(DirectionalBlur)),
       _GT(typeof(Dithering)),
       _GT(typeof(DoubleVision)),
       _GT(typeof(DynamicLookup)),
       _GT(typeof(FastVignette)),
       _GT(typeof(Frost)),
       _GT(typeof(GaussianBlur)),
       _GT(typeof(Glitch)),
       _GT(typeof(GradientRamp)),
       _GT(typeof(GradientRampDynamic)),
       _GT(typeof(GrainyBlur)),
       _GT(typeof(Grayscale)),
       _GT(typeof(Halftone)),
       _GT(typeof(Histogram)),
       _GT(typeof(HueFocus)),
       _GT(typeof(HueSaturationValue)),
       _GT(typeof(Kuwahara)),
       _GT(typeof(Led)),
       _GT(typeof(LensDistortionBlur)),
       _GT(typeof(Letterbox)),
       _GT(typeof(Levels)),
       _GT(typeof(LoFiPalette)),
       _GT(typeof(LookupFilter)),
       _GT(typeof(LookupFilter3D)),
       _GT(typeof(Negative)),
       _GT(typeof(Noise)),
       _GT(typeof(PhotoFilter)),
       _GT(typeof(Pixelate)),
       _GT(typeof(PixelMatrix)),
       _GT(typeof(Posterize)),
       _GT(typeof(RadialBlur)),
       _GT(typeof(RGBSplit)),
       _GT(typeof(SCurveContrast)),
       _GT(typeof(ShadowsMidtonesHighlights)),
       _GT(typeof(Sharpen)),
       _GT(typeof(SmartSaturation)),
       _GT(typeof(Strokes)),
       _GT(typeof(Technicolor)),
       _GT(typeof(Threshold)),
       _GT(typeof(TVVignette)),
       _GT(typeof(Vibrance)),
       _GT(typeof(Vintage)),
       _GT(typeof(VintageFast)),
       _GT(typeof(WaveDistortion)),
       _GT(typeof(WhiteBalance)),
       _GT(typeof(Wiggle)),
#endregion
       _GT(typeof(WWWUtils)),
       _GT(typeof(DateUtils)),
       _GT(typeof(EffectCamera)),
       _GT(typeof(LanguageText)),
       _GT(typeof(Spine.TrackEntry)),
       _GT(typeof(VideoPlayer)),
       _GT(typeof(DateTime)),
       _GT(typeof(TimeSpan)),
       _GT(typeof(MaterialPropertyBlock)),
       _GT(typeof(RuntimePlatform)),
    };

    public static List<Type> dynamicList = new List<Type>()
    {
        typeof(MeshRenderer),
#if !UNITY_5_4_OR_NEWER
        typeof(ParticleEmitter),
        typeof(ParticleRenderer),
        typeof(ParticleAnimator),
#endif

        typeof(BoxCollider),
        typeof(MeshCollider),
        typeof(SphereCollider),
        typeof(CharacterController),
        typeof(CapsuleCollider),

        typeof(Animation),
        typeof(AnimationClip),
        typeof(AnimationState),

        typeof(SkinWeights),
        typeof(RenderTexture),
        typeof(Rigidbody),
    };

    //重载函数，相同参数个数，相同位置out参数匹配出问题时, 需要强制匹配解决
    //使用方法参见例子14
    public static List<Type> outList = new List<Type>()
    {
        
    };
        
    //ngui优化，下面的类没有派生类，可以作为sealed class
    public static List<Type> sealedList = new List<Type>()
    {
        /*typeof(Transform),
        typeof(UIRoot),
        typeof(UICamera),
        typeof(UIViewport),
        typeof(UIPanel),
        typeof(UILabel),
        typeof(UIAnchor),
        typeof(UIAtlas),
        typeof(UIFont),
        typeof(UITexture),
        typeof(UISprite),
        typeof(UIGrid),
        typeof(UITable),
        typeof(UIWrapGrid),
        typeof(UIInput),
        typeof(UIScrollView),
        typeof(UIEventListener),
        typeof(UIScrollBar),
        typeof(UICenterOnChild),
        typeof(UIScrollView),        
        typeof(UIButton),
        typeof(UITextList),
        typeof(UIPlayTween),
        typeof(UIDragScrollView),
        typeof(UISpriteAnimation),
        typeof(UIWrapContent),
        typeof(TweenWidth),
        typeof(TweenAlpha),
        typeof(TweenColor),
        typeof(TweenRotation),
        typeof(TweenPosition),
        typeof(TweenScale),
        typeof(TweenHeight),
        typeof(TypewriterEffect),
        typeof(UIToggle),
        typeof(Localization),*/
    };

    public static BindType _GT(Type t)
    {
        return new BindType(t);
    }

    public static DelegateType _DT(Type t)
    {
        return new DelegateType(t);
    }    


    [MenuItem("Lua/Attach Profiler", false, 151)]
    static void AttachProfiler()
    {
        if (!Application.isPlaying)
        {
            EditorUtility.DisplayDialog("警告", "请在运行时执行此功能", "确定");
            return;
        }

        LuaClient.Instance.AttachProfiler();
    }

    [MenuItem("Lua/Detach Profiler", false, 152)]
    static void DetachProfiler()
    {
        if (!Application.isPlaying)
        {            
            return;
        }

        LuaClient.Instance.DetachProfiler();
    }
}
