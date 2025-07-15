using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

namespace CreateScript
{
    //创建代码模式
    public enum CreateMode
    {
        Csharp,
        ValueScript,
    }

    public partial class QConfigure
    {
        public static int versionIndex = 1;
        public static int version = 2;
        public static string[] versionStr = new string[] { "1", "2" };
        public static Transform selectTransform;
        public static string referencedefaultPath = "Script/UI";
        public static string referencePath;
        public static string className;
        public static bool isCreateModel = false;
        public static bool isCreateController = true;

        public static string moudleName;
        public static string netName;
        public static string netSubName;
        public static int netNum;

        public static string plugName = "QCreateScript";
        private static string assetPath = "\\Asset\\info.asset";
        public static string infoPath = "/Info/{0}_Info.json";
        private static string plugPath;
        public static string InfoPath
        {
            get
            {
                if (string.IsNullOrEmpty(plugPath))
                {
                    switch (version)
                    {
                        case 1:
                            plugPath = QFileOperation.GetAssetsDirectoryPath(plugName);
                            plugPath = plugPath.Remove(0, plugPath.IndexOf("Assets")) + assetPath;
                            break;
                        case 2:
                            plugPath = Application.persistentDataPath + infoPath;
                            break;
                    }
                }

                return plugPath;
            }
        }

        public static string switchMode = "切换{0}成功";
        public static string msgTitle = "温馨提示";
        public static string ok = "好的";
        public static string noSelect = "欧尼酱～没有选对象呢";
        public static string haveBeenCreated = "欧尼酱～脚本已创建了，点击更新哦~";
        public static string notCreate = "奥尼酱～你还没生成脚本呢";
        public static string editorCompiling = "欧尼酱～编辑器傲娇中...";
        public static string plugCreate = "欧尼酱～没有使用插件生成对应的脚本呢";
        public static string copy = "复制成功！";
        public static string noMountScript = "欧尼酱～还没挂载脚本呢～";

        public static string spine = "SpineController";
        public static string uiSpine = "SpineUIController";
        public static string loopScrollView = "\tprivate LoopScrollView\t\t              {0};\n";
        public static string findLoopScrollView = "\t\t{0} = (LoopScrollView)DLLMonoManager.instance.FindMono(\"LoopScrollView\", {1});\n";
        public static string variableFormat = "\tprivate {0,-50} {1};\n";
        public static string findFormat = "\t\t{0,-50} = GetUIComponent<{1}>(\"#{2}\");\n";
        public static string findFormat2 = "\t\t{0,-50} = values.Find{1}(\"{2}\");\n";
        public static string attributeVariableFormat = "\tprivate Q{0,-45} q{1};\n";
        public static string attributeFormat = "\tpublic {0,-50} q{1}{{get{{return {1};}}}}\n";
        public static string newAttributeFormat = "\t\tq{0,-50} = new Q{1}({0});\n";
        public static string attribute2Format = "\tpublic {0,-50} q{1}{{get{{return {1};}}}}\n";
        public static string registerFormat = "{0}.{1}.AddListener( {2} );\n";
        public static string controllerEventFormat = "\tpublic Action{0,-41} {1};\n";
        public static string functionFormat = "\n\n\tprivate void {0}({1})\n\t{{\n\t\t\n\t}}\n";
        public static string spineFormat = "\tprivate {0} {1}= new {0}();\n";
        public static string spineAssembleCode = "\t\t{0}.Assemble({1});\n";

        public static string luaVariableFormat = "this.{0} = nil\n";
        public static string luaFindFormat = "\tthis.{0} = Util.GetGameObject(self.transform, \"{1}\"){2}\n";
        public static string luaFindComponent = ":GetComponent(\"{0}\")";
        public static string luaRegisterFormat = "\tUtil.AddClick(this.{0}, {1})\n";
        public static string luaFunctionFormat = "function this:{0}()\n\nend\n\n";

        public static string registerName = "$\"{{(int){0}.{1}}}_{{(int){1}.{2}}}\"";

        public static string assignmentFormat = "\t\tui.{0,-50} = {1};\n";
        public static string declareFormat = "\tpartial void {0}({1});\n";
        public static string funFormat = "\tprivate void {0}({1})\n\t{{\n\t\t{2}({3});\n\t}}\n";

        public static string uicodeOnAwake = "\tpartial void OnAwake()\n\t{\n\n\t}";

        public static string getvalueScript = "\t\tValue_Script values = Mono.GetComponent<Value_Script>();\n";

