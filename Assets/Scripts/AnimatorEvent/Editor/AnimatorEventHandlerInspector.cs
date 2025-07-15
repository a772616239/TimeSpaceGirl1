using UnityEngine;
using UnityEditor;

namespace Game {
	[CustomEditor(typeof(AnimatorEventHandler))]
	public class AnimatorEventHandlerInspector : Editor {
		public override void OnInspectorGUI() {

			if (GUILayout.Button("编辑动画器事件")) {
				AnimatorEventEditor.ShowWindow();
			}

			AnimatorEventHandler animatorEventHandler = (AnimatorEventHandler)target;
			animatorEventHandler.isUpdateEventInStateEndFrame = GUILayout.Toggle(animatorEventHandler.isUpdateEventInStateEndFrame, "是否处理状态切换结束帧事件");
		   
			if (AnimatorEventEditor.instance != null) {

				AnimatorEventEditor.instance.handler = (AnimatorEventHandler)target;

			}
		}
	}
}
