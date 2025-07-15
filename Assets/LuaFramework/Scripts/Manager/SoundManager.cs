using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;
using GameCore;
namespace GameLogic
{

    /// <summary>
    /// 扩展音源
    /// </summary>
    public class ExtAudioClip {
        /// <summary>
        /// 音效名
        /// </summary>
        public string name {
            get {
                if (audioClip == null) return string.Empty;
                return audioClip.name;
            }
        }
        /// <summary>
        /// 音效资源
        /// </summary>
        public AudioClip audioClip;

        /// <summary>
        /// 初始化
        /// </summary>
        /// <param name="audioClip"></param>
        public void Init(AudioClip audioClip) {
            this.audioClip = audioClip;
        }

        /// <summary>
        /// 卸载
        /// </summary>
        public void UnLoad() {
            if (audioClip == null) return;
            App.ResMgr.UnLoadAsset(audioClip.name);
        }
    }

    /// <summary>
    /// 扩展音乐播放器
    /// </summary>
    public class ExtAudioSource : MonoBehaviour
    {
        /// <summary>
        /// 音乐播放源
        /// </summary>
        AudioSource audioSource;

        public ExtAudioClip clip{get;set;}

        public bool isPlaying {
            get {
                return audioSource.isPlaying;
            }
        }

        public float volume {
            get 
            {
                return audioSource.volume;
            }
            set {
                audioSource.volume = value;
            }
        }

        public bool loop {
            get 
            {
                return audioSource.loop;
            }
            set 
            {
                audioSource.loop = value;
            }
        }

        private void Awake()
        {
           audioSource = this.gameObject.AddComponent<AudioSource>();
        }


        public void Play() {
            audioSource.Play();
        }

        /// <summary>
        /// 播放
        /// </summary>
        /// <param name="game"></param>
        /// <param name="audioClip"></param>
        public void Play(ExtAudioClip clip)
        {
            this.clip = clip;
            audioSource.clip = clip.audioClip;
            audioSource.Play();
        }

        public void PlayOneShot(ExtAudioClip clip) {
            this.clip = clip;
            audioSource.clip = clip.audioClip;
            audioSource.PlayOneShot(clip.audioClip);
        }

        /// <summary>
        /// 停止播放
        /// </summary>
        public void Stop()
        {
            audioSource.Stop();
        }
    }
    public class SoundManager : UnitySingleton<SoundManager>
    {
        GameCore.ObjectPool<ExtAudioClip> audioClipPool = new GameCore.ObjectPool<ExtAudioClip>(null, (toRealease) =>
        {
            toRealease.UnLoad();
        });
        /// <summary>
        /// 音乐开关
        /// </summary>
        const string IsPlayMusicKey = "IsPlayMusicKey";
        /// <summary>
        /// 音效开关
        /// </summary>
        const string IsPlayAudioKey = "IsPlayAudioKey";

        /// <summary>
        /// 音乐音量
        /// </summary>
        const string MusicVolumeKey = "MusicVolumeKey";

        /// <summary>
        /// 音效音量
        /// </summary>
        const string AudioVolumeKey = "AudioVolumeKey";

        /// <summary>
        /// 同时播放的音效数量
        /// </summary>
        private int aduioCount = 5;
        /// <summary>
        /// 背景音量
        /// </summary>
        private float musicVolume = 1f;
        /// <summary>
        /// 音效音量
        /// </summary>
        private float aduioVolume = 1f;
        /// <summary>
        /// 是否关闭声音
        /// </summary>
        private bool isPlayMusic = true;
        /// <summary>
        /// 是否关闭音效
        /// </summary>
        private bool isPlayAudio = true;
        /// <summary>
        /// 背景音
        /// </summary>
        ExtAudioSource audioSource;
        /// <summary>
        /// 音效音
        /// </summary>
        ExtAudioSource[] audioSources;
        /// <summary>
        /// 下一个背景音
        /// </summary>
        ExtAudioClip nextBGM;

        /// <summary>
        /// 初始化
        /// </summary>
        private void Awake()
        {
            Init();
            gameObject.AddComponent<AudioListener>();
            audioSources = new ExtAudioSource[aduioCount];
            for (int i = 0; i < aduioCount; i++)
            {
                audioSources[i] = gameObject.AddComponent<ExtAudioSource>();
            }
            audioSource = gameObject.AddComponent<ExtAudioSource>();
            audioSource.volume = 0f;
            audioSource.loop = true;
            nextBGM = null;
        }

        /// <summary>
        /// 初始化
        /// </summary>
        private void Init()
        {
            isPlayMusic = PlayerPrefs.GetInt(IsPlayMusicKey, 1) == 1;
            isPlayAudio = PlayerPrefs.GetInt(IsPlayAudioKey, 1) == 1;
        }



