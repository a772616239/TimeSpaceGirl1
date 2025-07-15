using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

public class RoleProperty : MonoBehaviour
{
    private static string[] ERoleProperty = {
        "等级",
        "生命",
        "最大生命",
        "攻击力",
        "护甲",
        "魔抗",
        "速度",
        "伤害加成系数（%）",
        "伤害减免系数（%）",
        "施法率（%）",
        "后期基础施法率（%）",
        "暴击率（%）",
        "暴击伤害系数（%）",
        "抗暴率（%）",
        "治疗加成系数（%）",
        "受到治疗加成系数（%）",    
        "物伤",
        "法伤",
        "物免",
        "法免",
        "速度加成",
        "攻击加成",
        "护甲加成",
        "控制几率",
        "控制抵抗",
        "技能伤害",
        "对高爆型伤害",
        "对穿甲型伤害",
        "对防御型伤害",
        "对辅助型伤害",
        "受穿甲型伤害降低",
        "受高爆型伤害降低",
        "受防御型伤害降低",
        "受辅助型伤害降低",
        "暴伤抵抗",
        "修理暴击",
        "修理暴击效果",
        "生命加成",
"other",
"other",
"other",
"other",
"other",
"other",
"other",
"other",
    };
    private Dictionary<string, float> _dic = new Dictionary<string, float>();
    private void Awake()
    {
        if (!Directory.Exists(Application.dataPath + "/../BattleRecord"))
        {
            Directory.CreateDirectory(Application.dataPath + "/../BattleRecord");
        }
    }

    public int uid;

    public void AddProperty(int id, float value)
    {
        string name = ERoleProperty[id-1];
        if (!_dic.ContainsKey(name))
        {
            _dic.Add(name, value);
        }
        else
        {
            _dic[name] = value;
        }
    }

    public void SetValue(int id, float value)
    {
        string name = ERoleProperty[id - 1];
        if (_dic.ContainsKey(name))
        {
            _dic[name] = value;
        }
    }

    public float GetValue(string name)
    {
        return _dic[name];
    }

    public string[] GetNames()
    {
        return _dic.Keys.ToArray();
    }
}