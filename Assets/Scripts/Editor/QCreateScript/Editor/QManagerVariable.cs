using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Text;
using System.IO;
using System.Reflection;
using LitJson;
using System.Text.RegularExpressions;
using UnityEngine.UI;
using TMPro;
using Spine.Unity;

namespace CreateScript
{
    public class QManagerVariable
    {
        public bool isFind = false;
        public static bool isCsharpMode = true;
        public static bool isMain = true;

        private Dictionary<Transform, QVariableModel> dic = new Dictionary<Transform, QVariableModel>();

        public QVariableModel this[Transform t]
        {
            get
            {
                if (!dic.ContainsKey(t))
                {
                    dic.Add(t, new QVariableModel(t));
                }
                return dic[t];
            }
        }

        StringBuilder variable = new StringBuilder();
        StringBuilder controllerEvent = new StringBuilder();
        StringBuilder attributeVariable = new StringBuilder();
        StringBuilder attribute = new StringBuilder();
        StringBuilder find = new StringBuilder();
        StringBuilder newAttribute = new StringBuilder();
        StringBuilder register = new StringBuilder();
        StringBuilder function = new StringBuilder();

        public void Init()
        {
            if (!QFileOperation.IsExists(QConfigure.GetInfoPath())) return;

            var value = QFileOperation.ReadText(QConfigure.GetInfoPath());
            var jd = JsonMapper.ToObject(value);
            if (jd.IsArray)
            {
                for (int i = 0; i < jd.Count; i++)
                {
                    VariableJson vj = JsonMapper.ToObject<VariableJson>(jd[i].ToJson());
                    var obj = QConfigure.selectTransform.Find(vj.findPath);
                    if (obj == null) continue;
                    var v = this[obj];
                    if (v == null) continue;
                    v.state.isOpen = vj.isOpen;
                    v.state.isVariable = vj.isVariable;
                    v.state.isAttribute = vj.isAttribute;
                    v.state.isEvent = vj.isEvent;
                    v.state.index = vj.index;
                }
            }
        }

        public string GetBuildUICode()
        {
            newAttribute.Length =
            attributeVariable.Length =
            function.Length =
            register.Length =
            variable.Length =
            controllerEvent.Length =
            attribute.Length =
            find.Length = 0;

            string variableFormat = QConfigure.variableFormat;
            string findFormat = isCsharpMode ? QConfigure.findFormat : QConfigure.findFormat2;
            string getValueScript = isCsharpMode ? string.Empty : QConfigure.getvalueScript;

            foreach (var value in dic.Values)
            {
                if (!value.state.isVariable) continue;
                string name = CheckName(value.name.Replace("#", ""));
                string type = CheckType(value.type);
                string findType = CheckFindType(value.type);


                //判断是否添加循环列表相关的代码
                bool isLoopScrollView = CheckLoopScrollView(value.target);
                if (isLoopScrollView)
                    variable.AppendFormat(QConfigure.loopScrollView, name + "_LoopScrollView");

                //判断是否添加Spine相关的代码
                SkeletonGraphic uiSkelet = value.target.GetComponent<SkeletonGraphic>();
                SkeletonAnimation skelet = value.target.GetComponent<SkeletonAnimation>();
                if (skelet != null)
                {
                    string spineName = name + "_SpineCtr";
                    variable.AppendFormat(QConfigure.spineFormat, QConfigure.spine, spineName);
                }

                if (uiSkelet != null)
                {
                    string spineName = name + "_UISpineCtr";
                    variable.AppendFormat(QConfigure.spineFormat, QConfigure.uiSpine, spineName);
                }

                if (isFind)
                {
                    string name2 = isCsharpMode ? name.Split('_')[1] : name;
                    find.AppendFormat(findFormat, name, findType, name2);

                    if(isLoopScrollView)
                    {
                        find.AppendFormat(QConfigure.findLoopScrollView, name + "_LoopScrollView", name);
                    }

                    if (skelet != null)
                    {
                        string spineName = name + "_SpineCtr";
                        find.AppendFormat(QConfigure.spineAssembleCode, spineName, name);
                    }

                    if (uiSkelet != null)
                    {
                        string spineName = name + "_UISpineCtr";
                        find.AppendFormat(QConfigure.spineAssembleCode, spineName, name);
                    }
                }


                if (value.state.isAttribute)
                { 
                    if (value.isUI)
                    {
                        attribute.AppendFormat(QConfigure.attributeFormat, type, name);
                    }
                    else
                    {
                        attribute.AppendFormat(QConfigure.attribute2Format, type, name);
                    }
                }

                if (value.variableEvent != string.Empty && value.state.isEvent)
                {
                    string eventName = CheckEventName(value.eventName);
                    register.AppendFormat(QConfigure.registerFormat, name, value.variableEvent, eventName);
                    function.AppendFormat(QConfigure.functionFormat, eventName);
                }
            }

            var tmp = string.Format(QConfigure.uiClassCode,
                variable, attributeVariable, controllerEvent, attribute, getValueScript, find, newAttribute, register);

            var tmp2 = string.Format(QConfigure.uiClassCode2, function);

            return string.Format(QConfigure.uiCode2, QConfigure.className, tmp, tmp2);
        }

