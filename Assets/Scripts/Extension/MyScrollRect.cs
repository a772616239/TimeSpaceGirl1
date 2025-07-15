using GameLogic;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
public class MyScrollRect : ScrollRect
{
    
    //上层ScrollRect
    private ScrollRect upperScroll;
    private EventTriggerListener etl;

    public RectTransform upperScrollView;
    public RectTransform upperScrollRect;
    //方向
    private enum Direction
    {
        Horizontal,
        Vertical
    }
    //预设滑动方向
    private Direction dir;
    //当前操作方向
    private Direction dragDir;

    public enum ScrollGroupType
    {
        ScrollRect_ScrollView,
        ScrollRect_ScrollRect
    }
    public ScrollGroupType scrollGroupType;

    protected override void Awake()
    {
        //找到父对象
        //Transform parent = transform.parent;
        if (upperScrollRect && scrollGroupType == ScrollGroupType.ScrollRect_ScrollRect)
        {
            upperScroll = upperScrollRect.GetComponentInParent<ScrollRect>();
        }
        if (horizontal && vertical)
        {
            vertical = false;
            Debug.LogWarning("不能同时选择Horizontal和Vertical,同时选择时默认仅Horizontal");
        }
        dir = horizontal ? Direction.Horizontal : Direction.Vertical;
        base.Awake();
    }
    protected override void Start()
    {
        if (upperScrollView && scrollGroupType == ScrollGroupType.ScrollRect_ScrollView)
        {
            RectTransform ScrollCycleViewTrans = (RectTransform)upperScrollView.transform.Find("ScrollCycleView");
            if(ScrollCycleViewTrans)
            {
                etl = ScrollCycleViewTrans.GetComponentInParent<EventTriggerListener>();
            }
        }
        base.Start();
    }


    public override void OnBeginDrag(PointerEventData eventData)
    {
        if (etl && scrollGroupType == ScrollGroupType.ScrollRect_ScrollView)
        {
            //判断手势方向
            dragDir = Mathf.Abs(eventData.delta.x) > Mathf.Abs(eventData.delta.y) ? Direction.Horizontal : Direction.Vertical;
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                etl.OnBeginDrag(eventData);
                return;
            }
        }
        if (upperScroll && scrollGroupType == ScrollGroupType.ScrollRect_ScrollRect)
        {
            //判断手势方向
            dragDir = Mathf.Abs(eventData.delta.x) > Mathf.Abs(eventData.delta.y) ? Direction.Horizontal : Direction.Vertical;
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                upperScroll.OnBeginDrag(eventData);
                return;
            }
        }
        base.OnBeginDrag(eventData);
    }
    public override void OnDrag(PointerEventData eventData)
    {
        if (etl && scrollGroupType == ScrollGroupType.ScrollRect_ScrollView)
        {
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                etl.OnDrag(eventData);
                return;
            }
        }
        if (upperScroll && scrollGroupType == ScrollGroupType.ScrollRect_ScrollRect)
        {
            Debug.LogError(dragDir);
            Debug.LogError(dir);
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                upperScroll.OnDrag(eventData);
                return;
            }
        }
        base.OnDrag(eventData);
    }

    public override void OnEndDrag(PointerEventData eventData)
    {
        if (etl && scrollGroupType == ScrollGroupType.ScrollRect_ScrollView)
        {
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                etl.OnEndDrag(eventData);
                return;
            }
        }
        if (upperScroll && scrollGroupType == ScrollGroupType.ScrollRect_ScrollRect)
        {
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                upperScroll.OnEndDrag(eventData);
                return;
            }
        }
        base.OnEndDrag(eventData);
    }

    public override void OnScroll(PointerEventData data)
    {
        if (etl && scrollGroupType == ScrollGroupType.ScrollRect_ScrollView)
        {
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                etl.OnScroll(data);
                return;
            }
        }
        if (upperScroll && scrollGroupType == ScrollGroupType.ScrollRect_ScrollRect)
        {
            if (dragDir != dir)
            {//当前滑动方向不等于ScrollRect预设方向，故执行上层ScrollRect事件
                upperScroll.OnScroll(data);
                return;
            }
        }
        base.OnScroll(data);
    }
}