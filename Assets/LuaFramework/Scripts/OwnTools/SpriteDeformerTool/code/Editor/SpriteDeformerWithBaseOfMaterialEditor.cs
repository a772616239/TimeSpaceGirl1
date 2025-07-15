using UnityEngine;
using System.Collections;
using UnityEditor;
using Game.SpriteDeformerTools;

namespace Game.SpriteDeformerToolsEditor
{
    public class SpriteDeformerWithBaseOfMaterialEditor :SpriteDeformerEditor
    {
        SpriteDeformerWithBaseOfMaterial spriteDeformerWithM;
        public void drawSelectMaterial()
        {
            //if (Application.isPlaying) return;
            spriteDeformerWithM = (SpriteDeformerWithBaseOfMaterial)target;

            if (spriteDeformerWithM.referenceMaterial == null && !Application.isPlaying)
            {
                string[] s = AssetDatabase.FindAssets("m:Sprite Deformer standart material");
                if (s.Length > 0)
                {
                    Material m = (Material)AssetDatabase.LoadAssetAtPath(AssetDatabase.GUIDToAssetPath(s[0]), typeof(Material));
                    spriteDeformerWithM.referenceMaterial = m;
                }
            }
            spriteDeformerWithM.referenceMaterial 
                = 
                (Material)EditorGUILayout.ObjectField("Material:", spriteDeformerWithM.referenceMaterial, typeof(Material),false);
        }
        protected override void inspectorMain()
        {
            drawSelectMaterial();
            base.inspectorMain();
        }
        protected override void OnEnable()
        {

            base.OnEnable();

        }
    }

}
