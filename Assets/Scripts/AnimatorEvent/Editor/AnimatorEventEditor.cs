using UnityEngine;
using UnityEditor;
using UnityEditorInternal;
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEditor.Animations;

using State = UnityEditor.Animations.AnimatorState;
using AnimatorTransitionBase = UnityEditor.Animations.AnimatorTransitionBase;
using AnimatorController = UnityEditor.Animations.AnimatorController;
using StateMachine = UnityEditor.Animations.AnimatorStateMachine;
using AnimatorControllerLayer = UnityEditor.Animations.AnimatorControllerLayer;
using GameLogic;

namespace Game {
	public class AnimatorEventEditor : EditorWindow {
		#region singleton
		private static AnimatorEventEditor ms_instance = null;
		public static AnimatorEventEditor instance {
			get {
				return ms_instance;
			}
		}
		#endregion
		
		#region private members
		private AnimatorEventHandler m_handler = null;
		private string[] m_animatorLayers = null;
		private Dictionary<string, State[]> m_animatorStates = null;
		private Dictionary<State, string> m_stateFullNames = null;
		private Dictionary<StateMachine, string> m_stateMachineFullNames = null;
		private Dictionary<int, AnimatorTransitionBase[]> m_animatorTransitions = null;
		private int m_selectedLayerIndex = -1;
		private int m_selectedStateIndex = -1;
		private MsgEvent m_selectedEvent = null;
		private bool m_isDataChanged = false;
		private bool m_isSimulating = false;
		private float m_playbackTime = 0f;

		// 为了接入wwise的akwwisecomponetpicker而需要的参数
		private SerializedObject m_AkSerializeObject = null;
		private SerializedProperty[] m_AkValueProperty = null;
		private string[] shakeTypeStrings = null;
		#endregion

		#region public properties
		public AnimatorEventHandler handler {
			set {
				if (m_handler == value)
					return;

				_CheckDataSaved();
				isSimulating = false;

				m_handler = value;

				_OnHandlerChanged();
			}
			get {
				return m_handler;
			}
		}
		#endregion

		#region private properties
		AnimatorController animatorController {
			get {
				if (handler == null)
					return null;

				if (handler.animator == null)
					return null;

				return (AnimatorController)handler.animator.runtimeAnimatorController;
			}
		}

		int selectedLayerIndex {
			set {
				if (m_selectedLayerIndex == value)
					return;

				m_selectedLayerIndex = value;
				_OnSelectedLayerChanged();
			}
			get {
				return m_selectedLayerIndex;
			}
		}

		string selectedLayerName {
			get {
				if (m_animatorLayers == null)
					return null;

				if (selectedLayerIndex < 0)
					return null;

				if (selectedLayerIndex >= m_animatorLayers.Length)
					return null;

				return m_animatorLayers[selectedLayerIndex];
			}
		}

		State[] animatorStatesInSelectedLayer {
			get {
				if (m_animatorStates == null)
					return null;

				if (selectedLayerName == null)
					return null;

				State[] states;
				if (!m_animatorStates.TryGetValue(selectedLayerName, out states))
					return null;

				return states;
			}
		}

		string[] animatorStatesNameInSelectedLayer {
			get {
				if (animatorStatesInSelectedLayer == null)
					return null;

				string[] statesName = new string[animatorStatesInSelectedLayer.Length];
				for (int i = 0; i < animatorStatesInSelectedLayer.Length; ++i)
					statesName[i] = animatorStatesInSelectedLayer[i].name;

				return statesName;
			}
		}

		int selectedStateIndex {
			set {
				if (m_selectedStateIndex == value)
					return;

				m_selectedStateIndex = value;
				_OnSelectedStateChanged();
			}
			get {
				return m_selectedStateIndex;
			}
		}

		State selectedState {
			get {
				if (animatorStatesInSelectedLayer == null)
					return null;

				if (selectedStateIndex < 0)
					return null;

				if (selectedStateIndex >= animatorStatesInSelectedLayer.Length)
					return null;

				return animatorStatesInSelectedLayer[selectedStateIndex];
			}
		}

		float selectedStateLength {
			get {
				if (selectedState == null)
					return 0;

				Motion motion = selectedState.motion;
				if (motion == null)
					return 0;

				return motion.averageDuration;
			}
		}

		int selectedStateFrames {
			get {
				return Mathf.RoundToInt(selectedStateLength * 30);
			}
		}

