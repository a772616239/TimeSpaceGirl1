﻿using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(CanvasRenderer))]
public class RadarChart : MaskableGraphic
{
    public int EdgeCount
    {
        get
        {
            if (m_Weights == null)
                return 0;
            return m_Weights.Count;
        }
    }

    public List<float> Weights
    {
        get { return m_Weights; }
    }

    [SerializeField] private List<float> m_Weights;

    //重绘UI的Mesh
    protected override void OnPopulateMesh(VertexHelper vh)
    {
        if (m_Weights == null || m_Weights.Count <= 2)
        {
            base.OnPopulateMesh(vh);
            return;
        }
        int edgeCount = m_Weights.Count;

        float deltaAngle = 360f / edgeCount;

        vh.Clear();

        for (int i = 0; i < edgeCount; i++)
        {
            GetTriangle(vh, i, deltaAngle);
        }
    }


    private void GetTriangle(VertexHelper vh, int index, float deltaAngle)
    {
        float edgeLength = Mathf.Min(rectTransform.rect.width, rectTransform.rect.height) * 0.5f;
        var color32 = color;
        Vector3 cent = new Vector3(0, 0);
        float angle1 = 90 + (index + 1) * deltaAngle;
        float angle2 = 90 + (index) * deltaAngle;
        float radius1 = (index == m_Weights.Count - 1 ? m_Weights[0] : m_Weights[index + 1]) * edgeLength;
        float radius2 = m_Weights[index] * edgeLength;

        Vector3 p1 = new Vector3(radius1 * Mathf.Cos(angle1 * Mathf.Deg2Rad), radius1 * Mathf.Sin(angle1 * Mathf.Deg2Rad));
        Vector3 p2 = new Vector3(radius2 * Mathf.Cos(angle2 * Mathf.Deg2Rad), radius2 * Mathf.Sin(angle2 * Mathf.Deg2Rad));

        vh.AddVert(cent, color32, Vector2.zero);
        vh.AddVert(p1, color32, new Vector2(0, 1));
        vh.AddVert(p2, color32, new Vector2(1, 0));

        vh.AddTriangle(index * 3, index * 3 + 1, index * 3 + 2);
    }

    public void SetEdges(float[] edges)
    {
        m_Weights.Clear();
        for(int i = 0; i < edges.Length; i++)
        {
            m_Weights.Add(edges[i]);
        }
    }

    public bool IsRaycastLocationValid(Vector2 sp, Camera eventCamera)
    {
        if (raycastTarget)
        {
            Vector2 local;
            RectTransformUtility.ScreenPointToLocalPointInRectangle(rectTransform, sp, eventCamera, out local);

            int edgeCount = m_Weights.Count;

            float deltaAngle = 360f / edgeCount;

            for (int i = 0; i < edgeCount; i++)
            {
                bool result = IsInPolygon(i, deltaAngle, local);
                if (result)
                    return true;
            }
        }
        return false;
    }

    private bool IsInPolygon(int index, float deltaAngle, Vector2 point)
    {
        float edgeLength = Mathf.Min(rectTransform.rect.width, rectTransform.rect.height) * 0.5f;
        Vector2 cent = new Vector2(0, 0);
        float angle1 = 90 + (index + 1) * deltaAngle;
        float angle2 = 90 + (index) * deltaAngle;
        float radius1 = (index == m_Weights.Count - 1 ? m_Weights[0] : m_Weights[index + 1]) * edgeLength;
        float radius2 = m_Weights[index] * edgeLength;

        Vector2 p1 = new Vector2(radius1 * Mathf.Cos(angle1 * Mathf.Deg2Rad), radius1 * Mathf.Sin(angle1 * Mathf.Deg2Rad));
        Vector2 p2 = new Vector2(radius2 * Mathf.Cos(angle2 * Mathf.Deg2Rad), radius2 * Mathf.Sin(angle2 * Mathf.Deg2Rad));

        return IsInTriangle(cent, p1, p2, point);
    }

    private bool IsInTriangle(Vector2 vertex1, Vector2 vertex2, Vector2 vertex3, Vector2 point)
    {
        Vector2 v0 = vertex3 - vertex1;
        Vector2 v1 = vertex2 - vertex1;
        Vector2 v2 = point - vertex1;

        float dot00 = Vector2.Dot(v0, v0);
        float dot01 = Vector2.Dot(v0, v1);
        float dot02 = Vector2.Dot(v0, v2);
        float dot11 = Vector2.Dot(v1, v1);
        float dot12 = Vector2.Dot(v1, v2);

        float inverDeno = 1 / (dot00 * dot11 - dot01 * dot01);

        float u = (dot11 * dot02 - dot01 * dot12) * inverDeno;
        if (u < 0 || u > 1)
        {
            return false;
        }

        float v = (dot00 * dot12 - dot01 * dot02) * inverDeno;
        if (v < 0 || v > 1)
        {
            return false;
        }

        return u + v <= 1;
    }
}