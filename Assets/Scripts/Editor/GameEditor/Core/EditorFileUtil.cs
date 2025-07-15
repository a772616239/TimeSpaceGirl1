using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
namespace GameEditor.Core
{
    public static class EditorFileUtil
    {
        /// <summary>
        /// 创建目录
        /// </summary>
        /// <param name="path"></param>
        /// <param name="force"></param>
        public static void CreateDirectory(string path,bool force) {
            if (Directory.Exists(path))
            {
                if (force)
                {
                    Directory.Delete(path);
                    Directory.CreateDirectory(path);
                }
            }
            else {
                Directory.CreateDirectory(path);
            }
        }


    }
}
