using System.Linq;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace GameEditor.Core.DataConfig
{
    public class DataToOptimizeLuaExporter
    {
        private DataSheet dataSheet;
        private DataConfigSetting setting;
        public DataToOptimizeLuaExporter(DataSheet sheet, DataConfigSetting setting)
        {
            dataSheet = sheet;
            this.setting = setting;
            summary = new DataToOptimizeLuaSummary(dataSheet);
            CreateSummary();
        }

        public static bool CheckIsExport(DataSheet sheet)
        {
            int count = 0;
            for (int i = 0; i < sheet.fields.Count; i++)
            {
                DataField dfInfo = sheet.fields[i];
                if (dfInfo.exportType == DataFieldExportType.None
                    || dfInfo.exportType == DataFieldExportType.Server
                    || dfInfo.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                count++;
            }
            return count > 0;
        }

        private DataToOptimizeLuaSummary summary;

        private void CreateSummary()
        {
            for (int i = 0; i < dataSheet.fields.Count; i++)
            {
                DataField dfInfo = dataSheet.fields[i];
                if (dfInfo.exportType == DataFieldExportType.None
                    || dfInfo.exportType == DataFieldExportType.Server
                    || dfInfo.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                summary.fields.Add(dfInfo);
                summary.fieldIndexs.Add(i);
            }
        }

        public void Export()
        {
            string dirPath = setting.clientOutputDir;
            if (!Directory.Exists(dirPath))
            {
                Directory.CreateDirectory(dirPath);
            }

            summary.Export(dataSheet.name, dirPath);

            string subDirPath = dirPath + "/" + dataSheet.name;

            if (Directory.Exists(subDirPath))
            {
                Directory.Delete(subDirPath, true);
            }
        }
    }

    public class DataToOptimizeLuaSummary
    {
        public DataSheet dataSheet;
        public List<DataField> fields = new List<DataField>();
        public List<int> fieldIndexs = new List<int>();

        public DataToOptimizeLuaSummary(DataSheet dataSheet)
        {
            this.dataSheet = dataSheet;
        }

        public void Export(string name, string dirPath)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendFormat("local {0} = {{\n", name);

            Dictionary<string, int> IdDic = new Dictionary<string, int>();
            List<string> Ids = new List<string>();

            for (int i = 0; i < dataSheet.lines.Count; i++)
            {
                DataField dfInfo = fields[0];
                var cell = dataSheet.lines[i][0];
                string data = DataHelper.GetClientValByDefault(cell, dfInfo.defaultContent, dfInfo.fieldType);

                if (!string.IsNullOrEmpty(data))
                {
                    if (!IdDic.ContainsKey(data))
                    {
                        Ids.Add(data);
                        IdDic[data] = i;
                    }
                    else
                    {
                        UnityEngine.Debug.LogError("存在重复的id！ Config :" + name + " id:" + data + " orgin Line:" + (IdDic[data] + 8) + " error Line:" + (i + 8));
                    }
                }
            }

            dataSheet.lines.Sort((c1, c2) =>
            {
                int i1 = int.Parse(c1[0]);
                int i2 = int.Parse(c2[0]);
                return i1 - i2;
            });

            sb.AppendFormat("__count = {0},\n", Ids.Count);

            List<string> ids = new List<string>();
            List<string> idslz = new List<string>();
            for (int i = 0; i < Ids.Count; i++)
            {
                DataField dfInfo = fields[0];
                var cell = dataSheet.lines[IdDic[Ids[i]]][0];
                string data = DataHelper.GetClientValByDefault(cell, dfInfo.defaultContent, dfInfo.fieldType);
                ids.Add(data);
            }
            CalLz77List(ids, ref idslz);

            sb.Append("__indexs = {");
            for (int i = 0; i < idslz.Count; i++)
            {
                sb.AppendFormat("{0},", idslz[i]);
            }
            if (idslz.Count > 0) sb.Remove(sb.Length - 1, 1);
            sb.AppendLine("},");

            Dictionary<string, int> record = new Dictionary<string, int>();
            for (int i = 0; i < fields.Count - 1; i++)
            {
                DataField dfInfo = fields[i + 1];
                List<string> list = new List<string>();
                for (int j = 0; j < Ids.Count; j++)
                {
                    var cell = dataSheet.lines[IdDic[Ids[j]]][fieldIndexs[i + 1]];
                    list.Add(DataHelper.GetClientValByDefault(cell, dfInfo.defaultContent, dfInfo.fieldType));
                }

                List<string> d = new List<string>();
                List<string> d_idx = new List<string>();
                string dflt = null;
                int ntimes = CalDedaultList(list, ref dflt, ref d, ref d_idx);

                if (dflt != null)
                {
                    DataHelper.GetValueString(dfInfo, dflt, (s, s1) =>
                    {
                        int nn;
                        if (int.TryParse(s, out nn))
                        {
                            record[s] = nn;
                        }
                        else
                        {
                            if (!record.ContainsKey(s))
                            {
                                record[s] = 1;
                            }
                            else
                            {
                                record[s]--;
                            }
                        }
                        return s;
                    });
                }
                for (int j = 0; j < d.Count; j++)
                {
                    DataHelper.GetValueString(dfInfo, d[j], (s, s1) =>
                    {
                        int nn;
                        if (int.TryParse(s, out nn))
                        {
                            record[s] = nn;
                        }
                        else
                        {
                            if (!record.ContainsKey(s))
                            {
                                record[s] = 1;
                            }
                            else
                            {
                                record[s]--;
                            }
                        }
                        return s;
                    });
                }
            }
            int n;

            var dicSort = from objDic in record orderby objDic.Value ascending select objDic;
            Dictionary<string, int> ItemIndex = new Dictionary<string, int>();
            int index = 0;

            List<string> values = new List<string>();
            List<string> values_item = new List<string>();
            foreach (KeyValuePair<string, int> kvp in dicSort)
            {
                if (int.TryParse(kvp.Key, out n))
                {
                    ItemIndex[kvp.Key] = ++index;
                    values.Add(kvp.Key);
                }
            }
            CalLz77List(values, ref values_item);

            sb.Append("__values = {");
            for (int i = 0; i < values_item.Count; i++)
            {
                sb.AppendFormat("{0},", values_item[i]);
            }
            if (values_item.Count > 0) sb.Remove(sb.Length - 1, 1);
            sb.AppendLine("},");

            if (values.Count < record.Count)
            {
                sb.AppendFormat("__exVals = {{{0},", record.Count - values.Count);
                foreach (KeyValuePair<string, int> kvp in dicSort)
                {
                    if (!int.TryParse(kvp.Key, out n))
                    {
                        var st = kvp.Key;
                        double d;
                        if (double.TryParse(st, out d) && (int)d == 0)
                        {
                            sb.Append(string.Format("{0},", st.Replace("0.", ".")));
                        }
                        else
                        {
                            sb.Append(string.Format("{0},", st));
                        }
                        ItemIndex[kvp.Key] = ++index;
                    }
                }
                sb.Remove(sb.Length - 1, 1);
                sb.AppendLine("},");
            }

            List<List<string>> lineRefs = new List<List<string>>();
            List<string> lineDflt = new List<string>();
            List<List<string>> lineDL_idx = new List<List<string>>();
            List<Dictionary<string, Dictionary<int, string>>> ref_tbs = new List<Dictionary<string, Dictionary<int, string>>>();
            List<List<string>> lineTb_idx = new List<List<string>>();

            for (int i = 0; i < fields.Count - 1; i++)
            {
                List<string> list = new List<string>();
                DataField dfInfo = fields[i + 1];
                Dictionary<string, Dictionary<int, string>> tbList = new Dictionary<string, Dictionary<int, string>>();
                for (int j = 0; j < Ids.Count; j++)
                {
                    var cell = dataSheet.lines[IdDic[Ids[j]]][fieldIndexs[i + 1]];
                    string data = DataHelper.GetClientValByDefault(cell, dfInfo.defaultContent, dfInfo.fieldType);
                    if (dfInfo.fieldType != DataFieldType.Mut)
                        list.Add(DataHelper.GetValueString(dfInfo, data, (s, s1) => ItemIndex[s].ToString()));
                    else
                    {
                        list.Add(DataHelper.GetValueString(dfInfo, data, (s, s1) =>
                        {
                            var rs = ItemIndex[s].ToString();
                            if (!string.IsNullOrEmpty(s1))
                            {
                                if (!tbList.ContainsKey(s1))
                                {
                                    tbList[s1] = new Dictionary<int, string>();
                                }
                                tbList[s1][j] = rs;
                            }
                            return rs;
                        }));
                    }

                }

                List<string> d = new List<string>();
                List<string> d_item = new List<string>();
                List<string> d_idx = new List<string>();
                List<string> d_idx_item = new List<string>();
                List<string> d_tbIdx = new List<string>();

                string dflt = null;
                CalDedaultList(list, ref dflt, ref d, ref d_idx);
                lineDflt.Add(dflt);

                if (dfInfo.fieldType != DataFieldType.Mut)
                {
                    CalLz77List(d, ref d_item);
                    lineRefs.Add(d_item);
                }
                else
                {
                    for (int j = 0; j < d_idx.Count; j++) //当list引用表有默认值时，记录剔除默认值后，list引用位置
                    {
                        d_tbIdx.Add(d_idx[j]);
                    }
                    lineRefs.Add(d);
                }
                CalLz77List(d_idx, ref d_idx_item);
                lineDL_idx.Add(d_idx_item);

                ref_tbs.Add(tbList);
                lineTb_idx.Add(d_tbIdx);
            }

            sb.AppendLine("__fields = {");
            for (int i = 0; i < fields.Count; i++)
            {
                sb.AppendFormat("\t\'{0}\'", fields[i].name);
                sb.AppendLine(i != fields.Count - 1 ? "," : "");
            }
            sb.AppendLine("},");

            sb.AppendLine("__defaults = {");
            for (int i = 0; i < fields.Count - 1; i++)
            {
                var dflt = lineDflt[i];
                if (string.IsNullOrEmpty(dflt))
                {
                    sb.Append("\tnil");
                }
                else
                {
                    sb.AppendFormat("\t{0}", dflt);
                }
                sb.Append(i != fields.Count - 2 ? ",\n" : "\n");
            }
            sb.AppendLine("},");

            List<List<List<string>>> ref_tbLists = new List<List<List<string>>>();
            List<List<List<string>>> ref_tbPosLists = new List<List<List<string>>>();

            for (int i = 0; i < fields.Count - 1; i++)
            {
                DataField dfInfo = fields[i + 1];
                var d = ref_tbs[i];

                List<List<string>> tb_list = new List<List<string>>();
                List<List<string>> tbPos_list = new List<List<string>>();
                if (lineRefs[i].Count == 0 || dfInfo.fieldType != DataFieldType.Mut)
                {
                }
                else
                {
                    var keys = new List<string>(d.Keys);
                    for (int j = 0; j < keys.Count; j++)
                    {
                        var key = keys[j];
                        var kdic = d[key];

                        List<string> list = new List<string>();
                        List<string> list_item = new List<string>();

                        List<string> poslist = new List<string>();
                        List<string> poslist_item = new List<string>();

                        for (int k = 0; k < lineRefs[i].Count; k++)
                        {
                            var idx = lineTb_idx[i].Count > 0 ? int.Parse(lineTb_idx[i][k]) : k + 1; //有默认值，则读取引用表id，否则读取顺序索引
                            if (kdic.ContainsKey(idx - 1))
                            {
                                list.Add(kdic[idx - 1]);
                                if (kdic.Count < lineRefs[i].Count && kdic.Count <= (lineRefs[i].Count + 1) / 2)
                                {
                                    poslist.Add((k + 1).ToString());
                                }
                            }
                            else
                            {
                                if (kdic.Count < lineRefs[i].Count && kdic.Count > (lineRefs[i].Count + 1) / 2)
                                {
                                    poslist.Add((k + 1).ToString());
                                }
                            }
                        }

                        CalLz77List(list, ref list_item);
                        tb_list.Add(list_item);

                        CalLz77List(poslist, ref poslist_item);
                        tbPos_list.Add(poslist_item);
                    }
                }
                ref_tbLists.Add(tb_list);
                ref_tbPosLists.Add(tbPos_list);
            }

            sb.AppendLine("__refs = {");
            for (int i = 0; i < fields.Count - 1; i++)
            {
                DataField dfInfo = fields[i + 1];
                var d = lineRefs[i];
                if (d.Count == 0)
                {
                    sb.Append("\tnil");
                }
                else
                {
                    if (dfInfo.fieldType == DataFieldType.Mut)
                    {
                        var dic = ref_tbs[i];
                        var d_info = ref_tbLists[i];
                        var d_pos = ref_tbPosLists[i];
                        sb.Append("\t{");
                        var keys = new List<string>(dic.Keys);
                        for (int j = 0; j < keys.Count; j++)
                        {
                            var key = keys[j];
                            sb.AppendFormat("{{{0},{{", key);
                            var kdic = d_info[j];
                            for (int k = 0; k < kdic.Count; k++)
                            {
                                sb.AppendFormat("{0}", kdic[k]);
                                if (k < kdic.Count - 1)
                                {
                                    sb.Append(",");
                                }
                            }
                            sb.Append("}");
                            var kPos = d_pos[j];
                            if (kPos.Count > 0)
                            {
                                sb.Append(",{");
                                for (int k = 0; k < kPos.Count; k++)
                                {
                                    sb.AppendFormat("{0}", kPos[k]);
                                    if (k < kPos.Count - 1)
                                    {
                                        sb.Append(",");
                                    }
                                }
                                sb.Append("}}");
                            }
                            else
                            {
                                sb.Append("}");
                            }
                            if (j < keys.Count - 1)
                            {
                                sb.Append(",");
                            }
                        }
                        sb.Append("}");
                    }
                    else
                    {
                        sb.AppendFormat("\t{{");
                        for (int j = 0; j < d.Count; j++)
                        {
                            sb.AppendFormat("{0}", d[j]);
                            if (j < d.Count - 1)
                            {
                                sb.Append(",");
                            }
                        }
                        sb.Append("}");
                    }
                }
                sb.Append(i != fields.Count - 2 ? ",\n" : "\n");
            }
            sb.AppendLine("},");

            sb.AppendLine("__refPoss = {");
            for (int i = 0; i < fields.Count - 1; i++)
            {
                var d = lineDL_idx[i];
                if (d.Count == 0)
                {
                    sb.Append("\tnil");
                }
                else
                {
                    sb.AppendFormat("\t{{");
                    for (int j = 0; j < d.Count; j++)
                    {
                        sb.AppendFormat("{0}", d[j]);
                        if (j < d.Count - 1)
                        {
                            sb.Append(",");
                        }
                    }
                    sb.Append("}");
                }
                sb.Append(i != fields.Count - 2 ? ",\n" : "\n");
            }
            sb.AppendLine("},");

            sb.Append("}\n");
            sb.AppendFormat("return {0}", name);
            string fileContent = sb.ToString();
            File.WriteAllText(string.Format("{0}/{1}.lua", dirPath, name), fileContent);
        }

        //计算一列数据是否需要默认值
        public int CalDedaultList(List<string> dataList, ref string dflt, ref List<string> d, ref List<string> d_idx)
        {
            if (dataList.Count == 1)
            {
                dflt = dataList[0];
                return 1;
            }
            string flag = null;
            int ntimes = 0;
            for (int i = 0; i < dataList.Count; i++)
            {
                if (ntimes == 0)
                {
                    flag = dataList[i];
                    ntimes = 1;
                }
                else
                {
                    if (flag == dataList[i])
                    {
                        ntimes++;
                    }
                    else
                    {
                        ntimes--;
                    }
                }
            }

            ntimes = 0;
            for (int i = 0; i < dataList.Count; i++)
            {
                if (flag == dataList[i])
                {
                    ntimes++;
                }
            }

            //if (ntimes >= dataList.Count / 3 * 2)
            if (false)
            {
                dflt = flag;
                for (int i = 0; i < dataList.Count; i++)
                {
                    if (flag != dataList[i])
                    {
                        d.Add(dataList[i]);
                        d_idx.Add((i + 1).ToString());
                    }
                }
            }
            else
            {
                d = dataList;
            }
            return ntimes;
        }

        public void CalDeltaStringList(ref List<string> dataList)
        {
            if (dataList.Count <= 1) return;

            int odata = 0;

            try
            {
                odata = int.Parse(dataList[0]);
            }
            catch (System.Exception ex)
            {
                int a = 9;

                throw ex;
            }

            int oId = 0;
            string oData = dataList[0];
            List<string> d = new List<string>();
            d.Add(oData);

            for (int i = 1; i < dataList.Count; i++)
            {
                int item = int.Parse(dataList[i]);
                dataList[i] = (item - odata).ToString();

                if (dataList[i] == oData && item - odata >= 0)
                {
                    if (i == dataList.Count - 1)
                    {
                        d[d.Count - 1] = PrintPos(oData == "0" || oData == "1" ? oData : "-" + oData, (i - oId + 1).ToString());
                    }
                }
                else
                {
                    if (i - oId > 1)
                    {
                        d[d.Count - 1] = PrintPos(oData == "0" || oData == "1" ? oData : "-" + oData, (i - oId).ToString());
                    }
                    oData = dataList[i];
                    d.Add(oData);
                    oId = i;
                }
                odata = item;
            }
            dataList = d;
        }

        public void Match(List<string> text, Dictionary<string, List<int>> dic, int t1, ref int count, ref int off)
        {
            int t2 = 2 * t1 <= text.Count ? t1 : text.Count - t1;
            if (t1 < t2 || t2 < 2)
            {
                count = 0;
                off = -1;
                return;
            }

            int index = -1;
            int max = 0;

            if (dic.ContainsKey(text[t1]))
            {
                int q;
                bool flag;
                var qL = dic[text[t1]];
                max = 1;

                for (int i = qL.Count - 1; i >= 0; i--)
                {
                    int c = System.Math.Min(t1 - qL[i], t2);
                    q = max;
                    for (int j = max; j < c; j++)
                    {
                        if (text[j + t1] != text[j + qL[i]])
                        {
                            break;
                        }
                        else
                        {
                            q++;
                        }
                    }
                    if (q > max)
                    {
                        flag = true;
                        for (int j = 1; j < max; j++)
                        {
                            if (text[j + t1] != text[j + qL[i]])
                            {
                                flag = false;
                                break;
                            }
                        }
                        if (flag)
                        {
                            max = q;
                            index = qL[i];
                            if (max == t2)
                            {
                                count = max;
                                off = index;
                                return;
                            }
                        }
                    }
                }

                if (max > 1)
                {
                    int qLen = 0;
                    int iLen = (t1 - index).ToString().Length + 3;
                    flag = true;
                    for (int i = 0; i < max; i++)
                    {
                        qLen += text[i + index].Length + 1;
                        if (qLen > iLen)
                        {
                            flag = false;
                            break;
                        }
                    }
                    if (flag)
                    {
                        count = 0;
                        off = -1;
                        return;
                    }
                }
            }

            count = max;
            off = index;
        }

        //执行lz77压缩算法
        public void CalLz77List(List<string> dataList, ref List<string> d)
        {
            //d = dataList;
            //return;

            CalDeltaStringList(ref dataList);
            if (dataList.Count <= 1)
            {
                for (int k = 0; k < dataList.Count; k++)
                {
                    d.Add(dataList[k]);
                }
                return;
            }
            int i = 0;
            int offset = -1;
            int count = 0;

            Dictionary<string, List<int>> dic = new Dictionary<string, List<int>>();
            while (i < dataList.Count)
            {
                Match(dataList, dic, i, ref count, ref offset);
                if (count < 2)
                {
                    d.Add(dataList[i]);
                    if (!dic.ContainsKey(dataList[i]))
                    {
                        dic[dataList[i]] = new List<int>();
                    }
                    dic[dataList[i]].Add(i);
                    i++;
                }
                else
                {
                    if (i - offset == count)
                    {
                        d.Add(PrintPos(count.ToString(), "1"));
                    }
                    else
                    {
                        d.Add(PrintPos((i - offset).ToString(), count.ToString()));
                    }
                    for (int j = 0; j < count; j++)
                    {
                        if (!dic.ContainsKey(dataList[j]))
                        {
                            dic[dataList[j]] = new List<int>();
                        }
                        dic[dataList[i + j]].Add(i + j);
                    }
                    i += count;
                }
            }
        }

        //输入两个参数x,y，将y反序成z，以"x.z"形式输出
        public string PrintPos(string x, string y)
        {
            if (y.Length > 1)
            {
                char[] cArray = y.ToCharArray();
                StringBuilder reverse = new StringBuilder();
                for (int i = cArray.Length - 1; i >= 0; i--)
                {
                    reverse.Append(cArray[i]);
                }
                y = reverse.ToString();
            }
            return string.Format("{0}.{1}", x == "0" ? "" : x, y);
        }
    }
}