        public string GetBuildUICode2()
        {
            variable.Length =
            register.Length =
            function.Length =
            find.Length = 0;

            string variableFormat = QConfigure.luaVariableFormat;
            string findFormat = QConfigure.luaFindFormat;
            string luaFindComponent = QConfigure.luaFindComponent;

            foreach (var value in dic.Values)
            {
                if (!value.state.isVariable) continue;
                string name = CheckName(value.name.Replace("#", ""));
                string type = CheckType(value.type);
                string findType = CheckFindType(value.type);

                variable.AppendFormat(variableFormat, name);

                if (isFind)
                {
                    if (type == "GameObject" || type == "Button")
                    {
                        find.AppendFormat(findFormat, name ,value.path, string.Empty);
                    }
                    else
                    {
                        find.AppendFormat(findFormat, name ,value.path, string.Format(luaFindComponent, findType));
                    }
                }

                if (value.variableEvent != string.Empty && value.state.isEvent)
                {
                    string eventName = CheckEventName(value.eventName);
                    register.AppendFormat(QConfigure.luaRegisterFormat, name, eventName);
                    function.AppendFormat(QConfigure.luaFunctionFormat, eventName,
                        value.eventType);
                }
            }

            string head = isMain ? string.Format(QConfigure.headUiCode1, QConfigure.className) : string.Format(QConfigure.headUiCode2, QConfigure.className);

            var tmp = string.Format(QConfigure.uiCode3, head, variable, find, register, function, QConfigure.className);

            return tmp;
        }

        protected string CheckEventName(string eventName)
        {

            string[] str = eventName.Split('_');

            if (str.Length == 3)
            {
                string str1 = str[0];
                string str2 = str[2];

                return str1 + "_" + str2;
            }

            return eventName;

        }

        protected string CheckName(string name)
        {
            string[] str = name.Split('_');

            if (str.Length == 3)
            {
                string str1 = str[1]/*CheckType(str[0])*/;
                string str2 = str[2];

                return str1 + "_" + str2;
            }

            return name;

        }

        protected bool CheckLoopScrollView(Transform tran)
        {
            //Path_Script script = tran.GetComponent<Path_Script>();

            //if (script != null)
                //return script.dllScriptName == "LoopScrollView";

            return false;
        }

        protected string CheckType(string type)
        {
            if (!isCsharpMode && (type.Equals("Transform") || type.Equals("RectTransform")))
                return "GameObject";

            if (!isCsharpMode && (type.Equals("TextMeshProUGUI")))
                return "TMP_Text";

            return type;
        }

        protected string CheckFindType(string type)
        {
            if (!isCsharpMode && (type.Equals("Transform") || type.Equals("RectTransform")))
                return "GameObject";

            if (!isCsharpMode && (type.Equals("TextMeshProUGUI")))
                return "TextMeshPro";

            return type;
        }

        StringBuilder assignment = new StringBuilder();
        StringBuilder declare = new StringBuilder();
        StringBuilder fun = new StringBuilder();

        public void SetMain(bool _isMain)
        {
            isMain = _isMain;
        }

