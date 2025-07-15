using UnityEngine;
using System.Collections;
using System.Collections.Generic;

#if UNITY_EDITOR
using System.IO;
#endif

public enum AnimatorEventType
{
    Effect,
    CameraShake,
    Msg,
}

[System.Serializable]
public class MsgEvent
{
    public MsgEvent()
    {
        type = AnimatorEventType.Msg;
    }
    public string msgFunction;
    public string msgParams;
    public AnimatorEventType type;
    public string name = "";
    public int layer = -1;
    public float normalizedTime = 0.0f;
    public  bool IsEquals(object obj)
    {
        MsgEvent other = obj as MsgEvent;
        if (other == null)
            return false;
        if (this.layer != other.layer
            || this.type != other.type
            || this.name != other.name
            || Mathf.Abs(this.normalizedTime - other.normalizedTime) > Mathf.Epsilon|| this.msgFunction != other.msgFunction
            || this.msgParams != other.msgParams)
            return false;
        return true;
    }
}

[System.Serializable]
public class EventDataDic
{
    public int stateHash;
    public List<MsgEvent> eventList;

    public EventDataDic(int hash)
    {
        stateHash = hash;
        eventList=new List<MsgEvent>();
    }
}

[System.Serializable]
public class AnimatorEventDatas
{
    public List<EventDataDic> m_animatorEventData = null;
    public void MakeSureEventList(int stateHash)
    {
        if (m_animatorEventData != null)
        {
            foreach (var eventList in m_animatorEventData)
            {
                if (eventList.stateHash == stateHash)
                    return;
            }
        }
        else
        {
            m_animatorEventData = new List<EventDataDic>();
        }
        m_animatorEventData.Add(new EventDataDic(stateHash));
    }

    public List<MsgEvent> GetEventList(int stateHash)
    {
        if (m_animatorEventData != null)
        {
            foreach (var dataEventDic in m_animatorEventData)
            {
                if (dataEventDic.stateHash == stateHash)
                    return dataEventDic.eventList;
            }
        }
        return null;
    }

    public List<MsgEvent> GetEventList(int stateHash, int layerIndex)
    {
        if (m_animatorEventData != null)
        {
            List<MsgEvent> events = new List<MsgEvent>();
            foreach (var dataEventDic in m_animatorEventData)
            {
                if (dataEventDic.stateHash == stateHash)
                {
                    for (int i = 0; i < dataEventDic.eventList.Count; ++i)
                    {
                        if (dataEventDic.eventList[i].layer == layerIndex || dataEventDic.eventList[i].layer == -1)
                        {
                            events.Add(dataEventDic.eventList[i]);
                        }
                    }
                    return events;
                }
            }
        }
        return null;
    }

    /// 干掉相同的事件
    public bool RemoveSameEvents()
    {
        bool ret = false;
        foreach (var itemData in m_animatorEventData)
        {
            var elem = itemData.eventList;
            for (int i = elem.Count - 1; i >= 0; --i)
            {
                for (int j = i - 1; j >= 0; --j)
                {
                    if (elem[i].IsEquals(elem[j]))
                    {
                        ret = true;
                        Debug.Log("removesameevents: key=" + itemData.stateHash + " type=" + elem[i].type + " name=" + elem[i].name + " time=" + elem[i].normalizedTime + " layer=" + elem[i].layer);
                        elem.RemoveAt(i);
                        break;
                    }
                }
            }
        }
        return ret;
    }


    public void Remove(int stateHash)
    {
        if (m_animatorEventData != null)
        {
            List<EventDataDic> deletEvents = new List<EventDataDic>();
            foreach (var dataEventDic in m_animatorEventData)
            {
                if (dataEventDic.stateHash == stateHash)
                {
                    deletEvents.Add(dataEventDic);
                }
            }
            foreach(var delDataEvent in deletEvents)
            {
                m_animatorEventData.Remove(delDataEvent);
            }
        }
    }

    public bool HasEventStateHash(int stateHash)
    {
        foreach (var dataEventDic in m_animatorEventData)
        {
           if( dataEventDic.stateHash== stateHash)
            {
                return true;
            }
        }
        return false;
    }

    public bool AddEvent(int stateHash, MsgEvent addEvent)
    {
        List<MsgEvent> eventList= GetEventList(stateHash);
        if (eventList==null)
        {
            eventList = new List<MsgEvent>();
            var eventDataDic= new EventDataDic(stateHash);
            eventDataDic.eventList.Add(addEvent);
            m_animatorEventData.Add(eventDataDic);
        }
        else
        {
            eventList.Add(addEvent);
        }
        return true;
    }

    public bool RemoveEvent(int stateHash, MsgEvent deleteEvent)
    {
        List<MsgEvent> eventList = GetEventList(stateHash);
        if (eventList == null)
        {
            return false;
        }
        else
        {
            return eventList.Remove(deleteEvent);
        }
    }
}

[ExecuteInEditMode]
[RequireComponent(typeof(Animator))]
public class AnimatorEventHandler : MonoBehaviour {
	class LayerRuntime {
		public int stateNameHash = 0;
		public float stateNormalizedTime = -0.000001f;
		public float stateLength = 1;
		public bool stateLoop = false;
	}

    #region private members
    private Animator m_animator = null;
    public AnimatorEventDatas animatorEventData = null;
	private Dictionary<int, LayerRuntime> m_layerRuntimeDictionary = new Dictionary<int, LayerRuntime>();
    #endregion

    #region public members
    public bool isUpdateEventInStateEndFrame = false;
    #endregion

