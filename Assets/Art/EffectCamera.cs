using UnityEngine;

/// <summary>
/// 特效摄像机动画参数
/// </summary>
public class EffectCamera : MonoBehaviour
{
    /// <summary>
    /// 摄像机位置
    /// </summary>
    public Transform effectCamera;
    /// <summary>
    /// 如果区分左右方,左边施法摄像机位置
    /// </summary>
    public Transform effectCamera_left;
    /// <summary>
    /// 如果区分左右方,右边施法摄像机位置
    /// </summary>
    public Transform effectCamera_right;
    /// <summary>
    /// 摄像机动画节点
    /// </summary>
    public Transform CameraAni;
}
