using ICSharpCode.SharpZipLib.Zip;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Text;
using System.Xml;

namespace GameEditor.Core.DataConfig
{
    public class DataHelper
    {
        public static DataSheet GetSheet(string filePath)
        {
            DataSheet sheet = new DataSheet();
            using (var stream = File.Open(filePath.Replace("\\", "/"), FileMode.Open, FileAccess.Read))
            {
                using (var excelReader = new ZipWorker(stream).GetWorksheetReader())
                {
                    sheet.name = Path.GetFileNameWithoutExtension(filePath);

                    //System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
                    //time.Start();

                    int fieldCount = 0;
                    string item;

                    int rowsNum = 0;
                    foreach (var cellDic in excelReader.Read())
                    {
                        rowsNum++;
                        if (rowsNum == 1)
                        {
                            foreach (var kvp in cellDic)
                            {
                                if (fieldCount < kvp.Key + 1)
                                {
                                    fieldCount = kvp.Key + 1;
                                }
                            }
                        }
                        else if (rowsNum == 3)
                        {
                            bool isServer = true;
                            for (int i = 0; i < fieldCount; i++)
                            {
                                if (cellDic.ContainsKey(i))
                                {
                                    if (i > 0 && (cellDic[i] == "2" || cellDic[i] == "3"))
                                    {
                                        isServer = false;
                                    }
                                }
                            }
                            if (isServer)
                            {
                                //UnityEngine.Debug.LogError("純后端表：" + sheet.name);
                                return sheet;
                            }
                        }
                        for (int i = 0; i < fieldCount; i++)
                        {
                            if (cellDic.ContainsKey(i))
                            {
                                item = cellDic[i];
                            }
                            else
                            {
                                item = string.Empty;
                            }
                            if (i > 0)
                            {
                                if (rowsNum >= 1 && rowsNum <= 7)
                                {
                                    if (rowsNum == 1)
                                    {
                                        sheet.fields.Add(new DataField(i, i == 1));
                                    }
                                    if (i - 1 < sheet.fields.Count)
                                    {
                                        sheet.fields[i - 1].SetFiledValue(rowsNum - 1, item);
                                    }
                                }
                                else
                                {
                                    List<string> line = null;
                                    if (i == 1)
                                    {
                                        if (string.IsNullOrEmpty(item))
                                        {
                                            break;
                                        }
                                        line = new List<string>();
                                        sheet.lines.Add(line);
                                    }
                                    else
                                    {
                                        line = sheet.lines[sheet.lines.Count - 1];
                                    }
                                    line.Add(item);
                                }
                            }
                        }
                    }

                    //time.Stop();
                    //UnityEngine.Debug.LogError("耗时：" + time.ElapsedMilliseconds);
                }
            }
            return sheet;
        }

        public static string GetStrVal(string sQ, string s, string s2, System.Func<string, string, string> itemFunc)
        {
            if (sQ.StartsWith("string"))
            {
                if (string.IsNullOrEmpty(s))
                {
                    s = "nil";
                }
                else
                {
                    //> s = string.Format("'{0}'", s);
                    s = string.Format("'{0}'", s.Replace("\'", "\\\'"));
                }
            }
            return itemFunc(s, s2);
        }
      
