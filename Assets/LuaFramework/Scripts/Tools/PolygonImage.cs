using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
/// <summary>
/// 响应不规则区域点击事件
/// </summary>
[RequireComponent(typeof(PolygonCollider2D))]
public class PolygonImage : Image {
    PolygonCollider2D polygonCollider2D;
    protected override void Awake()
    {
        base.Awake();
        polygonCollider2D = this.GetComponent<PolygonCollider2D>();
    }

    public override bool IsRaycastLocationValid(Vector2 screenPoint, Camera eventCamera)
    {
        if (eventCamera != null) screenPoint = eventCamera.ScreenToWorldPoint(screenPoint);
        return polygonCollider2D.OverlapPoint(screenPoint);
    }

}