        public void SetMode(CreateMode mode)
        {
            isCsharpMode = mode == CreateMode.Csharp;
            string modeStr = mode == CreateMode.Csharp ? "#模式" : "Value_Script模式";
            string msg = string.Format(QConfigure.switchMode, modeStr);

            EditorUtility.DisplayDialog(QConfigure.msgTitle, msg, QConfigure.ok);
        }

        public string GetControllerBuildCode()
        {
            assignment.Length =
            declare.Length =
            fun.Length = 0;
            string type = string.Empty;
            foreach (var value in dic.Values)
            {
                if (value.variableEvent != string.Empty && value.state.isEvent)
                {
                    type = value.IsButton() ? string.Empty : string.Format("{0} value", value.eventType);
                    //assignment.AppendFormat("\t\tui.{0,-50} = {1};\n", value.attributeName, value.eventName);
                    assignment.AppendFormat(QConfigure.assignmentFormat, value.attributeName, value.eventName);
                    //declare.AppendFormat("\tpartial void {0}({1});\n", value.attributeName, type);
                    declare.AppendFormat(QConfigure.declareFormat, value.attributeName, type);
                    /*fun.AppendFormat("\tprivate void {0}({1})\n\t{{\n\t\t{2}({3});\n\t}}\n",
                        value.eventName, type, value.attributeName, value.type == "Button" ? string.Empty : "value");*/
                    fun.AppendFormat(QConfigure.funFormat, value.eventName, type,
                        value.attributeName, value.IsButton() ? string.Empty : "value");
                }
            }

            string code = string.Empty;
            if (QConfigure.isCreateModel)
            {
                code = QConfigure.controllerBuildCode;
            }
            else
            {
                code = QConfigure.controllerBuildCode2;
            }
            return string.Format(
                code,
                QGlobalFun.GetString(QConfigure.selectTransform.name),
                assignment,
                declare,
                fun);
        }

        public string GetUICode()
        {
            return string.Format(QConfigure.uiCode, QGlobalFun.GetString(QConfigure.selectTransform.name), QConfigure.uicodeOnAwake);
        }

        public string GetModelCode()
        {
            return string.Format(QConfigure.modelCode, QGlobalFun.GetString(QConfigure.selectTransform.name));
        }

        public string GetControllerCode()
        {
            return string.Format(QConfigure.controllerCode, QGlobalFun.GetString(QConfigure.selectTransform.name));
        }

        public override string ToString()
        {
            return GetBuildUICode2();
        }

        public void Clear()
        {
            foreach (var value in dic.Values)
            {
                value.Reset();
            }
            dic.Clear();
        }

        public void TotalFold(bool isOn = true)
        {
            foreach (var value in dic.Values)
            {
                value.state.isOpen = isOn;
            }
        }

        public void TotalSelectVariable(bool isOn = true)
        {
            if (QConfigure.selectTransform != null)
                TotalSelect(QConfigure.selectTransform, isOn);
        }

        public void TetalSelectVariableTwo(bool isOn = true)
        {
            if (QConfigure.selectTransform != null)
                TotalSelectTwo(QConfigure.selectTransform, isOn);
        }

        public void TetalSelectVariableThree(bool isOn = true)
        {
            if (QConfigure.selectTransform != null)
            {
                TotalSelectThree(QConfigure.selectTransform, isOn);
            }
        }

