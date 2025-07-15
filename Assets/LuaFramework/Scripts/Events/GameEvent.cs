using System;
using System.Collections.Generic;
using System.Threading;

namespace GameLogic
{
	/// <summary>
	/// event execute
	/// </summary>
	internal struct GameEventInfo {
		public GameEventHandler eventHandler;
		public object[] args;
	}


	/// <summary>
	/// Event handler.
	/// external event function format
	/// </summary>
	public delegate void GameEventHandler(params object[] args);


	public class GameEvent {

		/// <summary>
		/// event execute list
		/// </summary>
		private List<GameEventInfo> mAsyncEventList;


		/// <summary>
		/// The event list.
		/// </summary>
		private Dictionary<string, List<GameEventHandler>> mEventDic;

		/// <summary>
		/// just use once of event
		/// </summary>
		private Dictionary<string, GameEventHandler> mUseOnceEventDic;

		public GameEvent() {
			mAsyncEventList = new List<GameEventInfo>();
			mEventDic = new Dictionary<string, List<GameEventHandler>>();
			mUseOnceEventDic = new Dictionary<string, GameEventHandler>();
		}


		/// <summary>
		/// Adds the event.
		/// </summary>
		public void AddEvent(string type, GameEventHandler handler, bool isUseOnce = false) {
			List<GameEventHandler> handlerList = mEventDic.ContainsKey(type) ? mEventDic[type] : null;
			if (handlerList == null) {
				mEventDic[type] = new List<GameEventHandler>();
			}
			if (mEventDic[type].Contains(handler))
				return;

			mEventDic[type].Add(handler);
			if (isUseOnce && !mUseOnceEventDic.ContainsKey(type))
				mUseOnceEventDic.Add(type, handler);
		}



		/// <summary>
		/// Removes the event.
		/// </summary>
		public void RemoveEvent(string type, GameEventHandler handler) {
			List<GameEventHandler> handlerList = mEventDic.ContainsKey(type) ? mEventDic[type] : null;
			if (handlerList != null && handlerList.Contains(handler)) {
				handlerList.Remove(handler);
			}
			if (mUseOnceEventDic.ContainsKey(type) && mUseOnceEventDic[type] == handler)
				mUseOnceEventDic.Remove(type);
		}


		/// <summary>
		/// Removes All this type of event.
		/// </summary>
		public void RemoveEvent(string type) {
			if (mEventDic.ContainsKey(type))
				mEventDic.Remove(type);
			if (mUseOnceEventDic.ContainsKey(type))
				mUseOnceEventDic.Remove(type);
		}


		/// <summary>
		/// remove all event
		/// </summary>
		public void RemoveEvent() {
			mEventDic.Clear();
			mUseOnceEventDic.Clear();
		}


		/// <summary>
		/// Dispatch the specified type, target and args. sync type. 
		/// </summary>
		public void DispatchEvent(string type, params object[] args) {
			List<GameEventHandler> handlerList = mEventDic.ContainsKey(type) ? mEventDic[type] : null;
			if (handlerList != null && HasEvent(type)) {
				for (short i = 0; i < handlerList.Count; i++) {
					handlerList[i](args);

					if (mUseOnceEventDic.ContainsKey(type) && mUseOnceEventDic[type] == handlerList[i])
						RemoveEvent(type, handlerList[i]);
				}
			}
		}

		/// <summary>
		/// Dispatch the specified type, target and args. async type, in idle frame execute function
		/// </summary>
		public void DispatchAsyncEvent(string type, params object[] args) {
			List<GameEventHandler> handlerList = mEventDic.ContainsKey(type) ? mEventDic[type] : null;
			if (handlerList != null && HasEvent(type)) {
				for (short i = 0; i < handlerList.Count; i++) {
					mAsyncEventList.Add(new GameEventInfo() { args = args, eventHandler = handlerList[i] });
					if (mUseOnceEventDic.ContainsKey(type) && mUseOnceEventDic[type] == handlerList[i])
						RemoveEvent(type, handlerList[i]);
				}
			}
		}

		/// <summary>
		/// Dispatch the specified type, target and args. in new child thread execute function
		/// </summary>
		[System.Obsolete("Do not use temporary")]
		public void DispatchThreadEvent(string type, object args) {
			///////////////
			List<GameEventHandler> handlerList = mEventDic.ContainsKey(type) ? mEventDic[type] : null;
			if (handlerList != null && HasEvent(type)) {
				for (short i = 0; i < handlerList.Count; i++) {
					Thread thread = new Thread((object arg) => handlerList[i]());
					thread.Start(args);
					if (mUseOnceEventDic.ContainsKey(type) && mUseOnceEventDic[type] == handlerList[i])
						RemoveEvent(type, handlerList[i]);
				}
			}
		}



		/// <summary>
		/// 
		/// </summary>
		/// <param name="type"></param>
		/// <returns></returns>
		public bool HasEvent(string type) {
			return mEventDic.ContainsKey(type);
		}

		/// <summary>
		/// 消息循环
		/// </summary>
		public void UpdateEvent()
        {
			for (short i = 0; i < mAsyncEventList.Count; i++) {
				GameEventInfo taskEvent = mAsyncEventList[i];
				mAsyncEventList.Remove(taskEvent);
				taskEvent.eventHandler(taskEvent.args);
			}
		}


		/// <summary>
		/// 
		/// </summary>
		public void Dispose() 
        {
			mUseOnceEventDic.Clear();
			mEventDic.Clear();
			mAsyncEventList.Clear();
			mAsyncEventList = null;
			mEventDic = null;
			mUseOnceEventDic = null;
		}
	}
}