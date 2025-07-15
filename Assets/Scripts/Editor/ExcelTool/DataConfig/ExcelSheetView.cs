using GameEditor.Core.TreeViewBase;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.IMGUI.Controls;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    public class ExcelSheetData
    {
        public DataSheet sheet;
        public int lineIndex;
    }

    public class ExcelSheetView : TreeViewWithTreeModel<TreeElementWithData<ExcelSheetData>>
    {
        const float kRowHeights = 20f;
        public ExcelSheetView(TreeViewState state, MultiColumnHeader multiColumnHeader, TreeModel<TreeElementWithData<ExcelSheetData>> model) 
            : base(state, multiColumnHeader, model)
        {
            rowHeight = kRowHeights;
            showAlternatingRowBackgrounds = true;
            showBorder = true;

            Reload();
        }

        protected override bool CanStartDrag(CanStartDragArgs args)
        {
            return false;
        }

        protected override bool CanMultiSelect(TreeViewItem item)
        {
            return false;
        }

        protected override void RowGUI(RowGUIArgs args)
        {
            var item = (TreeViewItem<TreeElementWithData<ExcelSheetData>>)args.item;
            TreeElementWithData<ExcelSheetData> element = item.data;

            for (int i = 0; i < args.GetNumVisibleColumns(); ++i)
            {
                int visibleColIndex = args.GetColumn(i);
                Rect cellRect = args.GetCellRect(i);
                DataSheet sheet = element.Data.sheet;
                var line = sheet.lines[element.Data.lineIndex];
                var cell = line[visibleColIndex];
                string label = cell;
                if(label == null)
                {
                    label = "";
                }
                //string eMsg = null;
                //bool cellVerify = cell.Verify(sheet, out eMsg);
                Rect valueRect = cellRect;
                Color fColor = GUI.contentColor;
                //if(!cellVerify)
                //{
                //    valueRect.width -= 16;
                //    Rect tipRect = valueRect;
                //    tipRect.width = 16;
                //    tipRect.x += valueRect.width;

                //    EditorGUI.LabelField(tipRect, new GUIContent("", eMsg), "CN EntryErrorIconSmall");

                //    GUI.contentColor = Color.red;
                //}
                if (visibleColIndex != 0)
                {
                    EditorGUI.LabelField(valueRect, label, EditorStyles.textField);
                }
                else
                {
                    EditorGUI.LabelField(valueRect, label);
                }
                GUI.contentColor = fColor;
            }
        }

        internal static MultiColumnHeaderState CreateDefaultMultiColumnHeaderState(List<DataField> fields)
        {
            MultiColumnHeaderState.Column[] columns = new MultiColumnHeaderState.Column[fields.Count];
            for(int i =0;i<fields.Count;i++)
            {
                MultiColumnHeaderState.Column col = new MultiColumnHeaderState.Column()
                {
                    headerContent = new GUIContent(fields[i].name),
                    headerTextAlignment = TextAlignment.Center,
                    autoResize = true,
                    canSort = false,
                };
                if (fields[i].fieldType == DataFieldType.String
                    || fields[i].fieldType == DataFieldType.Stringt
                    || fields[i].fieldType == DataFieldType.Res
                    || fields[i].fieldType == DataFieldType.Mut
                    )
                {
                    col.width = col.minWidth = 180;
                }else
                {
                    col.width = col.minWidth = 80;
                }
                columns[i] = col;
            }
            MultiColumnHeaderState state = new MultiColumnHeaderState(columns);
            return state;
        }
    }
}