		List<MsgEvent> animatorEventsInSelectedState {
			get {
				if (handler == null)
					return null;

				if (handler.animatorEventData == null)
					return null;

				if (selectedState == null)
					return null;

				handler.animatorEventData.MakeSureEventList(GetUniqueNameHash(selectedState));

				return handler.animatorEventData.GetEventList(GetUniqueNameHash(selectedState), selectedLayerIndex);
			}
		}

		int GetUniqueNameHash(State state)
		{
			int hash = 0;
			if (m_stateFullNames.ContainsKey(state))
			{
				hash = Animator.StringToHash(m_stateFullNames[state]);
			}
			else
			{
				hash = state.nameHash;
			}
			return hash;
		}

		bool RequestAddEvent(int stateHash, MsgEvent addEvent)
		{
			if (addEvent == null)
				return false;
			if (handler == null)
				return false;
			if (handler.animatorEventData == null)
				return false;

			return handler.animatorEventData.AddEvent(stateHash, addEvent);
		}
		bool RequestRemoveEvent(int stateHash, MsgEvent deleteEvent)
		{
			if (deleteEvent == null)
				return false;
			if (handler == null)
				return false;
			if (handler.animatorEventData == null)
				return false;

			return handler.animatorEventData.RemoveEvent(stateHash, deleteEvent);
		}

        MsgEvent selectedEvent {
			set {
				if (m_selectedEvent == value)
					return;

				m_selectedEvent = value;
				_OnSelectedEventChanged();
			}
			get {
				return m_selectedEvent;
			}
		}

		bool isSimulating
        {
			set {
				if (m_isSimulating == value)
					return;

				m_isSimulating = value;
				if (m_isSimulating) {
					_OnEnterSimulatingState();
				}
				else {
					_OnLeaveSimulatingState();
				}
			}
			get {
				return m_isSimulating;
			}
		}

        // In range [0, 1]
        float playbackTime {
			set {
				if (value == 1f)
					m_playbackTime = 1f;
				else
					m_playbackTime = Mathf.Repeat(value, 1f);

				Repaint();
			}

			get {
				return m_playbackTime;
			}
		}
		#endregion

		public static void ShowWindow() {
			GetWindow<AnimatorEventEditor>();
		}

		void OnEnable() {
			ms_instance = this;
			isSimulating = false;

			titleContent.text = "编辑动画器事件"; // title
			minSize = new Vector2(950, 320);

			m_AkSerializeObject = new SerializedObject(this);
			m_AkValueProperty = new SerializedProperty[1];
			m_AkValueProperty[0] = m_AkSerializeObject.FindProperty("valueGuid.Array");

			shakeTypeStrings = new string[4];
			shakeTypeStrings[0] = "全方向随机";
			shakeTypeStrings[1] = "上下震动";
			shakeTypeStrings[2] = "左右震动";
			shakeTypeStrings[3] = "前后震动";
		}

		void OnDisable() {
			isSimulating = false;
			handler = null;
			ms_instance = null;
		}

		#region OnGUI
		void OnGUI() {
			if (animatorController == null)
            {
                if (handler != null && handler.animator != null && handler.animator.runtimeAnimatorController==null)
                {
                    ShowNotification(new GUIContent("该Animator没有控制器，请先选择控制器."));
                }
                else
                {
                    ShowNotification(new GUIContent("请先选择一个有Animator和AnimatorEventHandler组件的物件."));
                }
                return;
			}
			RemoveNotification();

			GUILayout.BeginVertical();
			GUILayout.Space(10);

			GUILayout.BeginHorizontal();
			_DrawLayersPanel();
			GUILayout.Space(10);
			_DrawStatesPanel();
			GUILayout.Space(10);
			_DrawStateInformation();
			GUILayout.EndHorizontal();

			GUILayout.Space(10);
			GUILayout.EndVertical();

			if (!Application.isPlaying)
				m_isSimulating = false;

			if (isSimulating) {
				_SimulateStateStatus();
			}
			else {
				_SyncStateStatus();
			}
		}

		private Vector2 m_LayerScrollPos;
		void _DrawLayersPanel() {
			GUILayout.BeginVertical(GUILayout.Width(150));

			if (animatorController != null && m_animatorLayers != null) {
				GUILayout.Label(string.Format("动画器[{0}]有{1}个动画层。", animatorController.name, m_animatorLayers.Length));

				GUILayout.BeginVertical("Box");
				m_LayerScrollPos = GUILayout.BeginScrollView(m_LayerScrollPos);

				selectedLayerIndex = GUILayout.SelectionGrid(selectedLayerIndex, m_animatorLayers, 1);

				GUILayout.EndScrollView();
				GUILayout.EndVertical();
			}
			else {
				GUILayout.Label("此动画器无动画层！");
			}

			GUILayout.EndVertical();
		}