        public static string GetValueString(DataField field, string content, System.Func<string, string, string> itemFunc)
        {
            StringBuilder sb = new StringBuilder();        
            if (string.IsNullOrEmpty(content))
            {
                sb.Append(itemFunc("nil", null));
            }
            else
            {
                switch (field.fieldType)
                {
                    case DataFieldType.Bool:
                    case DataFieldType.Float:
                    case DataFieldType.Int:
                    case DataFieldType.Long:
                    case DataFieldType.Double:
                    case DataFieldType.Ref:
                        sb.Append(itemFunc(content.ToLower(), null));
                        break;
                    case DataFieldType.Battle:
                    case DataFieldType.String:
                    case DataFieldType.Stringt:
                    case DataFieldType.Res:
                        sb.Append(GetStrVal("string", content, null, itemFunc));
                        break;
                    case DataFieldType.Mut:
                        {
                            sb.Append("{");
                            if (field.extType == 1)
                            {
                                string[] val = content.Split('#');
                                for (int i = 0; i < val.Length; i++)
                                {
                                    sb.Append(GetStrVal(field.ext, val[i], string.Format("{{{0}}}", i + 1), itemFunc));
                                    if (i < val.Length - 1)
                                    {
                                        sb.Append(",");
                                    }
                                }
                            }
                            else if (field.extType == 2)
                            {
                                string[] val_1 = content.Split('|');
                                for (int i = 0; i < val_1.Length; i++)
                                {
                                    sb.Append("{");
                                    string[] val_2 = val_1[i].Split('#');
                                    for (int j = 0; j < val_2.Length; j++)
                                    {
                                        sb.Append(GetStrVal(field.ext, val_2[j], string.Format("{{{0},{1}}}", i + 1, j + 1), itemFunc));
                                        if (j < val_2.Length - 1)
                                        {
                                            sb.Append(",");
                                        }
                                    }
                                    sb.Append("}");
                                    if (i < val_1.Length - 1)
                                    {
                                        sb.Append(",");
                                    }
                                }
                            }
                            else if (field.extType == 3)
                            {
                                string[] val_1 = content.Split(',');
                                for (int i = 0; i < val_1.Length; i++)
                                {
                                    sb.Append("{");
                                    string[] val_2 = val_1[i].Split('|');
                                    for (int j = 0; j < val_2.Length; j++)
                                    {
                                        sb.Append("{");
                                        string[] val_3 = val_2[j].Split('#');
                                        for (int m = 0; m < val_3.Length; m++)
                                        {
                                            sb.Append(GetStrVal(field.ext, val_3[m], string.Format("{{{0},{1},{2}}}", i + 1, j + 1, m + 1), itemFunc));
                                            if (m < val_3.Length - 1)
                                            {
                                                sb.Append(",");
                                            }
                                        }
                                        sb.Append("}");
                                        if (j < val_2.Length - 1)
                                        {
                                            sb.Append(",");
                                        }
                                    }
                                    sb.Append("}");
                                    if (i < val_1.Length - 1)
                                    {
                                        sb.Append(",");
                                    }
                                }
                            }
                            sb.Append("}");
                        }
                        break;
                }
            }           
            return sb.ToString();
        }

        public static string GetValByDefault(string val,string defaultVal, DataFieldType dataFieldType)
        {
            if(!string.IsNullOrEmpty(val))
            {
                return val;
            }
            if(!string.IsNullOrEmpty(defaultVal))
            {
                return defaultVal;
            }
            string result = "nil";
            switch(dataFieldType)
            {
                case DataFieldType.Int:
                case DataFieldType.Float:
                case DataFieldType.Double:
                case DataFieldType.Long:
                    result = "0";
                    break;
                case DataFieldType.Bool:
                    result = "false";
                    break;
                case DataFieldType.String:
                    result = "";
                    break;
            }
            return result;
        }
        public static string GetClientValByDefault(string val, string defaultVal, DataFieldType dataFieldType)
        {
            if (!string.IsNullOrEmpty(val))
            {
                return val;
            }
            if (!string.IsNullOrEmpty(defaultVal))
            {
                return defaultVal;
            }
            string result = "";
            switch (dataFieldType)
            {
                case DataFieldType.Int:
                case DataFieldType.Float:
                case DataFieldType.Double:
                case DataFieldType.Long:
                    result = "0";
                    break;
                case DataFieldType.Bool:
                    result = "false";
                    break;
            }
            return result;
        }
    }
}

internal static class XmlReaderHelper
{
    private const string NsSpreadsheetMl = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private const string ElementT = "t";
    private const string ElementR = "r";

