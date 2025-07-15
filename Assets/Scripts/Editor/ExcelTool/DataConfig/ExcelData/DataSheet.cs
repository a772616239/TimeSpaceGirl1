using System.Collections.Generic;

namespace GameEditor.Core.DataConfig
{
    public class DataSheet
    {
        public string name;
        public List<DataField> fields;
        public List<List<string>> lines;

        public DataSheet()
        {
            fields = new List<DataField>();
            lines = new List<List<string>>();
        }

        public bool Verify(DataSheet sheet,out string msg)
        {
            msg = null;
            if(!VerifyField())
            {
                return false;
            }
            return true;
        }

        private bool VerifyField()
        {
            Dictionary<string, bool> fieldDic = new Dictionary<string, bool>();
            foreach(DataField df in fields)
            {
                if(fieldDic.ContainsKey(df.name))
                {
                    return false;
                }
                else
                {
                    fieldDic.Add(df.name, true);
                }
            }
            return true;
        }
    }
}