		private Vector2 m_StateScrollPos;
		void _DrawStatesPanel() {
			GUILayout.BeginVertical(GUILayout.Width(200));

			if (selectedLayerName != null && animatorStatesNameInSelectedLayer != null) {
				GUILayout.Label(string.Format("动画层[{0}]有{1}个动画状态。", selectedLayerName, animatorStatesNameInSelectedLayer.Length));

				GUILayout.BeginVertical("Box");
				m_StateScrollPos = GUILayout.BeginScrollView(m_StateScrollPos);

				selectedStateIndex = GUILayout.SelectionGrid(selectedStateIndex, animatorStatesNameInSelectedLayer, 1);

				GUILayout.EndScrollView();
				GUILayout.EndVertical();

			}
			else {
				GUILayout.Label("此动画层无动画状态。");
			}

			GUILayout.EndVertical();
		}

		void _DrawStateInformation() {
			GUILayout.BeginVertical();

			_DrawStateLabel();
			GUILayout.Space(10);

			GUILayout.BeginHorizontal();
			GUILayout.Space(10);

			_DrawStateTimeline();
			GUILayout.Space(10);

			GUILayout.EndHorizontal();

			GUILayout.Space(10);
			_DrawToolsPanel();

			GUILayout.Space(10);
			_DrawEventPanel();

			GUILayout.EndVertical();
		}

		void _DrawStateLabel() {
			if (selectedState == null) {
				GUILayout.Label("请选择动画状态。");
				return;
			}

			int totalEventCount = 0;
			int effectEventCount = 0;
			int wwiseEventCount = 0;
			int cameraShakeEventCount = 0;
			int msgEventCount = 0;

			var listEvents = animatorEventsInSelectedState;
			if (listEvents != null)
			{
				totalEventCount = listEvents.Count;
				for (int i = 0; i < totalEventCount; ++i) {
					switch (listEvents[i].type)
					{
						case AnimatorEventType.Msg:
							++msgEventCount;
							break;
						default:
							break;
					}
				}
			}

			GUILayout.Label(
				string.Format(
					"动画状态[{0}]（{1}帧/{2}秒）共有{3}个动画事件，其中，{4}个Msg事件。请不要再黄线之后添加事件。",
					selectedState.name,
					selectedStateFrames,
					selectedStateLength.ToString("0.00"),
					totalEventCount,
					msgEventCount));
		}

		void _DrawStateTimeline() {
			Rect rect = GUILayoutUtility.GetRect(500, 10000, 50, 50);

			int timelineId = GUIUtility.GetControlID("TimelineControl".GetHashCode(), FocusType.Passive, rect);

			Rect thumbRect = new Rect(rect.x + rect.width * playbackTime - 5, rect.y + 2, 10, 10);

			Event e = Event.current;
			switch (e.type) {
				case EventType.Repaint:
					Rect lineRect = new Rect(rect.x, rect.y + 10, rect.width, 1.5f);
					_DrawTimeLine(lineRect);
					GUI.skin.horizontalSliderThumb.Draw(thumbRect, new GUIContent(), timelineId);
					break;

				case EventType.MouseDown:
					if (thumbRect.Contains(e.mousePosition)) {
						GUIUtility.hotControl = timelineId;
						e.Use();
					}
					else {
						if (GUIUtility.hotControl == timelineId) {
							GUIUtility.hotControl = 0;
						}
					}
					break;

				case EventType.MouseUp:
					if (GUIUtility.hotControl == timelineId) {
						GUIUtility.hotControl = 0;
						e.Use();
					}
					break;

				case EventType.MouseDrag:
					if (GUIUtility.hotControl == timelineId) {
						Vector2 guiPos = e.mousePosition;
						float clampedX = Mathf.Clamp(guiPos.x, rect.x, rect.x + rect.width);
						playbackTime = (clampedX - rect.x) / rect.width;

						e.Use();
					}
					break;
				default:
					break;
			}

			var listEvent = animatorEventsInSelectedState;
			if (listEvent != null)
			{
				for (int i = 0; i < listEvent.Count; ++i)
				{
					_DrawEventKey(rect, listEvent[i]);
				}
			}

			if (selectedState != null)
			{
				_DrawMinimumExitTime(rect, GetMinimumExitTimeForState(GetUniqueNameHash(selectedState)));
			}
		}