    #region public properties
    public Animator animator {
		get {
			if (m_animator == null) {
				m_animator = GetComponent<Animator>();
			}

			return m_animator;
		}
	}

	#endregion

	void Start() {
		Init();
	}



    void Init() {
		if (animatorEventData == null)
        {
            animatorEventData = new AnimatorEventDatas();
        }

		m_layerRuntimeDictionary.Clear();
		for (int i = 0; i < animator.layerCount; i++) {
			m_layerRuntimeDictionary.Add(i, new LayerRuntime());
		}
	}

    public AnimatorStateInfo GetCurrentStateInfo(int layerIndex) {
		if (animator.IsInTransition(layerIndex)) {
			return animator.GetNextAnimatorStateInfo(layerIndex);
		}
		return animator.GetCurrentAnimatorStateInfo(layerIndex);
	}

	void Update()
    {
		if (animator == null)
			return;

		if (animatorEventData == null)
			return;

		if (Time.deltaTime <= 0)
			return;

        if(Application.isPlaying)
        {
            for (int i = 0; i < animator.layerCount; ++i)
            {
                _UpdateLayer(i);
            }
        }
    }



	void _UpdateLayerChild(float stateNormalizedTime, LayerRuntime layerRuntime, int layerIndex)
    {
		int stateNameHash = layerRuntime.stateNameHash;
		List<MsgEvent> eventList = animatorEventData.GetEventList(stateNameHash);
		if (eventList == null)
			return;

		float currentTime = Time.time;
		float currentNormalizedTime = stateNormalizedTime;
		float lastNormalizedTime = layerRuntime.stateNormalizedTime;

		layerRuntime.stateNormalizedTime = currentNormalizedTime;

		int currentTimeFloor = Mathf.FloorToInt(currentNormalizedTime);
		int lastTimeFloor = Mathf.FloorToInt(lastNormalizedTime);


		float stateLength = layerRuntime.stateLength;
		bool stateLoop = layerRuntime.stateLoop;

		for (int i = 0; i < eventList.Count; ++i) {
			MsgEvent animatorEvent = eventList[i];
			if (layerIndex != animatorEvent.layer && animatorEvent.layer != -1)
				continue;

			if (!stateLoop) {
				float eventNormailzedTime = animatorEvent.normalizedTime;
				if (eventNormailzedTime > lastNormalizedTime && eventNormailzedTime <= currentNormalizedTime) {
					float deltaNormalizedTime = currentNormalizedTime - animatorEvent.normalizedTime;
					float eventFiredTime = currentTime - deltaNormalizedTime * stateLength;
                    App.LuaMgr.CallFunction(eventList[i].msgFunction,eventList[i].msgParams);
                   
                }
			} else {
				float floorTime = currentTime - Mathf.Repeat(currentNormalizedTime, 1f) * stateLength;
				for (int floor = currentTimeFloor; floor >= lastTimeFloor && floor >= 0; --floor, floorTime -= stateLength) {
					float eventNormailzedTime = floor + animatorEvent.normalizedTime;
					if (eventNormailzedTime > lastNormalizedTime && eventNormailzedTime <= currentNormalizedTime) {
						float eventFiredTime = floorTime + animatorEvent.normalizedTime * stateLength;
                        App.LuaMgr.CallFunction(eventList[i].msgFunction, eventList[i].msgParams);
                    }
				}
			}
		}
	}

	// 是否处理状态切换结束帧的事件
	public bool IsUpdateEventInStateEndFrame {
		get {
			return isUpdateEventInStateEndFrame;
		}
		set {
			isUpdateEventInStateEndFrame = value;
		}
	}

	private LayerRuntime layerRuntime;
	void _UpdateLayer(int layerIndex)
    {
		AnimatorStateInfo stateInfo = GetCurrentStateInfo(layerIndex);
		if (stateInfo.length <= 0f) { // 对于Empty做处理（其实是异常情况）            
			if (m_layerRuntimeDictionary.TryGetValue(layerIndex, out layerRuntime)) {
				layerRuntime.stateNameHash = stateInfo.fullPathHash;
			}
			return;
		}

        float _stateNormalizedTime = stateInfo.normalizedTime;

		if (!m_layerRuntimeDictionary.TryGetValue(layerIndex, out layerRuntime))
        {
			return;
		}
		if (layerRuntime.stateNameHash != stateInfo.fullPathHash||(_stateNormalizedTime < 1&& (_stateNormalizedTime < layerRuntime.stateNormalizedTime|| Time.deltaTime > stateInfo.length)))
        {
			if (isUpdateEventInStateEndFrame && layerRuntime.stateNameHash != stateInfo.fullPathHash)
            {
				float stateNormalizedTime = layerRuntime.stateNormalizedTime+ (Time.deltaTime - _stateNormalizedTime * stateInfo.length) / layerRuntime.stateLength;
				if (stateNormalizedTime > 1)
                {
					stateNormalizedTime = 1;
				}
				_UpdateLayerChild(stateNormalizedTime, layerRuntime, layerIndex);
			}

			layerRuntime.stateLength = stateInfo.length;
			layerRuntime.stateLoop = stateInfo.loop;
			layerRuntime.stateNameHash = stateInfo.fullPathHash;
			layerRuntime.stateNormalizedTime = -1f;
		}
		_UpdateLayerChild(_stateNormalizedTime, layerRuntime, layerIndex);
	}

	IEnumerator UpdateLayer() {
		while (true) {
			yield return new WaitForEndOfFrame();

			for (int i = 0; i < animator.layerCount; ++i) {
				_UpdateLayer(i);
			}
		}
	}
}
