using UnityEditor;
using UnityEngine;

public class DataConfigMD5Record : ScriptableObject
{
    public const string SettingsAssetName = "DataConfigMD5Record";
    private static DataConfigMD5Record instance;
    public static DataConfigMD5Record Instance
    {
        get
        {
            if (instance == null)
            {
                instance = AssetDatabase.LoadAssetAtPath<DataConfigMD5Record>("Assets/Scripts/Editor/ExcelTool/" + SettingsAssetName + ".asset");
                if (instance == null)
                {
                    instance = CreateInstance<DataConfigMD5Record>();
                    instance.name = "DataConfigMD5Record";
                    instance._keys = new string[0];
                    instance._values = new string[0];
#if UNITY_EDITOR
                    AssetDatabase.CreateAsset(instance, "Assets/Scripts/Editor/ExcelTool/" + SettingsAssetName + ".asset");
                    AssetDatabase.Refresh();
#endif
                }
            }
            return instance;
        }
    }

    [SerializeField]
    private string[] _keys;
    public string[] Keys
    {
        get
        {
            return _keys;
        }
        set
        {
            _keys = value;
        }
    }

    [SerializeField]
    private string[] _values;
    public string[] Values
    {
        get
        {
            return _values;
        }
        set
        {
            _values = value;
        }
    }
}