		private Material m_lineMaterial = null;
		void _DrawTimeLine(Rect rect) {
			if (Event.current.type != EventType.Repaint) {
				return;
			}

			if (selectedStateFrames <= 0)
				return;

			if (m_lineMaterial == null) {
				m_lineMaterial = new Material(Shader.Find("Diffuse"));
			}

			if (m_lineMaterial != null)
				m_lineMaterial.SetPass(0);

			GL.Begin(GL.LINES);

			GL.Color(new Color(1f, 1f, 1f, 0.75f));
			_DrawHorizontalLine(rect.x, rect.y, rect.width);
			_DrawHorizontalLine(rect.x, rect.y + 25, rect.width);

			float frameWidth = rect.width / selectedStateFrames;
			for (int i = 0; i <= selectedStateFrames; ++i) {
				if (i % 10 == 0) {
					_DrawVerticalLine(rect.x + i * frameWidth, rect.y, 15);
				}
				else if (i % 5 == 0) {
					_DrawVerticalLine(rect.x + i * frameWidth, rect.y, 10);
				}
				else {
					_DrawVerticalLine(rect.x + i * frameWidth, rect.y, 5);
				}
			}

			GL.Color(new Color(1f, 1f, 1f, 0.75f));
			_DrawVerticalLine(rect.x + rect.width * playbackTime, rect.y, 20);

			GL.End();
		}

		void _DrawHorizontalLine(float x, float y, float width) {
			GL.Vertex3(x, y, 0);
			GL.Vertex3(x + width, y, 0);
		}

		void _DrawVerticalLine(float x, float y, float height) {
			GL.Vertex3(x, y, 0);
			GL.Vertex3(x, y + height, 0);
		}

		void _AddEventKey(object obj) {
            MsgEvent newKey = null;

            AnimatorEventType eventType = (AnimatorEventType)obj;
			switch (eventType) {
				case AnimatorEventType.Msg:
					newKey = new MsgEvent();
					newKey.name = "新建Msg事件";
					break;
				default:
					break;
			}

			if (newKey != null && animatorEventsInSelectedState != null) {
				newKey.layer = selectedLayerIndex;
				newKey.normalizedTime = playbackTime;
				RequestAddEvent(GetUniqueNameHash(selectedState), newKey);
				m_isDataChanged = true;
				selectedEvent = newKey;
			}
		}

		void _DeleteEventKey() {
			if (selectedEvent == null)
				return;
			if (selectedState == null)
				return;

			if (animatorEventsInSelectedState == null)
				return;


			int selectedIndex = animatorEventsInSelectedState.IndexOf(selectedEvent);
			if (selectedIndex < 0)
				return;

			int stateHash = GetUniqueNameHash(selectedState);
			RequestRemoveEvent(stateHash, selectedEvent);
			selectedEvent = null;

			List<MsgEvent> listEvent = animatorEventsInSelectedState;
			m_isDataChanged = true;
			if (listEvent.Count > 0)
			{
				if (selectedIndex >= listEvent.Count)
					selectedIndex = listEvent.Count - 1;

				selectedEvent = listEvent[selectedIndex];
			}
		}

		void _DrawMinimumExitTime(Rect rect, float minimumExitTime)
		{
			float keyTime = minimumExitTime;
			Rect keyRect = new Rect(rect.x + rect.width * keyTime - 3, rect.y, 6, 60);

			int eventKeyCtrl = 999;
			Event e = Event.current;

			switch (e.type)
			{
				case EventType.Repaint:
					Color savedColor = GUI.color;
					GUI.color = Color.yellow;
					GUI.skin.button.Draw(keyRect, new GUIContent(), eventKeyCtrl);
					GUI.color = savedColor;

					if (m_hotEventKey == eventKeyCtrl || (m_hotEventKey == 0 && keyRect.Contains(e.mousePosition)))
					{
						string labelString = string.Format(
							"{0}@{1}", "exittime", minimumExitTime.ToString("0.0000"));
						Vector2 size = EditorStyles.largeLabel.CalcSize(new GUIContent(labelString));
						Rect infoRect = new Rect(rect.x + rect.width * keyTime - size.x, rect.y, size.x, size.y);
						savedColor = GUI.color;
						GUI.color = Color.yellow;
						EditorStyles.largeLabel.Draw(infoRect, new GUIContent(labelString), eventKeyCtrl);
						GUI.color = savedColor;
					}
					break;
			}
		}

