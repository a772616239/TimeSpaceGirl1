using UnityEditor;

[CustomEditor(typeof(LanguageText), true)]
[CanEditMultipleObjects]
public class LanguageTextEditor : UnityEditor.UI.TextEditor
{
    SerializedProperty LanguageIndex;

    protected override void OnEnable()
    {
        base.OnEnable();
        LanguageIndex = serializedObject.FindProperty("LanguageIndex");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();
        base.OnInspectorGUI();
        EditorGUILayout.PropertyField(LanguageIndex);
        serializedObject.ApplyModifiedProperties();
    }

}
