using UnityEngine;
using System.Collections;
using UnityEngine.EventSystems;
using UnityEngine.Events;

public class LongPressButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerExitHandler
{
    private bool hadInvoke = false;//是否已经调用过  

    public float interval = 0.1f;//按下后超过这个时间则认定为"长按"  
    private bool isPointerDown = false;
    private float recordTime;

    public UnityEvent onLongPress = new UnityEvent();//松开时调用  

    void Update()
    {
        if (hadInvoke) return;
        if (isPointerDown)
        {
            if ((Time.time - recordTime) > interval)
            {
                onLongPress.Invoke();
                hadInvoke = true;
            }
        }
    }

    public void OnPointerDown(PointerEventData eventData)
    {
        isPointerDown = true;
        recordTime = Time.time;
    }

    public void OnPointerUp(PointerEventData eventData)
    {
        if (!isPointerDown)
            return;

        isPointerDown = false;
        hadInvoke = false;
    }

    public void OnPointerExit(PointerEventData eventData)
    {
        if (!isPointerDown)
            return;

        isPointerDown = false;
        hadInvoke = false;
    }
}  