    public static bool ReadFirstContent(XmlReader xmlReader)
    {
        if (xmlReader.IsEmptyElement)
        {
            xmlReader.Read();
            return false;
        }

        xmlReader.MoveToContent();
        xmlReader.Read();
        return true;
    }

    public static bool SkipContent(XmlReader xmlReader)
    {
        if (xmlReader.NodeType == XmlNodeType.EndElement)
        {
            xmlReader.Read();
            return false;
        }

        xmlReader.Skip();
        return true;
    }

    public static string ReadStringItem(XmlReader reader)
    {
        if (!ReadFirstContent(reader)) return string.Empty;
        StringBuilder sb = new StringBuilder();
        while (!reader.EOF)
        {
            if (reader.IsStartElement(ElementT, NsSpreadsheetMl))
            {
                // There are multiple <t> in a <si>. Concatenate <t> within an <si>.
                sb.Append(reader.ReadElementContentAsString());
            }
            else if (reader.IsStartElement(ElementR, NsSpreadsheetMl))
            {
                if (ReadFirstContent(reader)) //ReadRichTextRun
                {
                    while (!reader.EOF)
                    {
                        if (reader.IsStartElement(ElementT, NsSpreadsheetMl))
                        {
                            sb.Append(reader.ReadElementContentAsString());
                        }
                        else if (!SkipContent(reader))
                        {
                            break;
                        }
                    }
                }
            }
            else if (!SkipContent(reader))
            {
                break;
            }
        }
        return sb.ToString();
    }
}

internal sealed class XmlWorksheetReader : IDisposable
{
    private const string NsSpreadsheetMl = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

    private const string NWorksheet = "worksheet";
    private const string NSheetData = "sheetData";
    private const string NRow = "row";
    private const string ARef = "ref";
    private const string AR = "r";
    private const string NV = "v";
    private const string NIs = "is";
    private const string AT = "t";
    private const string AS = "s";

    private const string NC = "c"; // cell
    private const string NInlineStr = "inlineStr";
    private const string NStr = "str";

    private XmlReader Reader;
    private Dictionary<string, string> SST;

    public XmlWorksheetReader(XmlReader reader, Dictionary<string, string> sst)
    {
        Reader = reader;
        SST = sst;
    }

    private Dictionary<int, string> cell = new Dictionary<int, string>();
    public IEnumerable<Dictionary<int, string>> Read()
    {
        if (!Reader.IsStartElement(NWorksheet, NsSpreadsheetMl))
        {
            yield break;
        }

        if (!XmlReaderHelper.ReadFirstContent(Reader))
        {
            yield break;
        }

        while (!Reader.EOF)
        {
            if (Reader.IsStartElement(NSheetData, NsSpreadsheetMl))
            {
                if (!XmlReaderHelper.ReadFirstContent(Reader))
                {
                    continue;
                }
                while (!Reader.EOF)
                {
                    if (Reader.IsStartElement(NRow, NsSpreadsheetMl))
                    {
                        if (!XmlReaderHelper.ReadFirstContent(Reader))
                        {
                            continue;
                        }
                        int columnIndex = 0;
                        cell.Clear();
                        while (!Reader.EOF)
                        {
                            if (Reader.IsStartElement(NC, NsSpreadsheetMl))
                            {
                                var item = ReadCell(ref columnIndex);
                                if (item != null)
                                {
                                    cell[columnIndex] = item;
                                }
                                //cell[columnIndex] = item ?? "";
                            }
                            else if (!XmlReaderHelper.SkipContent(Reader))
                            {
                                break;
                            }
                        }
                        if (cell.Count > 0)
                            yield return cell;
                    }
                    else if (!XmlReaderHelper.SkipContent(Reader))
                    {
                        break;
                    }
                }
            }
            else if (!XmlReaderHelper.SkipContent(Reader))
            {
                break;
            }
        }
    }
   