		private int m_hotEventKey = 0;
		void _DrawEventKey(Rect rect, MsgEvent animatorEvent) {
			if (animatorEvent.layer == -1)
			{
				animatorEvent.layer = selectedLayerIndex;
			}

			float keyTime = animatorEvent.normalizedTime;

			Rect keyRect = new Rect(rect.x + rect.width * keyTime - 3, rect.y + 25, 6, 18);

			int eventKeyCtrl = animatorEvent.GetHashCode();

			Event e = Event.current;

			switch (e.type) {
				case EventType.Repaint:
					Color savedColor = GUI.color;

					GUI.color = Color.gray;
					if (selectedEvent == animatorEvent)
						GUI.color = Color.red;
					GUI.skin.button.Draw(keyRect, new GUIContent(), eventKeyCtrl);

					GUI.color = savedColor;

					if (m_hotEventKey == eventKeyCtrl || (m_hotEventKey == 0 && keyRect.Contains(e.mousePosition))) {
						string labelString = string.Format(
							"{0}@{1}", animatorEvent.name, animatorEvent.normalizedTime.ToString("0.0000"));

						Vector2 size = EditorStyles.largeLabel.CalcSize(new GUIContent(labelString));
						Rect infoRect = new Rect(rect.x + rect.width * keyTime - size.x / 2, rect.y + 50, size.x, size.y);
						EditorStyles.largeLabel.Draw(infoRect, new GUIContent(labelString), eventKeyCtrl);
					}
					break;

				case EventType.MouseDown:
					if (keyRect.Contains(e.mousePosition)) {

						// 如果当前聚焦归一化时间编辑框，该编辑框的数据不会刷新。所以在选中事件时，清空当前聚焦。
						EditorGUI.FocusTextInControl("");

						m_hotEventKey = eventKeyCtrl;

						selectedEvent = animatorEvent;
						playbackTime = selectedEvent.normalizedTime;

						e.Use();
					}
					break;

				case EventType.MouseDrag:
					if (m_hotEventKey == eventKeyCtrl) {

						if (e.button == 0) {
							Vector2 guiPos = e.mousePosition;
							float clampedX = Mathf.Clamp(guiPos.x, rect.x, rect.x + rect.width);
							animatorEvent.normalizedTime = (clampedX - rect.x) / rect.width;
							m_isDataChanged = true;

							selectedEvent = animatorEvent;
							playbackTime = selectedEvent.normalizedTime;
						}

						e.Use();
					}
					break;

				case EventType.MouseUp:
					if (m_hotEventKey == eventKeyCtrl) {

						m_hotEventKey = 0;

						e.Use();
					}
					break;
			}
		}