        public static string UIFileName { get { return GetFileName("UI"); } }
        public static string UIBuildFileName { get { return GetFileName("BuildUI"); } }
        public static string ModelFileName { get { return GetFileName("Model"); } }
        public static string ControllerFileName { get { return GetFileName("Controller"); } }
        public static string ControllerBuildFileName { get { return GetFileName("BuildController"); } }

        public static string UIName { get { return GetClassName("UI"); } }
        public static string UIBuildName { get { return GetClassName("BuildUI"); } }
        public static string ModelName { get { return GetClassName("Model"); } }
        public static string ControllerName { get { return GetClassName("Controller"); } }
        public static string ControllerBuildName { get { return GetClassName("BuildController"); } }

        public static readonly string uiCode =
            "using UnityEngine;\n" +
            "using UnityEngine.UI;\n" +
            "using System;\n\n" +
            "public partial class {0}_UI :QBaseActive,IWindow\n{{\n{1}\n}}";

        public static readonly string uiCode2 =
        "using UnityEngine;\n" +
        "using UnityEngine.UI;\n" +
        "using System;\n" +
        "using FSHotfix.Common.Mono;\n" +
        "using FSHotfix.Core.Template;\n" +
        "using FSHotfix.Common.Config;\n" +
        "using FSHotfix.Core;\n" +
        "using FSHotfix.Code.Common.Utils;\n" +
        "using FSHotfix.Core.Event;\n" +
        "using System.Collections.Generic;\n" +
        "using Client;\n" +
        "using TMPro;\n\n" +
        "public partial class {0} : UIMono \n{{\n{1}\n}}  \n\n" +
        "public partial class {0} : UIMono \n{{\n{2}\n}}  "
            ;

        public static readonly string uiCode3 =
            "{0}" +
        "function this:InitComponent(){2}\nend\n\n" +
        "function this:BindEvent(){3}\nend\n\n" +
        "function this:AddListener()\nend\n\n" +
        "function this:RemoveListener()\nend\n\n" +
        "function this:OnOpen()\nend\n\n" +
        "function this:OnShow()\nend\n\n" +
        "function this:OnSortingOrderChange()\nend\n\n" +
        "function this:OnClose()\nend\n\n" +
        "function this:OnDestroy()\nend\n\n" +
        "{4}" +
        "return {5}"
            ;

        public static readonly string headUiCode1 =
             "require(\"Base/BasePanel\")\n" +
        "{0} = Inherit({0})\n" +
        "local this = {0}\n\n";

        public static readonly string headUiCode2 =
        "local {0} = {{}}\n" +
        "local this = {0}\n\n";

        public static readonly string uiClassCode =
            "{0}\n{1}\n{2}\n{3}\n" +
            "\tpublic override void Awake(GameObject obj)\n\t{{\n\t\tbase.Awake(obj);\n" +
            "{4}\n{5}\n{6}\n{7}\n" +
            "\t}}\n"
            ;

        public static readonly string uiClassCode2 =
            "{0}" +
            "\n\n\tpublic override void ShowUI(params object[] data)\n\t{{\n" +
            "\n\n\n" +
            "\t}}\n" +
             "\n\n\tpublic void Init()\n\t{{\n" +
            "\n\n\n" +
            "\t}}\n" +
            "\n\n\tpublic override void CloseUI()\n\t{{\n" +
            "\n\n\n" +
            "\t}}\n" +
            "\n\n\tpublic override void OnDestroy(GameObject obj)\n\t{{\n\t\tbase.OnDestroy(obj);\n" +
            "\n\n\n" +
            "\t}}\n"
            ;

        public static readonly string modelCode =
        "using Client;\n" +
        "using FSHotfix.Code.Common.Utils;\n" +
        "using FSHotfix.Code.Net;\n" +
        "using FSHotfix.Code.NetEnum;\n" +
        "using FSHotfix.Core;\n" +
        "using FSHotfix.Core.Event;\n" +
        "using FSHotfix.Core.Module;\n" +
        "using Google.Protobuf.Collections;\n" +
        "using System;\n" +
        "using System.Collections.Generic;\n" +
        "using UnityEngine;\n\n" +
        "public class {0} : IModule \n{{\n{1}\n}}  \n\n"
            ;

        public static readonly string modelClassCode =
            "\tpublic override void Initial(params object[] args)\n\t{{\n\t\t\n" + "\t}}\n\n" +
            "\tprotected override void AddQueryValue()\n\t{{\n\t\t\n" + "\t}}\n\n" +
            "\tprotected override void InitialOnce()\n\t{{\n{0}\n" + "\t}}{1}\n\n\n" +
            "\tpublic override void Destroy()\n\t{{\n\t\t\n" + "\t}}\n"
            ;