    /// <summary>
    /// Logic for the Excel dimensions. Ex: A15
    /// </summary>
    /// <param name="value">The value.</param>
    /// <param name="column">The column, 1-based.</param>
    /// <param name="row">The row, 1-based.</param>
    public static bool ParseReference(string value, out int column)
    {
        column = 0;
        var position = 0;
        const int offset = 'A' - 1;

        if (value != null)
        {
            while (position < value.Length)
            {
                var c = value[position];
                if (c >= 'A' && c <= 'Z')
                {
                    position++;
                    column *= 26;
                    column += c - offset;
                    continue;
                }

                if (char.IsDigit(c))
                    break;

                position = 0;
                break;
            }
        }

        if (position == 0)
        {
            column = 0;
            return false;
        }
        return true;
    }

    private string ReadCell(ref int columnIndex)
    {
        var aT = Reader.GetAttribute(AT);
        int referenceColumn;
        if (ParseReference(Reader.GetAttribute(AR), out referenceColumn))
            columnIndex = referenceColumn - 1; // ParseReference is 1-based

        if (!XmlReaderHelper.ReadFirstContent(Reader))
        {
            //UnityEngine.Debug.LogError("XmlReaderHelper");
            return null;
        }

        string rawValue = null;
        while (!Reader.EOF)
        {

            if (aT == NInlineStr && Reader.IsStartElement(NIs, NsSpreadsheetMl))
            {
                if (!XmlReaderHelper.ReadFirstContent(Reader))
                {
                    continue;
                }
                while (!Reader.EOF)
                {
                    if (Reader.IsStartElement(AT))
                    {

                        rawValue = Reader.ReadElementContentAsString();

                        if (Reader.NodeType == XmlNodeType.EndElement)
                        {
                            // 这里要读两次跳出<is>和<t>两个标签
                            Reader.Read();
                            Reader.Read();
                        }
                        return rawValue;
                    }
                    else if (!XmlReaderHelper.SkipContent(Reader))
                    {
                        break;
                    }
                }
            }
            else if (Reader.IsStartElement(NV, NsSpreadsheetMl))
            {
                if (aT == AS)
                {
                    rawValue = SST[Reader.ReadElementContentAsString()];
                }
                else if (aT == NStr || aT == NInlineStr)
                {
                    rawValue = Reader.ReadElementContentAsString();
                }
                else if (aT == "b")
                {
                    rawValue = Reader.ReadElementContentAsString() == "1" ? "true" : "false";
                }
                else if (aT == "e")
                {
                }
                else
                {
                    var s = Reader.ReadElementContentAsString();
                    if (s.Length >= 16)
                    {
                        double d;
                        if (double.TryParse(s, out d))
                        {
                            s = d.ToString();
                        }
                    }
                    rawValue = s;
                }
                if (Reader.NodeType == XmlNodeType.EndElement)
                {
                    Reader.Read();
                }
                //XmlReaderHelper.SkipContent(Reader);
                return rawValue;
            }
            else if (!XmlReaderHelper.SkipContent(Reader))
            {
                break;
            }
        }
        return rawValue;
    }  

    public void Dispose()
    {
        Reader.Close();
    }
}


internal sealed class ZipArchiveEntry
{
    private readonly ZipFile _handle;
    private readonly ZipEntry _entry;

    internal ZipArchiveEntry(ZipFile handle, ZipEntry entry)
    {
        _handle = handle;
        _entry = entry;
    }

    public string FullName
    {
        get
        {
            return _entry.Name;
        }
    }

    public Stream Open()
    {
        return _handle.GetInputStream(_entry);
    }
}

internal sealed class ZipArchive : IDisposable
{
    private readonly ZipFile _handle;

    public ZipArchive(Stream stream)
    {
        if (stream.CanSeek)
        {
            _handle = new ZipFile(stream);
        }
        else
        {
            // Password protected xlsx using "Standard Encryption" come as a non-seekable CryptoStream.
            // Must wrap in a MemoryStream to load
            var memoryStream = ReadToMemoryStream(stream);
            _handle = new ZipFile(memoryStream);
        }

        var entries = new List<ZipArchiveEntry>();
        foreach (ZipEntry entry in _handle)
            entries.Add(new ZipArchiveEntry(_handle, entry));
        Entries = new ReadOnlyCollection<ZipArchiveEntry>(entries);
    }