		void _DrawToolsPanel() {
			GUILayout.BeginHorizontal();
			EditorGUI.BeginDisabledGroup(Application.isPlaying == false);
			string buttonText = isSimulating ? "关闭运行时编辑" : "开启运行时编辑";
			if (GUILayout.Button(buttonText, GUILayout.Width(120))) {
				isSimulating = !isSimulating;
				if (!isSimulating && handler != null && handler.animator != null)
				{
					handler.animator.Update(0);
				}
			}
			EditorGUI.EndDisabledGroup();

			GUILayout.FlexibleSpace();


			if (GUILayout.Button("添加事件", GUILayout.Width(80))) {
				GenericMenu menu = new GenericMenu();
				menu.AddItem(new GUIContent("Msg事件"), false, _AddEventKey, AnimatorEventType.Msg);
				menu.ShowAsContext();
			}

			EditorGUI.BeginDisabledGroup(selectedEvent == null);
			if (GUILayout.Button("删除事件", GUILayout.Width(80))) {
				if (selectedEvent != null)
					_DeleteEventKey();
			}
			EditorGUI.EndDisabledGroup();
			EditorGUI.BeginDisabledGroup(false);
			if (GUILayout.Button("清除冗余", GUILayout.Width(80)))
			{
				List<int> stateHashs = new List<int>();
				foreach (var e in m_animatorStates)
				{
					for (int i = 0; i < e.Value.Length; ++i)
					{
						stateHashs.Add(GetUniqueNameHash(e.Value[i]));
					}
				}
			}
			EditorGUI.EndDisabledGroup();
			GUILayout.Space(20);
			EditorGUI.BeginDisabledGroup(m_isDataChanged == false);
			if (GUILayout.Button("保存prefab", GUILayout.Width(80))) {
				m_isDataChanged = false;
			    TestPrefabApply(handler.gameObject);
                EditorUtility.SetDirty(handler.gameObject);
                AssetDatabase.SaveAssets();
			    AssetDatabase.Refresh();
            }
			if (GUILayout.Button("还原prefab", GUILayout.Width(80))) {
				m_isDataChanged = false;
			    if (handler != null)
			    {
			        PrefabUtility.RevertPrefabInstance(handler.gameObject);
			    }

			}
			EditorGUI.EndDisabledGroup();
			GUILayout.EndHorizontal();
			if (selectedState == null)
				return;

			GUILayout.BeginHorizontal();
			int slotIndex = 0;
			List<MsgEvent> listBase = new List<MsgEvent>(animatorEventsInSelectedState);
			List<MsgEvent> changedBase = new List<MsgEvent>();
			List<string> listNormal = new List<string>();
			int paramNum = 0;
			while (listBase != null && listBase.Count > 0)
			{
				int index = 0;
				for (int i = 1; i < listBase.Count; ++i)
				{
					if (listBase[i].normalizedTime < listBase[index].normalizedTime)
						index = i;
				}
				if (listBase[index] == selectedEvent)
					slotIndex = listNormal.Count;
				changedBase.Add(listBase[index]);
				listNormal.Add(string.Format("{0}: {1}  -  {2}  - {3}", (paramNum++), listBase[index].type, listBase[index].name, listBase[index].normalizedTime));           
				listBase.RemoveAt(index);
			}
			int selectIndex = EditorGUILayout.Popup("事件列表", slotIndex, listNormal.ToArray());
			if ((selectIndex >= 0 && selectIndex < changedBase.Count) && (selectIndex != slotIndex || selectedEvent == null))
			{
				selectedEvent = changedBase[selectIndex];
			}
			GUILayout.EndHorizontal();
		}

		private Vector2 m_EventScrollPos;
		void _DrawEventPanel() {
			EditorGUI.BeginChangeCheck();

			GUILayout.BeginVertical("Box");
			m_EventScrollPos = GUILayout.BeginScrollView(m_EventScrollPos);


			if (selectedEvent != null) {
				switch (selectedEvent.type) {
					case AnimatorEventType.Msg:
						_DrawMsgEventPanel();
						break;
				}
			}
			else {
				GUILayout.Label("请选择要编辑的事件。");
			}

			GUILayout.EndScrollView();
			GUILayout.EndVertical();

			if (EditorGUI.EndChangeCheck()) {
				m_isDataChanged = true;
			}
		}

		static readonly string RESOURCES_DIR = "Resources/Prefabs/";
		static readonly string PREFAB_SUFFIX = ".prefab";
		string _GetEffectPrefabPath(GameObject effectPrefab) {
			if (effectPrefab == null)
				return string.Empty;

			string filePath = AssetDatabase.GetAssetPath(effectPrefab);
			bool isUseResourcePath = true;
			if (isUseResourcePath)
			{
				int index = filePath.IndexOf(RESOURCES_DIR);
				if (index < 0)
					return filePath;

				index += RESOURCES_DIR.Length;
				if (index > filePath.Length)
					return filePath;

				filePath = filePath.Substring(index);				
			}

			return filePath;
		}

	    List<string> getAllGameNames()
	    {
	       var games = Directory.GetDirectories(AppConst.GameResRealPath);
	        var gameNames = new List<string>();
	        for (int i = 0; i < games.Length; i++)
	        {
	            games[i] = Path.GetFileNameWithoutExtension(games[i]);
	            gameNames.Add(games[i]);
	        }
	        return gameNames;
	    }

	
		void _DrawMsgEventPanel() {
			if (handler == null) return;

			MsgEvent msgEvent = (MsgEvent)selectedEvent;
			if (msgEvent == null) return;

			GUILayout.BeginVertical();
			GUILayout.Label(string.Format("编辑Msg事件[{0}@{1}]", msgEvent.name, msgEvent.normalizedTime));
			GUILayout.Space(10);
			msgEvent.name = EditorGUILayout.TextField("事件名称", msgEvent.name);
			msgEvent.normalizedTime = EditorGUILayout.FloatField("归一化时间", msgEvent.normalizedTime);
		    msgEvent.normalizedTime = Mathf.Clamp(msgEvent.normalizedTime, 0, 1f);
            msgEvent.msgFunction = EditorGUILayout.TextField("响应函数名称", msgEvent.msgFunction);
			msgEvent.msgParams = EditorGUILayout.TextField("参数", msgEvent.msgParams);
			GUILayout.EndVertical();
		}

