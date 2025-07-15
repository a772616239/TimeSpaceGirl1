using UnityEngine;
using UnityEditor;
using GameLogic;

[CustomEditor((typeof(RoleProperty)))]
public class RolePropertyInspector : Editor {

    private RoleProperty _br;
    private float[] _properties;
    private string[] _propertyKeys;
    private bool _isDebug;

    void Awake()
    {
        if (Application.isPlaying)
        {
            Init();
        }
    }


    protected void Init()
    {
        _br = ((RoleProperty)target);
        _propertyKeys = _br.GetNames();
        _properties = new float[_propertyKeys.Length];
        for (int i = 0; i < _propertyKeys.Length; i++)
        {
            _properties[i] = _br.GetValue(_propertyKeys[i]);
        }
        _isDebug = true;
    }
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        EditorGUILayout.BeginVertical();

        EditorGUILayout.BeginHorizontal();
        GUI.color = Color.yellow;
        GUILayout.Label("是否手动控制 : ");
        bool b = EditorGUILayout.Toggle(_isDebug);
        if (b != _isDebug)
        {
            Util.CallMethod("BattleLogic", "SetRoleDebug", _br.uid, b);
            _isDebug = b;
        }
        EditorGUILayout.EndHorizontal();

        for (int i = 0; i < _propertyKeys.Length; i++)
        {
            EditorGUILayout.BeginHorizontal();
            GUI.color = Color.cyan;
            GUILayout.Label(_propertyKeys[i] + " : ");
            _properties[i] = _br.GetValue(_propertyKeys[i]);
            float v = EditorGUILayout.FloatField(_properties[i]);
            if(v != _properties[i])
            {
                _properties[i] = v;
                Util.CallMethod("BattleLogic", "SetRoleValue", _br.uid, i+1, v);
            }
            EditorGUILayout.EndHorizontal();
        }
        GUILayout.Space(10);

        EditorGUILayout.EndVertical();
    }
}