    public ReadOnlyCollection<ZipArchiveEntry> Entries;

    public void Dispose()
    {
        if(_handle is IDisposable)
        {
            (_handle as IDisposable).Dispose();
        }
    }

    private static MemoryStream ReadToMemoryStream(Stream input)
    {
        byte[] buffer = new byte[16 * 1024];
        int read;
        var ms = new MemoryStream();
        while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
        {
            ms.Write(buffer, 0, read);
        }

        ms.Position = 0;
        return ms;
    }
}

internal partial class ZipWorker : IDisposable
{
    private const string FileSharedStrings = "xl/sharedStrings.{0}";
    private const string FileWorksheet = "xl/worksheets/sheet1.{0}";
    private const string Format = "xml";

    private const string NsSpreadsheetMl = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private const string ElementSst = "sst";
    private const string ElementStringItem = "si";

    private static readonly XmlReaderSettings XmlSettings = new XmlReaderSettings
    {
        IgnoreComments = true,
        IgnoreWhitespace = true,
        XmlResolver = null,
    };

    private readonly Dictionary<string, ZipArchiveEntry> _entries;
    private bool _disposed;
    private Stream _zipStream;
    private ZipArchive _zipFile;

    ~ZipWorker()
    {
        Dispose(false);
    }

    public void Dispose()
    {
        Dispose(true);

        GC.SuppressFinalize(this);
    }

    private void Dispose(bool disposing)
    {
        // Check to see if Dispose has already been called.
        if (!_disposed)
        {
            if (disposing)
            {
                if (_zipFile != null)
                {
                    _zipFile.Dispose();
                    _zipFile = null;
                }

                if (_zipStream != null)
                {
                    _zipStream.Dispose();
                    _zipStream = null;
                }
            }

            _disposed = true;
        }
    }
    /// <summary>
    /// Initializes a new instance of the <see cref="ZipWorker"/> class. 
    /// </summary>
    /// <param name="fileStream">The zip file stream.</param>
    public ZipWorker(Stream fileStream)
    {
        _zipStream = fileStream;
        _zipFile = new ZipArchive(fileStream);
        _entries = new Dictionary<string, ZipArchiveEntry>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in _zipFile.Entries)
        {
            _entries.Add(entry.FullName.Replace('\\', '/'), entry);
        }
    }

    public XmlWorksheetReader GetWorksheetReader()
    {
        var zipEntry = FindEntry(string.Format(FileWorksheet, Format));
        if (zipEntry != null)
        {
            return new XmlWorksheetReader(XmlReader.Create(zipEntry.Open(), XmlSettings), GetSharedStringsReader());
        }
        return null;
    }

    /// <summary>
    /// Gets the shared strings reader.
    /// </summary>
    public Dictionary<string, string> GetSharedStringsReader()
    {
        var entry = FindEntry(string.Format(FileSharedStrings, Format));
        if (entry != null)
        {
            var reader = XmlReader.Create(entry.Open(), XmlSettings);
            var SST = new Dictionary<string, string>();
            if (!reader.IsStartElement(ElementSst, NsSpreadsheetMl))
            {
                return SST;
            }

            if (!XmlReaderHelper.ReadFirstContent(reader))
            {
                return SST;
            }

            while (!reader.EOF)
            {
                if (reader.IsStartElement(ElementStringItem, NsSpreadsheetMl))
                {
                    SST.Add(SST.Count.ToString(), XmlReaderHelper.ReadStringItem(reader));
                }
                else if (!XmlReaderHelper.SkipContent(reader))
                {
                    break;
                }
            }
            return SST;
        }
        return null;
    }

    private ZipArchiveEntry FindEntry(string name)
    {
        ZipArchiveEntry entry;
        if (_entries.TryGetValue(name, out entry))
            return entry;
        return null;
    }
}






