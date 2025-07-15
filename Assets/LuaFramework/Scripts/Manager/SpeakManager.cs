using System.Collections;
using System.Collections.Generic;
using UnityEngine;
//using agora_gaming_rtc;
using GameCore;
using GameLogic;
namespace GameLogic {
    public class SpeakManager : UnitySingleton<SpeakManager>
    {
        public const string Speaker_OnSelfSpeakVolume = "Speaker_OnSelfSpeakVolume";
        public const string Speaker_OnPlayerStartSpeak = "Speaker_OnPlayerStartSpeak";
        public const string Speaker_OnPlayerEndSpeak = "Speaker_OnPlayerEndSpeak";

        //private static IRtcEngineForGaming mRtcEngine = null;

        // PLEASE KEEP THIS App ID IN SAFE PLACE
        // Get your own App ID at https://dashboard.agora.io/
        // After you entered the App ID, remove ## outside of Your App ID
        private static string appId = "7ea15b5fb18543c7a6d7ba57a2f20ad4";

        private static uint selfID;

        //void Awake()
        //{
        //    QualitySettings.vSyncCount = 0;
        //    Application.targetFrameRate = 30;
        //}

        // Use this for initialization

        void Start()
        {
#if UNITY_EDITOR
            return;
#endif
            return;
            //mRtcEngine = RtcEngineForGaming.getEngine(appId);
            //mRtcEngine.OnJoinChannelSuccess += (string channelName, uint uid, int elapsed) =>
            //{
            //    string joinSuccessMessage = string.Format("joinChannel callback uid: {0}, channel: {1}, version: {2}", uid, channelName, RtcEngineForGaming.GetSdkVersion());
            //    selfID = uid;
            //    //Debug.LogWarning("~~~~~~~~~~~~~~~~~~~~~~~~~~~~Self ID:    " + uid);
            //    Debug.Log(joinSuccessMessage);
            //};

            //mRtcEngine.OnLeaveChannel += (RtcStats stats) =>
            //{
            //    string leaveChannelMessage = string.Format("onLeaveChannel callback duration {0}, tx: {1}, rx: {2}, tx kbps: {3}, rx kbps: {4}", stats.duration, stats.txBytes, stats.rxBytes, stats.txKBitRate, stats.rxKBitRate);
            //    Debug.Log(leaveChannelMessage);
            //};

            //mRtcEngine.OnUserJoined += (uint uid, int elapsed) =>
            //{
            //    string userJoinedMessage = string.Format("onUserJoined callback uid {0} {1}", uid, elapsed);
            //    Debug.Log(userJoinedMessage);
            //};

            //mRtcEngine.OnUserOffline += (uint uid, USER_OFFLINE_REASON reason) =>
            //{
            //    string userOfflineMessage = string.Format("onUserOffline callback uid {0} {1}", uid, reason);
            //    Debug.Log(userOfflineMessage);
            //};

            //mRtcEngine.OnVolumeIndication += (AudioVolumeInfo[] speakers, int speakerNumber, int totalVolume) =>
            //{
            //    //if (speakerNumber == 0 || speakers == null)
            //    //{
            //    //    //Debug.Log(string.Format("onVolumeIndication only local {0}", totalVolume));
            //    //}

            //    for (int idx = 0; idx < speakerNumber; idx++)
            //    {
            //        string volumeIndicationMessage = string.Format("{0} onVolumeIndication {1} {2}", speakerNumber, speakers[idx].uid, speakers[idx].volume);
            //        uint speakerID = speakers[idx].uid;
            //        if (speakerID == 0)
            //        {
            //            Util.CallLuaMessage(Speaker_OnSelfSpeakVolume, speakers[idx].volume);
            //        }
            //    }
            //};

            //mRtcEngine.OnUserMuted += (uint uid, bool muted) =>
            //{
            //    // string userMutedMessage = string.Format("onUserMuted callback uid {0} {1}", uid, muted);
            //    //Debug.Log(userMutedMessage);

            //    uint id = uid;
            //    if (id == 0) id = selfID;
            //    Util.CallLuaMessage(muted ? Speaker_OnPlayerEndSpeak : Speaker_OnPlayerStartSpeak, id);
            //};

            //mRtcEngine.OnWarning += (int warn, string msg) =>
            //{
            //    string description = RtcEngineForGaming.GetErrorDescription(warn);
            //    string warningMessage = string.Format("onWarning callback {0} {1} {2}", warn, msg, description);
            //    Debug.Log(warningMessage);
            //};

            //mRtcEngine.OnError += (int error, string msg) =>
            //{
            //    string description = RtcEngineForGaming.GetErrorDescription(error);
            //    string errorMessage = string.Format("onError callback {0} {1} {2}", error, msg, description);
            //    Debug.Log(errorMessage);
            //};

            //mRtcEngine.OnRtcStats += (RtcStats stats) =>
            //{
            //    string rtcStatsMessage = string.Format("onRtcStats callback duration {0}, tx: {1}, rx: {2}, tx kbps: {3}, rx kbps: {4}, tx(a) kbps: {5}, rx(a) kbps: {6} users {7}",
            //        stats.duration, stats.txBytes, stats.rxBytes, stats.txKBitRate, stats.rxKBitRate, stats.txAudioKBitRate, stats.rxAudioKBitRate, stats.users);
            //    Debug.Log(rtcStatsMessage);

            //    int lengthOfMixingFile = mRtcEngine.GetAudioMixingDuration();
            //    int currentTs = mRtcEngine.GetAudioMixingCurrentPosition();

            //    string mixingMessage = string.Format("Mixing File Meta {0}, {1}", lengthOfMixingFile, currentTs);
            //    Debug.Log(mixingMessage);
            //};

            //mRtcEngine.OnAudioRouteChanged += (AUDIO_ROUTE route) =>
            //{
            //    string routeMessage = string.Format("onAudioRouteChanged {0}", route);
            //    Debug.Log(routeMessage);
            //};

            //mRtcEngine.OnRequestChannelKey += () =>
            //{
            //    string requestKeyMessage = string.Format("OnRequestChannelKey");
            //    Debug.Log(requestKeyMessage);
            //};

            //mRtcEngine.OnConnectionInterrupted += () =>
            //{
            //    string interruptedMessage = string.Format("OnConnectionInterrupted");
            //    Debug.Log(interruptedMessage);
            //};

            //mRtcEngine.OnConnectionLost += () =>
            //{
            //    string lostMessage = string.Format("OnConnectionLost");
            //    Debug.Log(lostMessage);
            //};

            //mRtcEngine.SetLogFilter(LOG_FILTER.INFO);

            //// mRtcEngine.setLogFile("path_to_file_unity.log");

            //mRtcEngine.SetChannelProfile(CHANNEL_PROFILE.GAME_FREE_MODE);

            //// mRtcEngine.SetChannelProfile (CHANNEL_PROFILE.GAME_COMMAND_MODE);
            //// mRtcEngine.SetClientRole (CLIENT_ROLE.BROADCASTER);

            //MuteLocalAudioStream(true);
            //EnableAudioVolumeIndication(200, 3);
        }

