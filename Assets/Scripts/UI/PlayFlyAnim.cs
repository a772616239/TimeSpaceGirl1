using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using DG.Tweening;
using System;
using UnityEngine.UI;
using Sirenix.OdinInspector;

public enum ChangeType
{
    Move,
    LocalMove,
    EulerAngles,
    LocalEulerAngles,
    Scale,
    Shake,
    Fade,
    Color,
    FadeChild,
}

public enum SequeueType
{
    Append, //在上一个tween之后播
    Insert //跟上一个tween一起播
}

[Serializable]
public class ChangeTween
{
    public Vector3 initV3;
    public float initFloat;
    public bool isInit = true; //为true则在最开始设置，作为初始值，否则在动画序列播放前设置
    public Vector3 changeV3;
    public float changeFloat;
    public float duration;
    public float delay;
    public Ease curveType = Ease.Linear;
    public ChangeType changeType = ChangeType.Move;
    public SequeueType sequeueType = SequeueType.Append;
    public int loop;
    public LoopType loopType;
    public Transform targetObj;
}

public class PlayFlyAnim : MonoBehaviour
{
    public ChangeTween[] tweenSequeue;
    public bool isPlayAudio = true;//是否播放声音
    public bool isHaveCloseBtn = false;
    public bool isPlayOnOpen = true; //是否在打开时自动播放

    private Sequence mySeque;
    private Action hideCallback;//隐藏回调
    private Action playAnimOverCallBack;
    private float org_z;
    private bool mousedown = true;
    private bool isrotate = false;
    

    public void PlayAnim(bool playVoice = true, Action _action = null)
    {
        if (mySeque != null)
        {
            mySeque.Kill();
        }
        if (transform == null || tweenSequeue == null) return;
        //AddOrRemoveMask(true);
        //rectTrans.anchoredPosition3D = initPos;
        mySeque = DOTween.Sequence();

        Tween[] tweens;
        for(int i = 0; i < tweenSequeue.Length; i++)
        {
            Tween t = GetTween(transform, tweenSequeue[i], out tweens);       
            if (t != null)
            {
                switch (tweenSequeue[i].sequeueType)
                {
                    case SequeueType.Append:
                        mySeque.Append(t);
                        
                        break;
                    case SequeueType.Insert:
                        mySeque.Join(t);
                        break;
                }
                if (tweens != null)
                {
                    for(int j = 0; j < tweens.Length; j++)
                    {
                        mySeque.Join(tweens[j]);
                    }
                }
            }
        }      
        playAnimOverCallBack = _action;
        if (playVoice && isPlayAudio)
        {
            //AudioManager.Instance.PlayVoice(AudioManager.Audio_Panel_Animation);
        }
       
        mySeque.OnComplete(()=>
        {
            //AddOrRemoveMask(false);
            if (playAnimOverCallBack != null)
            {
                playAnimOverCallBack();
            }
        });
        mousedown = true;
        mySeque.SetAutoKill(false);
    }

    //动画反播
    public void PlayHideAnim(Action _func=null)
    {
        if (transform == null || tweenSequeue == null) return;
        AddOrRemoveMask(true);
        mousedown = true;
        hideCallback = _func;

        mySeque.OnStepComplete(() =>
        {
            AddOrRemoveMask(false);
            if (hideCallback != null)
            {
                hideCallback();
            }
           // mySeque.SetAutoKill();
        });
        mySeque.PlayBackwards();
    }

