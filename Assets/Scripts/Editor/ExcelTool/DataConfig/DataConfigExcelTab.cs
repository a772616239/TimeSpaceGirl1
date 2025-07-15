using GameEditor.Core.TreeViewBase;
using GameEditor.Core.Util;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.IMGUI.Controls;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    public class DataConfigExcelTab
    {
        public DataConfigWindow configWin;

        private ExcelTreeView excelTreeView = null;
        private TreeViewState excelTreeViewState = null;
        private ExcelTreeViewData selectedExcelData = null;

        private ExcelSheetView sheetTreeView = null;
        private TreeViewState sheetTreeViewState = null;
        public DataConfigExcelTab(DataConfigWindow win)
        {
            configWin = win;
        }
        private const float Excel_Tree_Width = 200;
        public void OnGUI(Rect rect)
        {
            Rect excelRect = new Rect(rect.x, rect.y, Excel_Tree_Width, rect.height);
            GUI.Box(excelRect, "",EditorStyles.helpBox);
            Rect excelTitleRect = new Rect(rect.x+2, rect.y+2, Excel_Tree_Width, 20);
            EditorGUI.LabelField(excelTitleRect, "Excel Tree List", GTEditorGUIStyle.BigLabelMidCeneterStyle);

            Rect excelTreeRect = excelTitleRect;
            excelTreeRect.y = excelTitleRect.y + excelTitleRect.height+10;
            excelTreeRect.height = rect.height - excelTitleRect.y - excelTitleRect.height - 20;

            if(excelTreeView == null)
            {
                InitExcelTreeView();
            }
            excelTreeView.OnGUI(excelTreeRect);

            Rect splitRect = new Rect(Excel_Tree_Width+5,rect.y,4,rect.height);
            GTEditorGUI.DrawHorizontalSplitter(splitRect);

            Rect tableRect = new Rect(splitRect.x + splitRect.width + 2, rect.y, rect.width - splitRect.x - splitRect.width - 10, rect.height);
            GUI.Box(tableRect,"",EditorStyles.helpBox);

            Rect tableTitleRect = tableRect;
            tableTitleRect.height = 20;
            EditorGUI.LabelField(tableTitleRect, "Excel Table", GTEditorGUIStyle.BigLabelMidCeneterStyle);

            Rect sheetRect = tableTitleRect;
            sheetRect.y += tableTitleRect.height;
            sheetRect.height = rect.height - 60;
            if (selectedExcelData == null || !selectedExcelData.IsSheet())
            {
                EditorGUI.LabelField(sheetRect, "请从左侧选择要查看数据表");
                Rect exportBtnRect = rect;
                exportBtnRect.x = rect.x + rect.width - 120;
                exportBtnRect.y = rect.y + rect.height - 30;
                exportBtnRect.width = 100;
                exportBtnRect.height = 20;
                if (GUI.Button(exportBtnRect, "Export All"))
                {
                    List<DataExcelSetting> excels = DataConfigWindow.window.excels;
                    if(excels != null)
                    {
                        for (int i = 0; i < excels.Count; i++)
                        {
                            if(excels[i].sheets != null)
                            {
                                for (int j = 0; j < excels[i].sheets.Count; j++)
                                {
                                    DataSheet sheet = excels[i].sheets[j];

                                    bool isServer = true;
                                    foreach (DataField df in sheet.fields)
                                    {
                                        if(df.exportType == DataFieldExportType.Client || df.exportType == DataFieldExportType.All)
                                        {
                                            isServer = false;
                                            break;
                                        }
                                    }

                                    if (!isServer)
                                    {
                                        try
                                        {
                                            if (DataToOptimizeLuaExporter.CheckIsExport(sheet))
                                            {
                                                new DataToOptimizeLuaExporter(sheet, DataConfigWindow.window.setting).Export();
                                            }
                                            else
                                            {
                                                Debug.LogError("前端没有数据导出");
                                            }

                                            DataToTxtExporter.Export(sheet, DataConfigWindow.window.setting);
                                            AssetDatabase.Refresh();
                                        }
                                        catch (System.Exception e)
                                        {
                                            Debug.Log(e);
                                        }
                                    }
                                    else
                                    {
                                        Debug.Log("该表为纯后端表，无需导出！" + sheet.name);
                                    }
                                }
                            }
                        }
                        EditorUtil.ShowSureDialog("配置表数据导入完毕!");
                    }

                }
            }
            else
            {
                List<DataExcelSetting> excels = DataConfigWindow.window.excels;
                DataSheet sheet = excels[selectedExcelData.excelIndex].sheets[selectedExcelData.sheetIndex];
                if(sheet == null || sheet.fields.Count == 0)
                {
                    EditorGUI.LabelField(sheetRect, "解析数据表错误，请检查需要查询的数据表格式");
                }else
                {
                    if(sheetTreeView == null)
                        InitSheetTreeView(sheet);
                }
                if(sheetTreeView!=null)
                {
                    sheetTreeView.OnGUI(sheetRect);

                    Rect exportBtnRect = rect;
                    exportBtnRect.x = rect.x + rect.width - 80;
                    exportBtnRect.y = rect.y + rect.height - 30;
                    exportBtnRect.width = 60;
                    exportBtnRect.height = 20;
                    if(GUI.Button(exportBtnRect, "Export"))
                    {
                        System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
                        time.Start();
                        if (DataToOptimizeLuaExporter.CheckIsExport(sheet))
                        {
                            new DataToOptimizeLuaExporter(sheet, DataConfigWindow.window.setting).Export();
                        }
                        else
                        {
                            Debug.LogError("前端没有数据导出");
                        }
                
                        DataToTxtExporter.Export(sheet, DataConfigWindow.window.setting);
                        AssetDatabase.Refresh();

                        time.Stop();
                        Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                        EditorUtil.ShowSureDialog("配置表数据导入完毕!");
                    }

                   


                }
            }
        }

        public void InitExcelTreeView()
        {
            excelTreeViewState = new TreeViewState();
            excelTreeView = new ExcelTreeView(excelTreeViewState, GetExcelTreeViewModel());
            excelTreeView.onSelected = OnSelected;
        }

        public void InitSheetTreeView(DataSheet sheetData)
        {
            var hs = ExcelSheetView.CreateDefaultMultiColumnHeaderState(sheetData.fields);
            var header = new MultiColumnHeader(hs);

            sheetTreeViewState = new TreeViewState();
            sheetTreeView = new ExcelSheetView(sheetTreeViewState,
                                                header,
                                                GetSheetTreeViewModel(sheetData));
        }

        private TreeModel<TreeElementWithData<ExcelSheetData>> GetSheetTreeViewModel(DataSheet sheetData)
        {
            TreeModel<TreeElementWithData<ExcelSheetData>> model = new TreeModel<TreeElementWithData<ExcelSheetData>>(
                new List<TreeElementWithData<ExcelSheetData>>() {
                    new TreeElementWithData<ExcelSheetData>(new ExcelSheetData(){sheet = null,lineIndex = -1},"",-1,-1),
                }
                );

            for(int i =0;i<sheetData.lines.Count;i++)
            {
                model.AddElement(new TreeElementWithData<ExcelSheetData>(new ExcelSheetData() { sheet = sheetData,lineIndex = i},"",0,i),
                                            model.root, model.root.hasChildren ? model.root.children.Count : 0);
            }

            return model;
        }

        private void OnSelected(TreeElementWithData<ExcelTreeViewData> data)
        {
            selectedExcelData = data.Data;
            sheetTreeView = null;
        }

        private TreeModel<TreeElementWithData<ExcelTreeViewData>> GetExcelTreeViewModel()
        {
            TreeModel<TreeElementWithData<ExcelTreeViewData>> data = new TreeModel<TreeElementWithData<ExcelTreeViewData>>(
                new List<TreeElementWithData<ExcelTreeViewData>>()
                {
                    new TreeElementWithData<ExcelTreeViewData>(ExcelTreeViewData.Root,"",-1,-1),
                });

            List<DataExcelSetting> excels = DataConfigWindow.window.excels;

            for (int i = 0; i < excels.Count; ++i)
            {
                TreeElementWithData<ExcelTreeViewData> excelData = new TreeElementWithData<ExcelTreeViewData>(
                    new ExcelTreeViewData() { excelIndex = i, sheetIndex = -1 }, Path.GetFileNameWithoutExtension(excels[i].excelPath),0, (i + 1) * 100);
                data.AddElement(excelData, data.root, data.root.hasChildren ? data.root.children.Count : 0);
                for (int j =0;j<excels[i].sheets.Count;++j)
                {
                    TreeElementWithData<ExcelTreeViewData> sheetData = new TreeElementWithData<ExcelTreeViewData>(
                    new ExcelTreeViewData() { excelIndex = i, sheetIndex = j }, Path.GetFileNameWithoutExtension(excels[i].sheets[j].name), 1, (i + 1) * 100+(j+1));

                    data.AddElement(sheetData, excelData, excelData.hasChildren ? excelData.children.Count : 0);
                }
            }

            return data;
        }
    }
}
