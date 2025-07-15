using UnityEngine;
namespace GameCore
{
    /// <summary>
    /// List.string配置
    /// </summary>
    [CreateAssetMenu(menuName = "自定义/StringArrayConfig")]
    [System.Serializable]
    public class StringArrayConfig : ScriptableObject {
        public string[] Configs;
	}
}