        public void SetAllValue()
        {
            if (Selection.activeTransform == null)
                return;

            //读入预制体
            var path = GetPrefabAssetPath(Selection.activeTransform.gameObject);
            var path2 = GetPrefabAssetPath(Selection.activeTransform.parent.gameObject);
           

            /*
            Value_Script valueScript = Selection.activeTransform.GetComponent<Value_Script>();

            if (valueScript == null)
                valueScript = Selection.activeTransform.gameObject.AddComponent<Value_Script>();

            valueScript.Images = new InspectorImage[0];
            valueScript.Buttons = new InspectorButton[0];
            valueScript.Texts = new InspectorText[0];
            valueScript.TextMeshPros = new InspectorTextMeshPro[0];
            valueScript.GameObjects = new InspectorGameObject[0];
            valueScript.Sliders = new InspectorSlider[0];
            valueScript.Scrollbars = new InspectorScrollbar[0];
            valueScript.InputFields = new InspectorInputField[0];
            valueScript.ScrollRects = new InspectorScrollRect[0];
            valueScript.ButtonExtends = new InspectorButtonExtend[0];

            foreach (var value in dic.Values)
            {
                if (!value.state.isVariable) continue;

                if (value.type.Equals("Image"))
                {
                    valueScript.Images = CopyArray(valueScript.Images.Length + 1, valueScript.Images);

                    InspectorImage image = new InspectorImage();
                    image.Name = CheckName(value.name);
                    image.Value = value.target.GetComponent<Image>();

                    valueScript.Images[valueScript.Images.Length - 1] = image;
                }

                if (value.type.Equals("Text"))
                {
                    valueScript.Texts = CopyArray(valueScript.Texts.Length + 1, valueScript.Texts);

                    InspectorText text = new InspectorText();
                    text.Name = CheckName(value.name);
                    text.Value = value.target.GetComponent<Text>();

                    valueScript.Texts[valueScript.Texts.Length - 1] = text;
                }

                if (value.type.Equals("TextMeshProUGUI"))
                {
                    valueScript.TextMeshPros = CopyArray(valueScript.TextMeshPros.Length + 1, valueScript.TextMeshPros);

                    InspectorTextMeshPro textMeshPro = new InspectorTextMeshPro();
                    textMeshPro.Name = CheckName(value.name);
                    textMeshPro.Value = value.target.GetComponent<TextMeshProUGUI>();

                    valueScript.TextMeshPros[valueScript.TextMeshPros.Length - 1] = textMeshPro;
                }

                if (value.type.Equals("Button"))
                {
                    valueScript.Buttons = CopyArray(valueScript.Buttons.Length + 1, valueScript.Buttons);

                    InspectorButton button = new InspectorButton();
                    button.Name = CheckName(value.name);
                    button.Value = value.target.GetComponent<Button>();

                    valueScript.Buttons[valueScript.Buttons.Length - 1] = button;
                }

                if (value.type.Equals("ButtonExtend"))
                {
                    valueScript.ButtonExtends = CopyArray(valueScript.ButtonExtends.Length + 1, valueScript.ButtonExtends);

                    InspectorButtonExtend buttonExtend = new InspectorButtonExtend();
                    buttonExtend.Name = CheckName(value.name);
                    buttonExtend.Value = value.target.GetComponent<ButtonExtend>();

                    valueScript.ButtonExtends[valueScript.ButtonExtends.Length - 1] = buttonExtend;
                }

                if (value.type.Equals("Slider"))
                {
                    valueScript.Sliders = CopyArray(valueScript.Sliders.Length + 1, valueScript.Sliders);

                    InspectorSlider slider = new InspectorSlider();
                    slider.Name = CheckName(value.name);
                    slider.Value = value.target.GetComponent<Slider>();

                    valueScript.Sliders[valueScript.Sliders.Length - 1] = slider;
                }

                if (value.type.Equals("InputField"))
                {
                    valueScript.InputFields = CopyArray(valueScript.InputFields.Length + 1, valueScript.InputFields);

                    InspectorInputField inputField = new InspectorInputField();
                    inputField.Name = CheckName(value.name);
                    inputField.Value = value.target.GetComponent<InputField>();

                    valueScript.InputFields[valueScript.InputFields.Length - 1] = inputField;
                }

                if (value.type.Equals("Scrollbar"))
                {
                    valueScript.Scrollbars = CopyArray(valueScript.Scrollbars.Length + 1, valueScript.Scrollbars);

                    InspectorScrollbar scrollbar = new InspectorScrollbar();
                    scrollbar.Name = CheckName(value.name);
                    scrollbar.Value = value.target.GetComponent<Scrollbar>();

                    valueScript.Scrollbars[valueScript.Scrollbars.Length - 1] = scrollbar;
                }

                if (value.type.Equals("ScrollRect"))
                {
                    valueScript.ScrollRects = CopyArray(valueScript.ScrollRects.Length + 1, valueScript.ScrollRects);

                    InspectorScrollRect scrollRect = new InspectorScrollRect();
                    scrollRect.Name = CheckName(value.name);
                    scrollRect.Value = value.target.GetComponent<ScrollRect>();

                    valueScript.ScrollRects[valueScript.ScrollRects.Length - 1] = scrollRect;
                }

                if (value.type.Equals("Transform") || value.type.Equals("RectTransform"))
                {
                    valueScript.GameObjects = CopyArray(valueScript.GameObjects.Length + 1, valueScript.GameObjects);

                    InspectorGameObject obj = new InspectorGameObject();
                    obj.Name = CheckName(value.name);
                    obj.Value = value.target.gameObject;

                    valueScript.GameObjects[valueScript.GameObjects.Length - 1] = obj;
                }
            }

            // 保存预制体
            if (path != null)
                PrefabUtility.SaveAsPrefabAsset(Selection.activeTransform.gameObject, path);

            if(path2 != null)
                PrefabUtility.SaveAsPrefabAsset(Selection.activeTransform.parent.gameObject, path2);

            //if (path3 != null)
            //    PrefabUtility.SaveAsPrefabAsset(Selection.activeTransform.parent.parent.gameObject, path3);

            //if (path4 != null)
            //    PrefabUtility.SaveAsPrefabAsset(Selection.activeTransform.parent.parent.parent.gameObject, path4);

            //if (path5 != null)
            //    PrefabUtility.SaveAsPrefabAsset(Selection.activeTransform.parent.parent.parent.parent.gameObject, path5);
            */
        }