        // Update is called once per frame
        //void Update()
        //{
        //    if (mRtcEngine != null)
        //    {
        //        mRtcEngine.Poll();
        //    }
        //}

        //public void SetChannelProfile(int profileType)
        //{
        //    StartCoroutine(SetChannelProfile_Co(profileType));
        //}

        //IEnumerator SetChannelProfile_Co(int profileType)
        //{
        //    yield return new WaitForEndOfFrame();
        //    if (mRtcEngine == null) yield break;

        //    mRtcEngine.SetChannelProfile((CHANNEL_PROFILE)profileType);
        //}

        //public void JoinChannel(string channelName, int uid)
        //{
        //    StartCoroutine(JoinChannel_Co(channelName, uid));
        //}

        //IEnumerator JoinChannel_Co(string channelName, int uid)
        //{
        //    yield return new WaitForEndOfFrame();
        //    if (mRtcEngine == null) yield break;

        //    Debug.Log(string.Format("tap joinChannel with channel name {0}", channelName));
        //    if (string.IsNullOrEmpty(channelName))
        //    {
        //        yield break;
        //    }

        //    mRtcEngine.JoinChannel(channelName, "extra", (uint)uid);
        //    MuteLocalAudioStream(true);
        //    // mRtcEngine.JoinChannelByKey ("YOUR_CHANNEL_KEY", channelName, "extra", 9527);
        //}

        //public void LeaveChannel()
        //{
        //    StartCoroutine(LeaveChannel_Co());
        //}

        //IEnumerator LeaveChannel_Co()
        //{
        //    yield return new WaitForEndOfFrame();
        //    if (mRtcEngine == null) yield break;

        //    // int duration = mRtcEngine.GetAudioMixingDuration ();
        //    // int current_duration = mRtcEngine.GetAudioMixingCurrentPosition ();

        //    // IAudioEffectManager effect = mRtcEngine.GetAudioEffectManager();
        //    // effect.StopAllEffects ();

        //    mRtcEngine.LeaveChannel();
        //}

        //public void MuteLocalAudioStream(bool isMute)
        //{
        //    StartCoroutine(MuteLocalAudioStream_Co(isMute));
        //}

        //IEnumerator MuteLocalAudioStream_Co(bool isMute)
        //{
        //    yield return new WaitForEndOfFrame();
        //    if (mRtcEngine == null) yield break;

        //    mRtcEngine.MuteLocalAudioStream(isMute);
        //}

        //public void EnableAudioVolumeIndication(int interval, int smooth)
        //{
        //    StartCoroutine(EnableAudioVolumeIndication_Co(interval, smooth));
        //}

        //IEnumerator EnableAudioVolumeIndication_Co(int interval, int smooth)
        //{
        //    yield return new WaitForEndOfFrame();
        //    if (mRtcEngine == null) yield break;

        //    mRtcEngine.EnableAudioVolumeIndication(interval, smooth);
        //}

    }


}