        public static readonly string registerNetCode =
            "\t#region {0}\n" +
            "\tEventModule.instance.Register({1},{2}, this);\n" +
             "\tEventModule.instance.Register(\"{3}\",{4}, this);\n" +
            "\t#endregion\n\n"
            ;

        public static readonly string statementNetCode =
            "\n\n\t#region {0}\n" +
            "\tprivate void {1}(Kernel kernel, params object[] args)\n\t{{\n\t{3}\n\t}}\n\n" +
             "\tprivate void {2}(Kernel kernel, params object[] args)\n\t{{\n\t{4}\n\t}}\n" +
            "\t#endregion\n"
            ;

        public static readonly string sendNewsCode =
            "Client.{0} c2s = new Client.{0}();\n\n\n" +
            "\tNetWork.instance.SendMessage((int){1}, (int){2}, c2s);"
            ;

        public static readonly string acceptNewsCode =
            "if (FSUtils.CheackError(args)) return;\n" +
            "\tSystem.IO.MemoryStream mem = (System.IO.MemoryStream)args[0];\n" +
            "\tClient.{0} s2c = Client.{0}.Parser.ParseFrom(mem);\n"
            ;

        public static readonly string controllerCode =
            "using UnityEngine;\n" +
            "using UnityEngine.EventSystems;\n\n" +
            "\n\npublic partial class {0}_Controller\n{{\n" +
            "\tpartial void OnAwake()\n\t{{\n\n\t}}\n}}";

        public static readonly string controllerBuildCode =
            "using UnityEngine;\n\n" +
            "\n\npublic partial class {0}_Controller:IController\n{{\n" +
            "\tprivate {0}_UI ui;\n" +
            "\tprivate {0}_Model model = new {0}_Model();\n\n" +
            "\tpublic {0}_Controller({0}_UI ui)\n\t{{\n" +
            "\t\tthis.ui = ui;\n" +
            "\t\tOnAwake();\n" +
            "{1}" +
            "\t}}\n" +
            "\tpartial void OnAwake();\n" +
            "{2}\n{3}\n" +
            "}}";

        public static readonly string controllerBuildCode2 =
    "using UnityEngine;\n\n" +
    "\n\npublic partial class {0}_Controller:IController\n{{\n" +
    "\tprivate {0}_UI ui;\n" +
    //"\tprivate {0}_Model model = new {0}_Model();\n\n" +
    "\tpublic {0}_Controller({0}_UI ui)\n\t{{\n" +
    "\t\tthis.ui = ui;\n" +
    "\t\tOnAwake();\n" +
    "{1}" +
    "\t}}\n" +
    "\tpartial void OnAwake();\n" +
    "{2}\n{3}\n" +
    "}}";


        public static int Version
        {
            get { return versionIndex; }
            set
            {
                versionIndex = value;
                version = int.Parse(versionStr[versionIndex]);
            }
        }

        public static string FilePath(string name)
        {
            var filePath = string.Format("{0}/{1}/{2}.cs", Application.dataPath, referencePath, name);
            if (!QFileOperation.IsDirctoryName(filePath, true))
            {
                EditorUtility.DisplayDialog(msgTitle, "文件夹无法创建", "OK");
                Debug.LogException(new Exception("文件夹无法创建"));
            }
            return filePath;
        }

        public static string GetClassName(string suffix)
        {
            return string.Format("{1}_{0}", suffix, QGlobalFun.GetString(Selection.activeTransform.name));
        }

        public static string GetInfoPath()
        {
            int id;
            var go = PrefabUtility.GetCorrespondingObjectFromSource(selectTransform.gameObject);
            if (go != null)
            {
                id = go.GetInstanceID();
            }
            else
            {
                id = selectTransform.gameObject.GetInstanceID();
            }
            return string.Format(InfoPath, id);
        }

        public static void Compiling()
        {
            EditorPrefs.SetBool("QConfigureSelectCompiling", true);
        }

        public static bool IsCompiling()
        {
            var value = EditorPrefs.GetBool("QConfigureSelectCompiling", false);
            EditorPrefs.SetBool("QConfigureSelectCompiling", false);
            return value;
        }

        private static string GetFileName(string suffix)
        {
            return string.Format("{0}/{1}_{0}", suffix, QGlobalFun.GetString(Selection.activeTransform.name));
        }
    }
}