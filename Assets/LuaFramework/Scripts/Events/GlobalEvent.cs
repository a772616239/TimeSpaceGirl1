using System;
using eEventName = System.String;

namespace GameLogic
{
	public class GlobalEvent : GameEvent 
    {
		/// <summary>
		/// The _inst.
		/// </summary>
		private static GlobalEvent _inst = new GlobalEvent();
		public static GlobalEvent inst {
			get {
				return _inst;
			}
		}

		/// <summary>
		/// Adds the event.
		/// </summary>
		public static void add(string type, GameEventHandler handler, bool isUseOnce = false) {
			inst.AddEvent(type, handler, isUseOnce);
		}

		/// <summary>
		/// Removes the event.
		/// </summary>
		public static void remove(string type, GameEventHandler handler) {
			inst.RemoveEvent(type, handler);
		}


		/// <summary>
		/// Removes All this type of event.
		/// </summary>
		public static void remove(string type) {
			inst.RemoveEvent(type);
		}


		/// <summary>
		/// remove all event
		/// </summary>
		public static void remove() {
			inst.RemoveEvent();
		}


		/// <summary>
		/// Dispatch the specified type, target and args. sync type. 
		/// </summary>
		public static void dispatch(string type, params object[] args) {
			inst.DispatchEvent(type, args);
		}


		/// <summary>
		/// Dispatch the specified type, target and args. async type, in idle frame execute function
		/// </summary>
		public static void dispatchAsync(string type, params object[] args) {
			inst.DispatchAsyncEvent(type, args);
		}

		/// <summary>
		/// 
		/// </summary>
		/// <param name="type"></param>
		/// <returns></returns>
		public static bool hasEvent(string type) {
			return inst.HasEvent(type);
		}

		/// <summary>
		/// 消息循环
		/// </summary>
		public static void updateEvent() 
        {
			inst.UpdateEvent();
		}

		/// <summary>
		/// Lua需要调用
		/// </summary>
		public static void AddLuaEvent(eEventName eName, GameEventHandler handler) 
        {
			if (handler == null) 
            {
                Util.LogError("AddLuaEvent Failed! Invalid Handler");
				return;
			}
			inst.AddEvent(eName, handler, false);
		}

		public static void RemoveLuaEvent(eEventName eName, GameEventHandler handler) {
			inst.RemoveEvent(eName, handler);
		}

		public static void DispatchLuaEvent(eEventName eName, params object[] args) {
			inst.DispatchEvent(eName, args);
		}

	}
}
