namespace GameLogic
{
	using UnityEngine;

	public class ParticleScaler : MonoBehaviour {
#if _USE_BEGIN_SCALE_
    // 需要缩放的普通模型特效,不包含particle
    public List<GameObject> scaleObjs = new List<GameObject>();    
    // 在编辑器上配置启动时的缩放, 代码里不应该改动
    public float BeginScale = 1.0f;
    // 确保只初始化一次
    private bool isInitedBeginScale = false;
#endif
		// 游戏中设置缩放比例
		private float _scaleMultiplier = 1.0f;

		private bool isTransformScale = true;
		private bool isPsStartSizeScale = true;
		private bool isPsGravityScale = true;
		private bool isPsStartSpeedScale = true;

		// 代码中可调用的唯一点
		public float ScaleMultiplier {
			get {
				return _scaleMultiplier;
			}
			set {
				if (Mathf.Abs(value - _scaleMultiplier) > Mathf.Epsilon) {
					SetParticleScaler(value);
				}
			}
		}

		void Start() {
			checkInitBeginScale();
		}

		void checkInitBeginScale() {
#if _USE_BEGIN_SCALE_
        if (!isInitedBeginScale)
        {
            isInitedBeginScale = true;
            if (Mathf.Abs(BeginScale - 1) < Mathf.Epsilon)
                return;
            SetParticleScaler(BeginScale);
            _scaleMultiplier = 1;
        }
#endif
		}

		void SetParticleScaler(float psScaler) {
			checkInitBeginScale();

			float mulScale = psScaler / _scaleMultiplier;
			ParticleSystem[] pss = gameObject.GetComponentsInChildren<ParticleSystem>();
			for (int i = 0; i < pss.Length; ++i) {
				if (pss[i].scalingMode == ParticleSystemScalingMode.Hierarchy)
					continue;
				pss[i].Stop();
				scalePs(gameObject, pss[i], mulScale);
				pss[i].Play();
			}
#if _USE_BEGIN_SCALE_
        for (int i = 0; i < scaleObjs.Count; ++i)
        {
            scaleObjs[i].transform.localScale *= mulScale;
        }
#else
			if (isTransformScale)
				transform.localScale *= mulScale;
#endif
			_scaleMultiplier = psScaler;
		}

		void scalePs(GameObject obj, ParticleSystem ps, float mulScale) {
			if (isPsStartSizeScale)
				ps.startSize *= mulScale;
			if (isPsGravityScale)
				ps.gravityModifier *= mulScale;
			if (isPsStartSpeedScale)
				ps.startSpeed *= mulScale;
		}
	}
}