        /// <summary>
        /// 获取预制体资源路径。
        /// </summary>
        /// <param name="gameObject"></param>
        /// <returns></returns>
        public static string GetPrefabAssetPath(GameObject gameObject)
        {
#if UNITY_EDITOR
            // Project中的Prefab是Asset不是Instance
            if (UnityEditor.PrefabUtility.IsPartOfPrefabAsset(gameObject))
            {
                // 预制体资源就是自身
                return UnityEditor.AssetDatabase.GetAssetPath(gameObject);
            }

            // Scene中的Prefab Instance是Instance不是Asset
            if (UnityEditor.PrefabUtility.IsPartOfPrefabInstance(gameObject))
            {
                // 获取预制体资源
                var prefabAsset = UnityEditor.PrefabUtility.GetCorrespondingObjectFromOriginalSource(gameObject);
                return UnityEditor.AssetDatabase.GetAssetPath(prefabAsset);
            }

            // PrefabMode中的GameObject既不是Instance也不是Asset
            var prefabStage = UnityEditor.SceneManagement.PrefabStageUtility.GetPrefabStage(gameObject);
            if (prefabStage != null && prefabStage.prefabContentsRoot.name == gameObject.name)
            {
                // 预制体资源：prefabAsset = prefabStage.prefabContentsRoot
                return prefabStage.prefabAssetPath;
            }
#endif

            // 不是预制体
            return null;
        }


        protected T[] CopyArray<T>(int Length, T[] array)
        {
            T[] copyArray = new T[Length];
            for (int i = 0; i < copyArray.Length; i++)
            {
                if (i >= array.Length)
                    copyArray[i] = default(T);
                else
                    copyArray[i] = array[i];

            }

            return copyArray;
        }

        public void TotalAttribute(bool isOn = true)
        {
            foreach (var value in dic.Values)
            {
                if (!value.state.isVariable) continue;
                value.state.isAttribute = isOn;
            }
        }

        public void TotalEvent(bool isOn = true)
        {
            foreach (var value in dic.Values)
            {
                if (!value.state.isVariable || !value.state.isSelectEvent) continue;
                value.state.isEvent = isOn;
            }
        }

        private void TotalSelect(Transform tr, bool isOn)
        {
            foreach (Transform t in tr)
            {
                var tmp = dic[t];
                tmp.state.isVariable = isOn;
                if (tmp.state.isOpen && t.childCount > 0)
                {
                    TotalSelect(t, isOn);
                }
            }
        }

        private void TotalSelectTwo(Transform tr, bool isOn)
        {
            foreach (Transform t in tr)
            {
                var tmp = dic[t];
                if (t.gameObject.name.Contains("#"))
                {
                    tmp.state.isVariable = true;
                }
                else
                {
                    tmp.state.isVariable = false;
                }
                if (tmp.state.isOpen && t.childCount > 0)
                {
                    TotalSelectTwo(t, isOn);
                }
            }
        }