        #endregion

	    public static void TestPrefabApply(GameObject selectGo)
	    {
	        if (selectGo == null)
	        {
	            Debug.LogError("请选中需要Apply的Prefab实例");
	            return;
	        }
	        PrefabType pType = EditorUtility.GetPrefabType(selectGo);
	        if (pType != PrefabType.PrefabInstance)
	        {
	            Debug.LogError("选中的实例不是Prefab实例");
	            return;
	        }
	        //这里必须获取到prefab实例的根节点，否则ReplacePrefab保存不了
	        GameObject prefabGo = GetPrefabInstanceParent(selectGo);
	        UnityEngine.Object prefabAsset = null;
	        if (prefabGo != null)
	        {
	            prefabAsset = PrefabUtility.GetPrefabParent(prefabGo);
	            if (prefabAsset != null)
	            {
	                PrefabUtility.ReplacePrefab(prefabGo, prefabAsset, ReplacePrefabOptions.ConnectToPrefab);
	            }
	        }
	        AssetDatabase.SaveAssets();
	    }

	    //遍历获取prefab节点所在的根prefab节点
	    static GameObject GetPrefabInstanceParent(GameObject go)
	    {
	        if (go == null)
	        {
	            return null;
	        }
	        PrefabType pType = EditorUtility.GetPrefabType(go);
	        if (pType != PrefabType.PrefabInstance)
	        {
	            return null;
	        }
	        if (go.transform.parent == null)
	        {
	            return go;
	        }
	        pType = EditorUtility.GetPrefabType(go.transform.parent.gameObject);
	        if (pType != PrefabType.PrefabInstance)
	        {
	            return go;
	        }
	        return GetPrefabInstanceParent(go.transform.parent.gameObject);
	    }

        void _CheckDataSaved() {
			if (m_isDataChanged == false)
				return;

			if (handler == null)
				return;

			if (animatorController == null)
				return;

			string message = string.Format("动画器[{0}]的事件数据发生了变化，是否保存？", animatorController.name);
			bool isSave = EditorUtility.DisplayDialog("是否保存动画器事件？", message, "保存", " 不保存");
		    if (isSave)
		    {
		        TestPrefabApply(handler.gameObject);
                EditorUtility.SetDirty(handler.gameObject);
                AssetDatabase.SaveAssets();
		        AssetDatabase.Refresh();
            }
			m_isDataChanged = false;
		}

		void _OnHandlerChanged() {
			m_animatorLayers = null;
			m_animatorStates = null;
			m_selectedLayerIndex = -1;
			m_selectedStateIndex = -1;
			selectedEvent = null;

			if (handler == null)
				return;


			if (handler.animator == null)
				return;

			AnimatorController animatorController = (AnimatorController)handler.animator.runtimeAnimatorController;
			if (animatorController == null)
				return;

			m_animatorLayers = new string[animatorController.layers.Length];
			m_animatorStates = new Dictionary<string, State[]>();
			m_stateFullNames = new Dictionary<State, string>();
			m_stateMachineFullNames = new Dictionary<AnimatorStateMachine, string>();
			m_animatorTransitions = new Dictionary<int, AnimatorTransitionBase[]>();


			for (int i = 0; i < animatorController.layers.Length; ++i) {
				AnimatorControllerLayer layer = animatorController.layers[i];

				m_animatorLayers[i] = layer.name;

				List<State> stateList = _GetStatesRecursive(layer.stateMachine);
				m_animatorStates.Add(layer.name, stateList.ToArray());

				Dictionary<int, AnimatorTransitionBase[]> transDic = _GetTransitionsRecursive(layer.stateMachine);
				foreach (var e in transDic)
				{
					m_animatorTransitions[e.Key] = e.Value;
				}
			}

			selectedLayerIndex = 0;   
		}

		float GetMinimumExitTimeForState(int stateHash)
		{
			float exitTime = 1;
			if (m_animatorTransitions == null)
				return exitTime;

			AnimatorTransitionBase[] trans = null;
			if (!m_animatorTransitions.TryGetValue(stateHash, out trans) || trans == null)
				return exitTime;

			for (int j = 0; j < trans.Length; ++j)
			{
				AnimatorStateTransition stateTrans = trans[j] as AnimatorStateTransition;
				if (stateTrans == null)
					continue;
				if (stateTrans.hasExitTime && stateTrans.exitTime < exitTime)
				{
					exitTime = stateTrans.exitTime;
				}        
			}

			return exitTime;                  
		}