    private static Tween GetTween(Transform transform, ChangeTween changeTween, out Tween[] tweens)
    {
        tweens = null;
        Tween t = null;
        Transform target = changeTween.targetObj == null ? transform : changeTween.targetObj;

        switch (changeTween.changeType)
        {
            case ChangeType.Move:
                if(target is RectTransform)
                {
                    RectTransform rectTransform = target as RectTransform;
                    if (changeTween.isInit)
                    {
                        rectTransform.anchoredPosition3D = changeTween.initV3;
                    }
                    t = DOTween.To(() =>
                    {
                        if (!changeTween.isInit)
                        {
                            rectTransform.anchoredPosition3D = changeTween.initV3;
                        }                           
                        return rectTransform.anchoredPosition3D;
                    }, v3 => rectTransform.anchoredPosition = v3, changeTween.changeV3, changeTween.duration);
                }
                else
                {
                    if (changeTween.isInit)
                    {
                        target.position = changeTween.initV3;
                    }
                    t = DOTween.To(() =>
                    {
                        if (!changeTween.isInit)
                        {
                            target.position = changeTween.initV3;
                        }
                        return target.position;
                    }, v3 => target.position = v3, changeTween.changeV3, changeTween.duration);
                }               
                break;
            case ChangeType.LocalMove:
                if (target is RectTransform)
                {
                    RectTransform rectTransform = target as RectTransform;
                    if (changeTween.isInit)
                    {
                        rectTransform.anchoredPosition3D = changeTween.initV3;
                    }
                    t = DOTween.To(() =>
                    {
                        if (!changeTween.isInit)
                        {
                            rectTransform.anchoredPosition3D = changeTween.initV3;
                        }
                        return rectTransform.anchoredPosition3D;
                    }, v3 => rectTransform.anchoredPosition = v3, changeTween.changeV3, changeTween.duration);
                }
                else
                {
                    if (changeTween.isInit)
                    {
                        target.localPosition = changeTween.initV3;
                    }
                    t = DOTween.To(() =>
                    {
                        if (!changeTween.isInit)
                        {
                            target.localPosition = changeTween.initV3;
                        }
                        return target.localPosition;
                    }, v3 => target.localPosition = v3, changeTween.changeV3, changeTween.duration);
                }
                break;
            case ChangeType.EulerAngles:
                if (changeTween.isInit)
                {
                    target.eulerAngles = changeTween.initV3;
                }
                t = DOTween.To(() =>
                {
                    if (!changeTween.isInit)
                    {
                        target.eulerAngles = changeTween.initV3;
                    }
                    return target.eulerAngles;
                }, v3 => target.eulerAngles = v3, changeTween.changeV3, changeTween.duration);
                break;
            case ChangeType.LocalEulerAngles:
                if (changeTween.isInit)
                {
                    target.localEulerAngles = changeTween.initV3;
                }
                t = DOTween.To(() =>
                {
                    if (!changeTween.isInit)
                    {
                        target.localEulerAngles = changeTween.initV3;
                    }
                    return target.localEulerAngles;
                }, v3 => target.localEulerAngles = v3, changeTween.changeV3, changeTween.duration);
                break;
            case ChangeType.Scale:
                if (changeTween.isInit)
                {
                    target.localScale = changeTween.initV3;
                }
                t = DOTween.To(() =>
                {
                    if (!changeTween.isInit)
                    {
                        target.localScale = changeTween.initV3;
                    }
                    return target.localScale;
                }, v3 => target.localScale = v3, changeTween.changeV3, changeTween.duration);
                break;
            case ChangeType.Shake:
                if(target is RectTransform)
                {
                    RectTransform rectTransform = target as RectTransform;
                    t = rectTransform.DOShakeAnchorPos(changeTween.duration, changeTween.changeV3.x, (int)changeTween.changeV3.y, changeTween.changeV3.z);
                }                
                break;
            case ChangeType.Fade:
                var image = target.GetComponent<MaskableGraphic>();
                if (image != null)
                {
                    if (changeTween.isInit)
                    {
                        Color oldColor = image.color;
                        oldColor.a = changeTween.initFloat;
                        image.color = oldColor;
                    }
                    t = DOTween.To(() =>
                    {
                        if (!changeTween.isInit)
                        {
                            Color oldColor = image.color;
                            oldColor.a = changeTween.initFloat;
                            image.color = oldColor;
                        }       
                        return image.color.a;
                    }, a => {
                        Color oldColor = image.color;
                        oldColor.a = a;
                        image.color = oldColor;
                    }, changeTween.changeFloat, changeTween.duration);
                }               
                break;
            case ChangeType.Color:
                break;
            case ChangeType.FadeChild:
                var images = target.GetComponentsInChildren<MaskableGraphic>();
                if (images != null)
                {
                    tweens = new Tween[images.Length];
                    for (int i = 0; i < images.Length; i++)
                    {
                        var image1 = images[i];
                        if (image1.transform != target)
                        {
                            if (changeTween.isInit)
                            {
                                Color oldColor = image1.color;
                                oldColor.a = changeTween.initFloat;
                                image1.color = oldColor;
                            }
                            tweens[i] = DOTween.To(() =>
                            {
                                if (!changeTween.isInit)
                                {
                                    Color oldColor = image1.color;
                                    oldColor.a = changeTween.initFloat;
                                    image1.color = oldColor;
                                }
                                return image1.color.a;
                            }, a => {
                                Color oldColor = image1.color;
                                oldColor.a = a;
                                image1.color = oldColor;
                            }, changeTween.changeFloat, changeTween.duration).SetEase(changeTween.curveType).SetDelay(changeTween.delay);
                            if (changeTween.loop != 0)
                            {
                                tweens[i].SetLoops(changeTween.loop, changeTween.loopType);
                            }
                        }                      
                    }
                }
                t = DOTween.To(() => 0, f => { }, 1, changeTween.duration);
                break;
        }
        if (t != null)
        {
            t.SetEase(changeTween.curveType);
            if (changeTween.delay > 0)
            {
                t.SetDelay(changeTween.delay);
            }
            if (changeTween.loop != 0)
            {
                t.SetLoops(changeTween.loop, changeTween.loopType);
            }
        }
        return t;
    }

