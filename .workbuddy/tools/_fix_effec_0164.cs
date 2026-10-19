var matPath = "Assets/Art/effectMaterials/effec_M_0164.mat";
var texPath = "Assets/Art/EffectsOld/Textures/cn2-tex_glow_020.png";

var mat = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(matPath);
if (mat == null) return "MAT NOT FOUND";
var tex = UnityEditor.AssetDatabase.LoadAssetAtPath<Texture2D>(texPath);
if (tex == null) return "TEX NOT FOUND";

var sb = new System.Text.StringBuilder();
sb.AppendLine("BEFORE: Main=" + (mat.GetTexture("_MainTex") == null ? "NULL" : mat.GetTexture("_MainTex").name)
    + " _Alpha=" + mat.GetFloat("_Alpha") + " _Color=" + mat.GetColor("_Color")
    + " keywords=" + string.Join(",", mat.shaderKeywords));

mat.SetTexture("_MainTex", tex);
UnityEditor.EditorUtility.SetDirty(mat);
UnityEditor.AssetDatabase.SaveAssets();
UnityEditor.AssetDatabase.Refresh();

// 重新从磁盘读一次，确认真的落盘了
var re = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(matPath);
var t = re.GetTexture("_MainTex");
sb.AppendLine("AFTER : Main=" + (t == null ? "NULL" : t.name) + " (" + (t == null ? 0 : t.width) + "x" + (t == null ? 0 : t.height) + ")");
sb.AppendLine("        _MainTex scale=" + re.GetTextureScale("_MainTex") + " offset=" + re.GetTextureOffset("_MainTex"));
sb.AppendLine("        _Alpha=" + re.GetFloat("_Alpha") + " _Color=" + re.GetColor("_Color")
    + " _ISsmoke=" + re.GetFloat("_ISsmoke") + " keywords=" + string.Join(",", re.shaderKeywords));
return sb.ToString();