        private void TotalSelectThree(Transform tr, bool isOn)
        {
            foreach (Transform t in tr)
            {
                var tmp = dic[t];
                if (t.gameObject.name.Contains("_"))
                {
                    tmp.state.isVariable = true;
                }
                else
                {
                    tmp.state.isVariable = false;
                }
                if (tmp.state.isOpen && t.childCount > 0)
                {
                    TotalSelectThree(t, isOn);
                }
            }
        }

        public void CreateFile()
        {
            if (QConfigure.selectTransform == null)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.noSelect, QConfigure.ok);
                return;
            }
            if (EditorApplication.isCompiling)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.editorCompiling, QConfigure.ok);
                return;
            }
            if (QFileOperation.IsExists(QConfigure.FilePath(QConfigure.UIBuildFileName)))
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.haveBeenCreated, QConfigure.ok);
                return;
            }

            QFileOperation.WriteText(QConfigure.FilePath(QConfigure.UIFileName), GetUICode());
            QFileOperation.WriteText(QConfigure.FilePath(QConfigure.UIBuildFileName), GetBuildUICode2());

            if (QConfigure.isCreateModel)
            {
                QFileOperation.WriteText(QConfigure.FilePath(QConfigure.ModelFileName), GetModelCode());
            }

            if (QConfigure.isCreateController)
            {
                QFileOperation.WriteText(QConfigure.FilePath(QConfigure.ControllerFileName), GetControllerCode());
                QFileOperation.WriteText(QConfigure.FilePath(QConfigure.ControllerBuildFileName), GetControllerBuildCode());
            }

            if (QConfigure.version == 1)
            {
                GetBindingInfo();
            }
            else
            {
                GetBindingInfoToJson();
            }
            QConfigure.Compiling();
            AssetDatabase.Refresh();
        }

        public void Update()
        {
            if (QConfigure.selectTransform == null) return;
            if (EditorApplication.isCompiling)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.editorCompiling, QConfigure.ok);
                return;
            }
            var fileName = QConfigure.FilePath(QConfigure.UIBuildFileName);
            if (!QFileOperation.IsExists(fileName))
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.notCreate, QConfigure.ok);
                return;
            }
            QFileOperation.WriteText(QConfigure.FilePath(QConfigure.UIBuildFileName), GetBuildUICode2(), FileMode.Create);

            if (QConfigure.isCreateController)
            {
                QFileOperation.WriteText(QConfigure.FilePath(QConfigure.ControllerBuildFileName), GetControllerBuildCode(), FileMode.Create);
            }

            if (QConfigure.version == 1)
            {
                GetBindingInfo();
            }
            else
            {
                GetBindingInfoToJson();
            }
            QConfigure.Compiling();
            AssetDatabase.Refresh();
        }

        public void Copy()
        {
            if (QConfigure.selectTransform == null) return;
            GUIUtility.systemCopyBuffer = GetBuildUICode2();
            EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.copy, QConfigure.ok);
        }

        public void MountScript()
        {
            if (QConfigure.selectTransform == null) return;

            if (EditorApplication.isCompiling)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.editorCompiling, QConfigure.ok);
                return;
            }

            var name = QConfigure.UIName;
            var scriptType = QGlobalFun.GetAssembly().GetType(name);
            if (scriptType == null)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.notCreate, QConfigure.ok);
                return;
            }
            var root = QConfigure.selectTransform.gameObject;
            //var target = root.GetComponent(scriptType);
            //if (target == null)
            //{
            /*target = */
            root.AddComponent(scriptType);
            //}
        }

        public void BindingUI()
        {
            if (QConfigure.selectTransform == null) return;
            if (EditorApplication.isCompiling)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.editorCompiling, QConfigure.ok);
                return;
            }
            if (QConfigure.selectTransform.GetComponent(QConfigure.UIName) == null)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.noMountScript, QConfigure.ok);
                return;
            }

            var assembly = QGlobalFun.GetAssembly();
            var type = assembly.GetType(QConfigure.UIName);

            if (type == null)
            {
                EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.notCreate, QConfigure.ok);
                return;
            }

            var root = QConfigure.selectTransform;
            var target = root.GetComponent(type);

            if (QConfigure.version == 1)
            {
                var so = AssetDatabase.LoadAssetAtPath<QScriptInfo>(QConfigure.InfoPath);
                var infos = so.GetFieldInfos(QConfigure.UIName);
                if (infos == null)
                {
                    EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.plugCreate, QConfigure.ok);
                    return;
                }
                foreach (var info in infos)
                {
                    if (string.IsNullOrEmpty(info.name)) continue;
                    type.InvokeMember(info.name,
                                    BindingFlags.SetField |
                                    BindingFlags.Instance |
                                    BindingFlags.NonPublic,
                                    null, target, new object[] { root.Find(info.path).GetComponent(info.type) }, null, null, null);
                }
            }
            if (QConfigure.version == 2)
            {
                if (!QFileOperation.IsExists(QConfigure.GetInfoPath()))
                {
                    EditorUtility.DisplayDialog(QConfigure.msgTitle, QConfigure.plugCreate, QConfigure.ok);
                    return;
                }
                var value = QFileOperation.ReadText(QConfigure.GetInfoPath());
                var jd = JsonMapper.ToObject(value);
                if (jd.IsArray)
                {
                    for (int i = 0; i < jd.Count; i++)
                    {
                        VariableJson vj = JsonMapper.ToObject<VariableJson>(jd[i].ToJson());
                        if (string.IsNullOrEmpty(vj.name)) continue;
                        type.InvokeMember(vj.name,
                                        BindingFlags.SetField |
                                        BindingFlags.Instance |
                                        BindingFlags.NonPublic,
                                        null, target, new object[] { root.Find(vj.findPath).GetComponent(vj.type) }, null, null, null);
                    }
                }
            }

            var obj = PrefabUtility.GetPrefabParent(root.gameObject);
            if (obj != null)
            {
                PrefabUtility.ReplacePrefab(root.gameObject, obj, ReplacePrefabOptions.ConnectToPrefab);
                AssetDatabase.Refresh();
            }
        }


        public void GetBindingInfoToJson()
        {
            if (QConfigure.selectTransform == null) return;

            JsonData jd = new JsonData();
            foreach (var item in dic)
            {
                if (!item.Value.state.isVariable) continue;
                VariableJson vj = new VariableJson();
                var state = item.Value.state;
                vj.isOpen = state.isOpen;
                vj.isAttribute = state.isAttribute;
                vj.isEvent = state.isEvent;
                vj.isVariable = state.isVariable;
                vj.index = state.index;
                vj.name = item.Value.name;
                vj.type = item.Value.type;
                vj.findPath = QGlobalFun.GetGameObjectPath(item.Key, QConfigure.selectTransform);
                jd.Add(JsonMapper.ToObject(JsonMapper.ToJson(vj)));
            }
            QFileOperation.WriteText(QConfigure.GetInfoPath(), jd.ToJson());
        }

        private void GetBindingInfo()
        {
            QScriptInfo so;
            if (QFileOperation.IsExists(QConfigure.InfoPath))
            {
                so = AssetDatabase.LoadAssetAtPath<QScriptInfo>(QConfigure.InfoPath);
            }
            else
            {
                so = ScriptableObject.CreateInstance<QScriptInfo>();
            }

            List<string> k = new List<string>(dic.Count);
            List<string> t = new List<string>(dic.Count);
            List<string> p = new List<string>(dic.Count);

            foreach (var key in dic.Keys)
            {
                var target = dic[key];
                if (target.state.isVariable)
                {
                    k.Add(target.name);
                    t.Add(target.type.ToString());
                    p.Add(QGlobalFun.GetGameObjectPath(key, QConfigure.selectTransform));
                }
            }

            int count = k.Count;
            var infos = new QScriptInfo.FieldInfo[count];
            for (int i = 0; i < count; i++)
            {
                infos[i] = new QScriptInfo.FieldInfo();
                infos[i].name = k[i];
                infos[i].type = t[i];
                infos[i].path = p[i];
            }

            so.SetClassInfo(QConfigure.UIName, infos);

            if (QFileOperation.IsExists(QConfigure.InfoPath))
            {
                AssetDatabase.SaveAssets();
            }
            else
            {
                if (QFileOperation.IsDirctoryName(QConfigure.InfoPath, true))
                {
                    AssetDatabase.CreateAsset(so, QConfigure.InfoPath);
                }
            }
        }
    }
}