using UnityEngine;
using UnityEditor;
 
[CustomEditor(typeof(SkinnedMeshRenderer))]
public class SkinnedMeshRendererEditor : Editor
{
   SkinnedMeshRenderer skinnedMeshRenderer;
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
       skinnedMeshRenderer = target as SkinnedMeshRenderer;
 
        string[] layerNames = new string[SortingLayer.layers.Length];
        for (int i = 0; i < SortingLayer.layers.Length; i++)
            layerNames[i] = SortingLayer.layers[i].name;
 
        int layerValue = SortingLayer.GetLayerValueFromID(skinnedMeshRenderer.sortingLayerID); 
        layerValue = EditorGUILayout.Popup("Sorting Layer", layerValue, layerNames);
 
        SortingLayer layer = SortingLayer.layers[layerValue];
        skinnedMeshRenderer.sortingLayerName = layer.name;
        skinnedMeshRenderer.sortingLayerID = layer.id;
        skinnedMeshRenderer.sortingOrder = EditorGUILayout.IntField("Order in Layer", skinnedMeshRenderer.sortingOrder);
    }
}