    [ButtonGroup("")]
    void EditorPlay()
    {
        PlayAnim();
    }

    [ButtonGroup("")]
    void EditorPlayBack()
    {
        PlayHideAnim();
    }
    /// <summary>
    /// 添加或者移除遮罩
    /// </summary>
    /// <param name="_add"></param>

    public void AddOrRemoveMask(bool _add)
    {
        //if (_add)
        //{
        //    if (animMask == null)
        //    {
        //        animMask = new UIMgr.AnimMaskTimeDel();
        //    }
        //    animMask.AddMask();
        //}
        //else
        //{
        //    if (animMask != null)
        //    {
        //        animMask.RemoveMask();
        //    }
        //}
    }

    /// <summary>
    /// 播放隐藏动画最后一帧
    /// </summary>
    public void Reset()
    {
    }
    /// <summary>
    /// 播放动画最后一帧
    /// </summary>
    public void LastFrame()
    {
    }


    void Start()
    {
        GameObject go = GameObject.Find("App");
        if(go == null) //非游戏环境时运行
        {
            PlayAnim();
        }
        //PlayAnim();
        //if (isHaveCloseBtn)
        //{
        //}
    }
    void FixedUpdate()
    {
        if (transform != null)
        {
            if (mousedown)
            {
                if ((transform.eulerAngles.z - org_z) < 260)
                {
                    //objRotate.Rotate(0, 0, Time.deltaTime * 90 * 5, Space.World);
                }
                else
                {
                    //isrotate = true; //已被旋转, 下次打开就回到原来位置.
                    mousedown = false; //停止
                }
                //else
                //{
                //    if (objRotate.transform.eulerAngles.z <= 360 && (objRotate.transform.eulerAngles.z - org_z) >= 0.001)
                //    {
                //        objRotate.transform.Rotate(0, 0, Time.fixedDeltaTime * 90 * 2, Space.World);//复位
                //    }
                //    else
                //    {
                //        isrotate = false; //旋转复原
                //        mousedown = false; //关闭停止
                //    }
                //}
            }
        }
    }
}

