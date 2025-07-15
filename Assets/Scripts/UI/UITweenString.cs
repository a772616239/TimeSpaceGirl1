using UnityEngine;

/// <summary>
/// 控制缓动的UI组件
/// </summary>
public class UITweenSpring : MonoBehaviour {
    public float MomentumAmount = 35f * 0.01f;
    public float Strength = 9;
    public bool IsUseCallBack;
    public Vector3 Momentum;
    public CallBack<Vector3> OnUpdate;
    public CallBack OnMoveEnd;

    private Vector3 _startMomentum;
    private float _duration;
    private float _startTime;

    public void LerpMomentum(Vector3 offset)
    {
        Momentum = offset * MomentumAmount;
        _startMomentum = offset * MomentumAmount;
        _duration = MomentumAmount / Strength;
        _startTime = 0;
    }

    public void Rebound(int type, float strength) // x 0x1 y 0x10 z 0x100
    {
        switch (type)
        {
            case 1:
                _startMomentum.x = -strength * _startMomentum.x;
                break;
            case 2:
                _startMomentum.y = -strength * _startMomentum.y;
                break;
            case 3:
                _startMomentum.x = -strength * _startMomentum.x;
                _startMomentum.y = -strength * _startMomentum.y;
                break;
            case 4:
                _startMomentum.z = -strength * _startMomentum.z;
                break;
            case 5:
                _startMomentum.x = -strength * _startMomentum.x;
                _startMomentum.z = -strength * _startMomentum.z;
                break;
            case 6:
                _startMomentum.y = -strength * _startMomentum.y;
                _startMomentum.z = -strength * _startMomentum.z;
                break;
            case 7:
                _startMomentum.x = -strength * _startMomentum.x;
                _startMomentum.y = -strength * _startMomentum.y;
                _startMomentum.z = -strength * _startMomentum.z;
                break;
        }
    }

    // Update is called once per frame
    void Update () {
        if (!Application.isPlaying) return;
        float delta = Time.unscaledDeltaTime;

        if (IsUseCallBack)
        {
            _startTime += delta;
            if (_startTime < _duration)
            {
                Momentum = Vector3.Lerp(Vector3.zero, _startMomentum, ease(_startTime / _duration));
                OnUpdate(Momentum);
            }
            else
            {
                enabled = false;
                Momentum = Vector3.zero;
                if (OnMoveEnd != null)
                    OnMoveEnd();
            }
        }
        else
        {
            _startTime += delta;
            Momentum = Vector3.Lerp(Vector3.zero, _startMomentum, ease(_startTime / _duration));
        }
	}

    static float ease(float progress)
    {
        return progress * progress - 2 * progress + 1;
    }
}
