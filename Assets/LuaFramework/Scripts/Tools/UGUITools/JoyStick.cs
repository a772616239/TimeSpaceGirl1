using UnityEngine;
using System.Collections;
using System;
using UnityEngine.EventSystems;

public class JoyStickArgs : EventArgs
{
    public Vector3 dir;
    public JoyStickArgs(Vector3 _dir)
    {
        dir = _dir;
    }
}

public delegate void JoyStickHandler(object o, JoyStickArgs e);

public class JoyStick : MonoBehaviour, IDragHandler, IBeginDragHandler, IEndDragHandler
{
    public event JoyStickHandler moveHandler;
    public event JoyStickHandler beginHandler;
    public event JoyStickHandler endHandler;

    private static JoyStick mIns;

    public RectTransform viewPivot;
    public RectTransform pot;

    private float radius;
    private Vector3 offset = Vector3.zero;
    private bool hasMoving = false;

    void Awake()
    {
        mIns = this;
    }

    void OnEnable()
    {
        radius = viewPivot.sizeDelta.x * 0.5f;
        hasMoving = false;
        offset = Vector3.zero;
    }
    void OnDisable()
    {
        // todo:
    }

    void Update()
    {
        if (hasMoving)
        {
            if (moveHandler != null)
                moveHandler(this, new JoyStickArgs(offset.normalized));
        }
    }

    // get instance
    public static JoyStick Inst()
    {
        return mIns;
    }

    // rigister listener 
    public void RigisterJoyStickHandler(JoyStickHandler _onBeginHandler = null, JoyStickHandler _onMoveHandler = null, JoyStickHandler _onEndHandler = null)
    {
        if (_onBeginHandler != null)
            beginHandler += _onBeginHandler;
        if (_onMoveHandler != null)
            moveHandler += _onMoveHandler;
        if (_onEndHandler != null)
            endHandler += _onEndHandler;
    }

    public void UnRigisterJoyStickHandler(JoyStickHandler _onBeginHandler = null, JoyStickHandler _onMoveHandler = null, JoyStickHandler _onEndHandler = null)
    {
        if (_onBeginHandler != null)
            beginHandler -= _onBeginHandler;
        if (_onMoveHandler != null)
            moveHandler -= _onMoveHandler;
        if (_onEndHandler != null)
            endHandler -= _onEndHandler;
    }

    public void OnDrag(PointerEventData data)
    {
        //limit radius
        if (pot.anchoredPosition.magnitude > radius)
            pot.anchoredPosition = pot.anchoredPosition.normalized * radius;

        offset = pot.anchoredPosition3D;
        if (offset.x < 1.0f && offset.x > -1.0f)
            offset.x = 0.0f;
        if (offset.y < 1.0f && offset.y > -1.0f)
            offset.y = 0.0f;

    }
    public void OnBeginDrag(PointerEventData data)
    {
        hasMoving = true;
        if (beginHandler != null)
            beginHandler(this, new JoyStickArgs(offset.normalized));
    }
    public void OnEndDrag(PointerEventData data)
    {
        hasMoving = false;
        if (endHandler != null)
            endHandler(this, new JoyStickArgs(offset.normalized));
    }
}
