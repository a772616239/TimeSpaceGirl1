using GameEditor.Core.TreeViewBase;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.IMGUI.Controls;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    public class ExcelTreeViewData
    {
        public int excelIndex = -1;
        public int sheetIndex = -1;

        public static ExcelTreeViewData Root
        {
            get
            {
                return new ExcelTreeViewData();
            }
        }

        public bool IsSheet()
        {
            return excelIndex >= 0 && sheetIndex >= 0;
        }
    }

    public class ExcelTreeView : TreeViewWithTreeModel<TreeElementWithData<ExcelTreeViewData>>
    {
        public delegate void OnTreeElementSelected(TreeElementWithData<ExcelTreeViewData> data);
        public OnTreeElementSelected onSelected = null;
           
        public ExcelTreeView(TreeViewState state, TreeModel<TreeElementWithData<ExcelTreeViewData>> model) : base(state, model)
        {
            showBorder = true;
            Reload();
        }

        protected override void RowGUI(RowGUIArgs args)
        {
            var item = (TreeViewItem<TreeElementWithData<ExcelTreeViewData>>)args.item;
            TreeElementWithData<ExcelTreeViewData> element = item.data;

            Rect contentRect = args.rowRect;
            contentRect.x += GetContentIndent(item);
            contentRect.width -= GetContentIndent(item);

            EditorGUI.LabelField(contentRect, element.name);
        }

        protected override bool CanMultiSelect(TreeViewItem item)
        {
            return false;
        }

        protected override void SelectionChanged(IList<int> selectedIds)
        {
            base.SelectionChanged(selectedIds);
            if(onSelected!=null)
            {
                onSelected(treeModel.Find(selectedIds[0]));
            }
        }
    }
}
