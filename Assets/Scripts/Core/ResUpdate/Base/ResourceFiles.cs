using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UnityEngine;
namespace ResUpdate
{
    /// <summary>
    /// 资源文件
    /// </summary>
    [Serializable]
    public class ResourceFiles : ScriptableObject
    {
        public List<ResourceFile> files;
        public string version;
    }

    /// <summary>
    /// 资源文件
    /// </summary>
    [Serializable]
    public class ResourceFile
    {
        /// <summary>
        /// id
        /// </summary>
        public int id;
        /// <summary>
        /// 文件名
        /// </summary>
        public string fileName;
        /// <summary>
        /// crc
        /// </summary>
        public string crc;
        /// <summary>
        /// 文件大小
        /// </summary>
        public long size;

        public ResourceFile() { }

        public ResourceFile(string fileName, string crc)
        {
            this.fileName = fileName;
            this.crc = crc;
        }


        public override string ToString()
        {
            return string.Format("id:{0},fileName:{1},crc:{2},size:{3}",id,fileName,crc,size);
        }
    }
}
