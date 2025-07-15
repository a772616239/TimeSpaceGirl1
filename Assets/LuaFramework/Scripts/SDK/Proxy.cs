using System.Collections.Generic;
using UnityEngine;

namespace SDK
{
    public class Proxy : MonoBehaviour
    {
        public virtual void Init() { }
        public virtual void Login() { }
        public virtual void Logout() { }
        public virtual void Exit() { }
        public virtual void SubmitExtraData(SDKSubmitExtraDataArgs args) { }
        public virtual void Pay(SDKPayArgs args) { }
        public virtual bool IsSupportExit() { return false; }
        public virtual string GetDeviceID() { return ""; }
        public virtual string GetIMEICode() { return ""; }
        public virtual string GetPayOrderID() { return ""; }
        public virtual void Bind() { }
        public virtual void Community() { }
        public virtual void CustomerService() { }
        public virtual void Relation(string type) { }
        public virtual void Cancellation() { }
        public virtual bool IsCDKey() { return false; }
        public virtual void CDKey(string cdkey, string serverID, string roleID) { }
        public virtual void LoginPanel_Btn1() { }
        public virtual void LoginPanel_Btn2() { }
        public virtual void CustomEvent(int type, string param) { }
        //public virtual void ShotCapture() { }
        private Queue<Message> messages = new Queue<Message>();
        public void PushMessage(Message msg) { lock (messages) { messages.Enqueue(msg); } }
        public Message PopMessage() { lock (messages) { return messages.Count > 0 ? messages.Dequeue() : null; } }
    }
}