        private void Update()
        {
            if (nextBGM != null && isPlayMusic)
            {
                if (audioSource.clip == null || audioSource.volume <= 0)
                {
                    if (audioSource.clip != null)
                    {
                        audioClipPool.Release(audioSource.clip);
                    }
                    audioSource.Play(nextBGM);
                    nextBGM = null;
                }
                else
                {
                    audioSource.volume -= 0.02f;
                }
            }
            else if (audioSource.clip != null && audioSource.volume < musicVolume && isPlayMusic)
            {
                if (!audioSource.isPlaying) audioSource.Play();
                float volume = musicVolume - audioSource.volume;
                audioSource.volume += volume > 0.02f ? 0.02f : volume;
            }
            else if (!isPlayMusic && audioSource.volume > 0)
            {
                audioSource.volume -= 0.02f;
                if (audioSource.volume <= 0) audioSource.Stop();
            }

        }

        /// <summary>
        /// 播放背景音乐
        /// </summary>
        public void PlayMusic(string name)
        {
            try {
                if (string.IsNullOrEmpty(name))
                    return;
                if (audioSource.clip != null && name == audioSource.clip.name)
                    return;
                App.ResMgr.LoadAssetAsync<AudioClip>(name, (tmpName, clip) =>
                {
                    if (clip == null || (nextBGM!=null && clip == nextBGM.audioClip))
                    {
                        App.ResMgr.UnLoadAsset(name);
                        return;
                    }
                    nextBGM = GetClip(clip);
                });
            }
            catch(System.Exception e){
                Debug.LogErrorFormat("PlayMusic error:{0}",e.ToString());
            }
            
        }

        /// <summary>
        /// 播放音效
        /// </summary>
        /// <param name="name">Name.</param>
        public void PlayAudio(string name)
        {
            if (string.IsNullOrEmpty(name))
                return;
            if (!isPlayAudio) return;
            App.ResMgr.LoadAssetAsync<AudioClip>(name,(tmpName,clip) =>
            {
                if (clip == null)
                {
                    App.ResMgr.UnLoadAsset(name);
                    return;
                }
                ExtAudioSource source = GetAudioSoure();
                if (source.isPlaying) source.Stop();
                source.volume = AduioVolume;
                source.PlayOneShot(GetClip(clip));
            });
        }

        /// <summary>
        /// 获取一个audioClip
        /// </summary>
        /// <param name="audioClip"></param>
        /// <returns></returns>
        private ExtAudioClip GetClip(AudioClip audioClip) {
            ExtAudioClip extAudioClip = audioClipPool.Get();
            extAudioClip.Init(audioClip);
            return extAudioClip;
        }

        /// <summary>
        /// 回收一个audioClip
        /// </summary>
        /// <param name="extAudioClip"></param>
        private void ReleaseClip(ExtAudioClip extAudioClip) {
            if (extAudioClip == null) return;
            audioClipPool.Release(extAudioClip);
        }

        /// <summary>
        /// 获取最后一个音效播放器
        /// </summary>
        /// <returns>The audio soure.</returns>
        private ExtAudioSource GetAudioSoure()
        {
            ExtAudioSource source = null;
            for (int i = 0; i < audioSources.Length; i++)
            {
                if (!audioSources[i].isPlaying)
                    source = audioSources[i];
            }
            source = source == null ? audioSources[0] : source;
            ReleaseClip(source.clip);
            return source;
        }

        /// <summary>
        /// 停止所有音效
        /// </summary>
        public void StopAllAudio()
        {
            if (audioSources != null)
            {
                for (int i = 0; i < audioSources.Length; i++)
                {
                    if (audioSources[i] != null)
                    {
                        audioSources[i].Stop();
                        ReleaseClip(audioSources[i].clip);
                    }
                }
            }
        }


        public float MusicVolume
        {
            get {
                return musicVolume;
            }
            set {
                musicVolume = Mathf.Clamp01(value);
                PlayerPrefs.SetFloat(MusicVolumeKey, musicVolume);
            }
        }


        public float AduioVolume
        {
            get
            {
                return aduioVolume;
            }
            set
            {
                aduioVolume = Mathf.Clamp01(value);
                PlayerPrefs.SetFloat(AudioVolumeKey, aduioVolume);
            }
        }

        /// <summary>
        /// 是否播放音乐
        /// </summary>
        public bool IsPlayMusic
        {
            get
            {
                return isPlayMusic;
            }
            set
            {
                isPlayMusic = value;
                PlayerPrefs.SetInt(IsPlayMusicKey, isPlayMusic ? 1 : 0);
            }
        }

        /// <summary>
        /// 是否播放音效
        /// </summary>
        public bool IsPlayAudio
        {
            get
            {
                return isPlayAudio;
            }
            set
            {
                isPlayAudio = value;
                PlayerPrefs.SetInt(IsPlayAudioKey, isPlayAudio ? 1 : 0);
                if (!isPlayAudio)
                    StopAllAudio();
            }
        }
    }
}