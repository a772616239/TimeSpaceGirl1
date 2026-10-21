// HierarchyPathCopy.cs
// Hierarchy 右键 -> 复制节点路径：把选中节点从根到自身的所有节点名用 "/" 拼起来放进剪贴板。
//
// 用法：Hierarchy 里右键任意 GameObject -> 「复制节点路径」子菜单。
//   完整路径            Canvas/Panel/Top/Btn            （快捷键 Cmd/Ctrl + Alt + C）
//   不含根节点           Panel/Top/Btn
//   带重名序号           Canvas/Panel/Top/Btn[1]/Icon    （同级有重名时才追加序号）
//   相对预制体根         Top/Btn                        （仅预制体实例可用）
// 多选时每个对象一行，按选择顺序输出。
//
// 关联文档：docs/hierarchy_path_copy_skill.md

using System.Collections.Generic;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace TSG.EditorTools
{
    public static class HierarchyPathCopy
    {
        const string MenuRoot = "GameObject/复制节点路径/";
        const int MenuPriority = 49;

        // ---------------------------------------------------------------- 菜单

        [MenuItem(MenuRoot + "完整路径 %&c", false, MenuPriority)]
        static void CopyFullPath()
        {
            CopyToClipboard(t => BuildPath(t, true, false), "完整路径");
        }

        // 校验函数用「不带快捷键」的路径注册：Unity 会把快捷键从菜单名里剥掉再匹配校验函数。
        [MenuItem(MenuRoot + "完整路径", true)]
        static bool CopyFullPathValidate()
        {
            return Selection.gameObjects != null && Selection.gameObjects.Length > 0;
        }

        [MenuItem(MenuRoot + "不含根节点", false, MenuPriority + 1)]
        static void CopyPathWithoutRoot()
        {
            CopyToClipboard(t => BuildPath(t, false, false), "不含根节点");
        }

        [MenuItem(MenuRoot + "不含根节点", true)]
        static bool CopyPathWithoutRootValidate()
        {
            return Selection.gameObjects != null && Selection.gameObjects.Length > 0;
        }

        [MenuItem(MenuRoot + "带重名序号", false, MenuPriority + 2)]
        static void CopyPathWithIndex()
        {
            CopyToClipboard(t => BuildPath(t, true, true), "带重名序号");
        }

        [MenuItem(MenuRoot + "带重名序号", true)]
        static bool CopyPathWithIndexValidate()
        {
            return Selection.gameObjects != null && Selection.gameObjects.Length > 0;
        }

        [MenuItem(MenuRoot + "相对预制体根", false, MenuPriority + 3)]
        static void CopyPathRelativeToPrefabRoot()
        {
            CopyToClipboard(BuildPathRelativeToPrefabRoot, "相对预制体根");
        }

        [MenuItem(MenuRoot + "相对预制体根", true)]
        static bool CopyPathRelativeToPrefabRootValidate()
        {
            var gos = Selection.gameObjects;
            if (gos == null || gos.Length == 0) return false;
            foreach (var go in gos)
            {
                if (go != null && PrefabUtility.GetOutermostPrefabInstanceRoot(go) != null) return true;
            }
            return false;
        }

        // ---------------------------------------------------------------- 核心

        /// <summary>把当前选择转成文本写进剪贴板（多选一行一个，按选择顺序去重）。</summary>
        static void CopyToClipboard(System.Func<Transform, string> builder, string label)
        {
            var gos = Selection.gameObjects;
            if (gos == null || gos.Length == 0)
            {
                Debug.LogWarning("[复制节点路径] 没有选中任何 GameObject。");
                return;
            }

            var lines = new List<string>();
            var seen = new HashSet<string>();
            foreach (var go in gos)
            {
                if (go == null) continue;
                var path = builder(go.transform);
                if (string.IsNullOrEmpty(path)) continue;
                if (seen.Add(path)) lines.Add(path);
            }

            if (lines.Count == 0)
            {
                Debug.LogWarning("[复制节点路径] 选中对象没有可用路径（" + label + "）。");
                return;
            }

            var text = string.Join("\n", lines);
            EditorGUIUtility.systemCopyBuffer = text;
            Debug.Log("[复制节点路径/" + label + "] " + text.Replace("\n", "  |  "));
        }

        /// <summary>从场景根（或预制体根）一路拼到目标节点，用 "/" 连接。</summary>
        static string BuildPath(Transform target, bool includeRoot, bool withIndex)
        {
            if (target == null) return string.Empty;

            var chain = new List<Transform>();
            for (var cur = target; cur != null; cur = cur.parent) chain.Add(cur);
            chain.Reverse();

            var sb = new StringBuilder();
            for (int i = 0; i < chain.Count; i++)
            {
                if (!includeRoot && i == 0) continue;
                AppendSegment(sb, chain[i], withIndex);
            }
            return sb.ToString();
        }

        /// <summary>从最外层预制体实例根的下级开始拼路径；不是预制体实例时返回空串。</summary>
        static string BuildPathRelativeToPrefabRoot(Transform target)
        {
            if (target == null) return string.Empty;

            var prefabRoot = PrefabUtility.GetOutermostPrefabInstanceRoot(target.gameObject);
            if (prefabRoot == null) return string.Empty;

            var rootTransform = prefabRoot.transform;
            if (target == rootTransform) return prefabRoot.name;

            var chain = new List<Transform>();
            for (var cur = target; cur != null && cur != rootTransform; cur = cur.parent) chain.Add(cur);
            chain.Reverse();

            var sb = new StringBuilder();
            foreach (var t in chain) AppendSegment(sb, t, false);
            return sb.ToString();
        }

        static void AppendSegment(StringBuilder sb, Transform t, bool withIndex)
        {
            if (sb.Length > 0) sb.Append('/');
            sb.Append(t.name);
            if (withIndex)
            {
                int idx = DuplicateIndex(t);
                if (idx > 0) sb.Append('[').Append(idx).Append(']');
            }
        }

        /// <summary>同级里第一个同名节点返回 0；第 N 个同名节点返回 N；没有重名时统一返回 0。</summary>
        static int DuplicateIndex(Transform t)
        {
            int index = 0;
            int total = 0;

            if (t.parent == null)
            {
                var scene = t.gameObject.scene;
                if (!scene.IsValid()) return 0;
                foreach (var root in scene.GetRootGameObjects())
                {
                    if (root.name != t.name) continue;
                    if (root.transform == t) index = total;
                    total++;
                }
            }
            else
            {
                var parent = t.parent;
                for (int i = 0; i < parent.childCount; i++)
                {
                    var child = parent.GetChild(i);
                    if (child.name != t.name) continue;
                    if (child == t) index = total;
                    total++;
                }
            }

            return total > 1 ? index : 0;
        }
    }
}
