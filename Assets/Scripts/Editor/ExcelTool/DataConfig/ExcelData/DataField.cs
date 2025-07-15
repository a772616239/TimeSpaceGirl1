using System;
using System.Collections.Generic;
using System.Text;

namespace GameEditor.Core.DataConfig
{
    public enum DataFieldType
    {
        None = 'n',
        Int = 'i',
        Float = 'f',
        Double = 'd',
        Long = 'l',
        Bool = 'b',
        String = 's',
        Stringt = 't',
        Ref = 'r',
        Mut = 'm',
        Res = 'u',
        Battle = 'a',
        Max = Res+1,
    }

    [Flags]
    public enum DataFieldExportType
    {
        None = 0,
        Unexport = 1,
        All = 2,
        Client = 3,
        Server = 4,
    }

    [Flags]
    public enum DataFieldValidationType
    {
        None = 0,
        NeverRepeat = 1 << 0,
        NeverNull = 1 << 1,
        StrLengthMax = 1 << 2,
        NumberRange = 1 << 3,
        Resource = 1 << 4,
        NeverDefault = 1<<5,
        MutRelate = 1<<6,
    }

    public class DataField
    {
        private delegate void SetValue(string str);

        public int columnIndex = -1;
        public bool isFirstField = false;

        public string name = null;
        public DataFieldType fieldType = DataFieldType.None;
        public string refName;
        public string ext;
        public int extType;
        //public DataField childField;
        public DataFieldExportType exportType = DataFieldExportType.None;
        public string desc = null;
        public DataFieldValidationType validationType = DataFieldValidationType.None;
        public string validationValue = null;
        public string defaultContent = null;

        private List<SetValue> setList = null;
        public DataField(int colIndex,bool isFirst = false)
        {
            columnIndex = colIndex;
            isFirstField = false;
            setList = new List<SetValue>()
            {
                SetName,
                SetFieldType,
                SetExportType,
                SetDesc,
                SetDefault,
                SetValidationType,
                SetValidationValue,
            };
        }

        public void SetFiledValue(int rowIndex,string value)
        {
            setList[rowIndex](value);
        }

        private void SetName(string str)
        {
            name = str;
        }

        private void SetDesc(string str)
        {
            desc = str;
        }

        private void SetDefault(string str)
        {
            defaultContent = str;
        }

        private void SetValidationValue(string str)
        {
            validationValue = str;
        }

        private string fieldTypeStr;
        public string FieldTypeStr
        {
            get
            {
                return fieldTypeStr;
            }
        }
        private void SetFieldType(string fieldTypeStr)
        {
            this.fieldTypeStr = fieldTypeStr;
            if (!string.IsNullOrEmpty(fieldTypeStr))
            {
                string fType = "";
                string[] splitStrs = null;

                int indexSplit = fieldTypeStr.IndexOf(",");
                if (indexSplit>0)
                {
                    splitStrs = fieldTypeStr.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    fType = splitStrs[0];
                }else
                {
                    fType = fieldTypeStr;
                }
                try
                {
                    fieldType = (DataFieldType)Enum.Parse(typeof(DataFieldType), fType, true);
                }catch
                {
                    fieldType = DataFieldType.None;
                    return;
                }

                if(fieldType == DataFieldType.Ref && splitStrs.Length == 2)
                {
                    refName = splitStrs[1];
                }else if(fieldType == DataFieldType.Res && splitStrs.Length == 2)
                {
                    ext = splitStrs[1];
                }else if(fieldType == DataFieldType.Mut && splitStrs.Length == 3)
                {
                    ext = splitStrs[1];
                    extType = int.Parse(splitStrs[2]);
                }
            }
        }

        private void SetExportType(string exportTypeStr)
        {
            if(string.IsNullOrEmpty(exportTypeStr))
            {
                return;
            }
            try
            {
                int epInt = int.Parse(exportTypeStr);
                if (Enum.IsDefined(typeof(DataFieldExportType), epInt))
                {
                    exportType = (DataFieldExportType)epInt;
                }
            }
            catch
            {

            }
        }

        private void SetValidationType(string validationTypeStr)
        {
            if (string.IsNullOrEmpty(validationTypeStr))
            {
                return;
            }
            try
            {
                int vInt = int.Parse(validationTypeStr);
                if (Enum.IsDefined(typeof(DataFieldValidationType), vInt))
                {
                    validationType = (DataFieldValidationType)vInt;
                }
            }
            catch
            {

            }
        }

        public DataFieldType FieldRealType()
        {
            return fieldType;
        }

        public bool Verify(DataSheet sheet,out string msg)
        {
            msg = null;
            //LogMsgMgr MsgMgr = LogMsgMgr.GetInstance();
            //if(string.IsNullOrEmpty(name))
            //{
            //    return false;
            //}
            //string nameReg = @"^[A-Z][A-Za-z0-9]{1,9}";
            //if(!Regex.IsMatch(name,nameReg))
            //{
            //    MsgMgr.Add(new ErrorLogData2(LogConst.E_DataField_NameFormat, ""+columnIndex,name));
            //    return false;
            //}
            //if(isFirstField && name!="ID")
            //{
            //    MsgMgr.Add(new ErrorLogData(LogConst.E_DataField_ID));
            //    return false;
            //}
            //if(FieldType == DataFieldType.None)
            //{
            //    MsgMgr.Add(new ErrorLogData2(LogConst.E_DataField_TypeNone, "" + columnIndex, name));
            //    return false;
            //}
            //if(FieldType == DataFieldType.Ref && string.IsNullOrEmpty(refName))
            //{
            //    MsgMgr.Add(new ErrorLogData1(LogConst.E_DataField_ResType, name));
            //    return false;
            //}else if(FieldType == DataFieldType.Mut )
            //{
            //    if(RefFieldType == DataFieldType.None)
            //    {
            //        MsgMgr.Add(new ErrorLogData1(LogConst.E_DataField_MutType, name));
            //        return false;
            //    }else if(string.IsNullOrEmpty(ext) || ext.Length>1)
            //    {
            //        MsgMgr.Add(new ErrorLogData1(LogConst.E_DataField_MutExt, name));
            //        return false;
            //    }
            //}
            //if(!string.IsNullOrEmpty(defaultContent))
            //{
            //    if (FieldType != DataFieldType.Mut)
            //    {
            //        if (!DataHelper.IsValidData(defaultContent, FieldType))
            //        {
            //            MsgMgr.Add(new ErrorLogData1(LogConst.E_DataField_DefaultParse,  name));
            //            return false;
            //        }
            //    }
            //    else
            //    {
            //        string[] splitContent = defaultContent.Split(new char[] { ext[0] }, StringSplitOptions.RemoveEmptyEntries);
            //        foreach(string sc in splitContent)
            //        {
            //            if(!DataHelper.IsValidData(sc,RefFieldType))
            //            {
            //                MsgMgr.Add(new ErrorLogData1(LogConst.E_DataField_DefaultParse, name));
            //                return false;
            //            }
            //        }
            //    }
            //}
            
            return true;
        }

        public override string ToString()
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("(index = " + columnIndex + ",");
            sb.Append("name = " + name + ",");
            sb.Append("type = " + fieldType + ",");
            sb.Append("export = " + exportType + ",");
            sb.Append("desc = " + desc + ",");
            sb.Append("validation = " + validationType + ",");
            sb.Append("validationValue = " + validationValue + ",");
            sb.Append("default = " + defaultContent + ",");
            sb.Append("refName = " + refName + ",");
            sb.Append("ext = " + ext + ")");
            return sb.ToString();
        }
    }
}