		Dictionary<int, AnimatorTransitionBase[]> _GetTransitionsRecursive(StateMachine stateMachine)
		{
			Dictionary<int, AnimatorTransitionBase[]> dic = new Dictionary<int, AnimatorTransitionBase[]>();
			for (int i = 0; i < stateMachine.states.Length; ++i)
			{
				State s = stateMachine.states[i].state;
				dic[GetUniqueNameHash(s)] = s.transitions;
			}
			for (int i = 0; i < stateMachine.stateMachines.Length; ++i)
			{            
				foreach (var e in _GetTransitionsRecursive(stateMachine.stateMachines[i].stateMachine))
				{
					dic[e.Key] = e.Value;
				}
			}
			return dic;
		}
    
		List<State> _GetStatesRecursive(StateMachine stateMachine) {
			if (!m_stateMachineFullNames.ContainsKey(stateMachine))
			{
				m_stateMachineFullNames.Add(stateMachine, stateMachine.name);
			}

			List<State> list = new List<State>();
			list.AddRange(_GetAnimatorStates(stateMachine));
			for (int i = 0; i < list.Count; ++i)
			{
				if (!m_stateFullNames.ContainsKey(list[i]))
				{
					m_stateFullNames.Add(list[i], m_stateMachineFullNames[stateMachine] + "." + list[i].name);                
				}                
			}
			for (int i = 0; i < stateMachine.stateMachines.Length; ++i)
			{
				StateMachine childMachine = stateMachine.stateMachines[i].stateMachine;
				if (!m_stateMachineFullNames.ContainsKey(childMachine))
				{
					m_stateMachineFullNames.Add(childMachine, m_stateMachineFullNames[stateMachine] + "." + childMachine.name);
				}
				list.AddRange(_GetStatesRecursive(stateMachine.stateMachines[i].stateMachine));            
			}        
			return list;
		}
        
		State[] _GetAnimatorStates(StateMachine stateMachine) {
			State[] array = new State[stateMachine.states.Length];
			for (int i = 0; i < stateMachine.states.Length; ++i) {
				array[i] = stateMachine.states[i].state;
			}
			return array;
		}

		void _OnSelectedLayerChanged() {
			selectedEvent = null;
			selectedStateIndex = 0;
			Repaint();
		}

		void _OnSelectedStateChanged() {
			selectedEvent = null;
			playbackTime  = 0f;
			Repaint();
		}

		void _OnSelectedEventChanged() {
			if (!Application.isPlaying)
				return;

			if (!isSimulating)
				return;

			if (m_selectedEvent == null)
				return;



			_SimulateStateStatus();
		}

		void _OnEnterSimulatingState() {
			if (!Application.isPlaying)
				return;

			if (handler != null)
				handler.enabled = false;

			if (handler.animator != null)
				handler.animator.speed = 0f;

			_OnSelectedEventChanged();
		}

		void _OnLeaveSimulatingState() {
			if (!Application.isPlaying)
				return;

			if (handler != null) {
				handler.enabled = true;
			}

			if (handler.animator != null)
				handler.animator.speed = 1f;

		}

		void _SimulateStateStatus() {
			if (!Application.isPlaying)
				return;

			if (handler == null)
				return;

			if (handler.animator != null) {
				AnimatorControllerLayer ctllayer = animatorController.layers[selectedLayerIndex];
				int playLayer = ctllayer.syncedLayerIndex < 0 ? selectedLayerIndex : ctllayer.syncedLayerIndex;
				int nameHash = selectedState == null ? -1 : selectedState.nameHash;
				handler.animator.Play(nameHash, playLayer, playbackTime);            
			}
			
		}

		void _SyncStateStatus() {
			if (!Application.isPlaying)
				return;

			if (handler == null)
				return;

			if (animatorStatesInSelectedLayer == null)
				return;

			AnimatorStateInfo currentStateInfo = handler.GetCurrentStateInfo(selectedLayerIndex);
			float _stateNormalizedTime = currentStateInfo.normalizedTime;

			for (int i = 0; i < animatorStatesInSelectedLayer.Length; ++i) {
				if (GetUniqueNameHash(animatorStatesInSelectedLayer[i]) != currentStateInfo.fullPathHash)
					continue;

				selectedStateIndex = i;
				playbackTime = _stateNormalizedTime;
			}
		}
	}
}