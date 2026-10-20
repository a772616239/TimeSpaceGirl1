using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    /// <summary>
    /// 包内资源构建的常驻批处理入口（供 Jenkins TS-Resource-Build 调用）。
    ///
    /// 为什么要有它：导表与 AB 重建长期是「人肉 GUI 点按钮」的环节，Jenkins 只能体检、
    /// 不能执行 ⇒ 改了 xlsx 忘了导表 / 导了表忘了重建 AB，包照打不误，问题到真机才暴露。
    ///
    /// 三个入口与 GUI 完全同链路：
    ///   ExportTables()   == DataConfig 面板 Excel 页签的「Export All」
    ///   BuildAllABs()    == FrameTool「整体打包资源」+「复制资源到流媒体目录」
    ///
    /// ⚠️ batchmode 下 Debug.Log 抓不到，明细另写 Logs/batch_resource_build.log。
    /// </summary>
    public static class BatchResourceBuild
    {
        static readonly string LogPath = "Logs/batch_resource_build.log";
        static readonly StringBuilder Buffer = new StringBuilder();

        static void L(string msg)
        {
            Buffer.AppendLine(msg);
            Debug.Log("[BatchResource] " + msg);
        }

        static void FlushLog()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath) ?? "Logs");
                File.WriteAllText(LogPath, Buffer.ToString(), Encoding.UTF8);
            }
            catch { }
        }

        /// <summary>
        /// 全量导表：客户端 Lua + 服务端 txt。纯后端表（exportType 全为 Server）跳过 Lua、只出 txt。
        /// 返回码：0 成功；3 有表失败（详见日志）；2 环境问题（目录不存在）
        /// </summary>
        public static void ExportTables()
        {
            Buffer.Clear();
            int rc = 0;
            try
            {
                string excelDir = DataConfigSetting.execlDir;
                L("excelDir=" + excelDir);
                if (string.IsNullOrEmpty(excelDir) || !Directory.Exists(excelDir))
                {
                    L("FAIL 导表目录不存在：" + excelDir);
                    rc = 2;
                    return;
                }

                var setting = new DataConfigSetting();
                L("clientDir=" + setting.clientOutputDir);
                L("serverDir=" + setting.serverOutputDir);

                string[] files = Directory.GetFiles(excelDir, "*.*", SearchOption.AllDirectories);
                Array.Sort(files, StringComparer.Ordinal);
                int excelCount = 0, luaCount = 0, txtCount = 0, serverOnly = 0, failed = 0;

                foreach (var file in files)
                {
                    if (file.Contains("~")) continue;
                    string ext = Path.GetExtension(file).ToLower();
                    if (ext != ".xlsx" && ext != ".xls") continue;

                    excelCount++;
                    DataExcelSetting eSetting;
                    try
                    {
                        eSetting = new DataExcelSetting(file);
                    }
                    catch (Exception e)
                    {
                        L("FAIL 读取失败 " + file + " : " + e.Message);
                        failed++;
                        continue;
                    }
                    if (eSetting.sheets == null || eSetting.sheets.Count == 0)
                    {
                        L("SKIP 空表 " + Path.GetFileName(file));
                        continue;
                    }

                    foreach (var sheet in eSetting.sheets)
                    {
                        if (sheet == null) continue;

                        bool isServerOnly = true;
                        foreach (var df in sheet.fields)
                        {
                            if (df.exportType == DataFieldExportType.Client || df.exportType == DataFieldExportType.All)
                            {
                                isServerOnly = false;
                                break;
                            }
                        }

                        try
                        {
                            if (!isServerOnly)
                            {
                                if (DataToOptimizeLuaExporter.CheckIsExport(sheet))
                                {
                                    new DataToOptimizeLuaExporter(sheet, setting).Export();
                                    luaCount++;
                                }
                                else
                                {
                                    L("WARN 前端无数据可导出：" + sheet.name);
                                }
                                DataToTxtExporter.Export(sheet, setting);
                                txtCount++;
                            }
                            else
                            {
                                // 🔴 与面板一致：纯后端表**不导出**。
                                // DataHelper.GetSheet 对纯后端表直接返回空表，硬导只会把服务端
                                // txt 写成空文件（RewardItemConfig 就是这么踩过的，靠
                                // scripts/append_reward_items_to_server.py 另行补齐）。
                                serverOnly++;
                                L("SKIP 纯后端表（不导出，避免写空 txt）：" + sheet.name);
                            }
                        }
                        catch (Exception e)
                        {
                            L("FAIL 导出失败 " + sheet.name + " : " + e.Message);
                            failed++;
                        }
                    }
                }

                AssetDatabase.Refresh();
                L(string.Format("汇总：xlsx={0} lua={1} txt={2} 纯后端={3} 失败={4}",
                    excelCount, luaCount, txtCount, serverOnly, failed));
                if (failed > 0)
                {
                    L("🔴 有 " + failed + " 张表导出失败，见上方 FAIL 行");
                    rc = 3;
                }
            }
            catch (Exception e)
            {
                L("FAIL 未捕获异常：" + e);
                rc = 3;
            }
            finally
            {
                FlushLog();
            }
            if (rc != 0) EditorApplication.Exit(rc);
        }

        /// <summary>
        /// 重建 AssetBundle 并复制到 StreamingAssets（= GUI「整体打包资源」+「复制资源到流媒体目录」）。
        /// 返回码：0 成功；3 失败
        /// </summary>
        public static void BuildAllABs()
        {
            Buffer.Clear();
            int rc = 0;
            try
            {
                L("== 整体打包资源（BuildGameAssetBundles）==");
                // ⚠️ 必须 global::：本文件在 GameEditor.Core.DataConfig 里，写 GameEditor.FrameTool
                // 会被解析成 GameEditor.GameEditor.FrameTool（2026-10-20 首次跑就编译失败）。
                global::GameEditor.FrameTool.FrameTool.BuildGameAssetBundles();
                L("== 复制资源到流媒体目录（CopyAssetBundleToStreamingAssets）==");
                global::GameEditor.FrameTool.FrameTool.CopyAssetBundleToStreamingAssets();
                L("== 完成 ==");
            }
            catch (Exception e)
            {
                L("FAIL AB 构建异常：" + e);
                rc = 3;
            }
            finally
            {
                FlushLog();
            }
            if (rc != 0) EditorApplication.Exit(rc);
        }
    }
}
