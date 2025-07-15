using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using LuaInterface;
using GameCore;
namespace GameLogic
{

    /// <summary>
    /// ��չ��Դ
    /// </summary>
    public class ExtAudioClip {
        /// <summary>
        /// ��Ч��
        /// </summary>
        public string name {
            get {
                if (audioClip == null) return string.Empty;
                return audioClip.name;
            }
        }
        /// <summary>
        /// ��Ч��Դ
        /// </summary>
        public AudioClip audioClip;

        /// <summary>
        /// ��ʼ��
        /// </summary>
        /// <param name="audioClip"></param>
        public void Init(AudioClip audioClip) {
            this.audioClip = audioClip;
        }

        /// <summary>
        /// ж��
        /// </summary>
        public void UnLoad() {
            if (audioClip == null) return;
            App.ResMgr.UnLoadAsset(audioClip.name);
        }
    }

    /// <summary>
    /// ��չ���ֲ�����
    /// </summary>
    public class ExtAudioSource : MonoBehaviour
    {
        /// <summary>
        /// ���ֲ���Դ
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
        /// ����
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
        /// ֹͣ����
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
        /// ���ֿ���
        /// </summary>
        const string IsPlayMusicKey = "IsPlayMusicKey";
        /// <summary>
        /// ��Ч����
        /// </summary>
        const string IsPlayAudioKey = "IsPlayAudioKey";

        /// <summary>
        /// ��������
        /// </summary>
        const string MusicVolumeKey = "MusicVolumeKey";

        /// <summary>
        /// ��Ч����
        /// </summary>
        const string AudioVolumeKey = "AudioVolumeKey";

        /// <summary>
        /// ͬʱ���ŵ���Ч����
        /// </summary>
        private int aduioCount = 5;
        /// <summary>
        /// ��������
        /// </summary>
        private float musicVolume = 1f;
        /// <summary>
        /// ��Ч����
        /// </summary>
        private float aduioVolume = 1f;
        /// <summary>
        /// �Ƿ�ر�����
        /// </summary>
        private bool isPlayMusic = true;
        /// <summary>
        /// �Ƿ�ر���Ч
        /// </summary>
        private bool isPlayAudio = true;
        /// <summary>
        /// ������
        /// </summary>
        ExtAudioSource audioSource;
        /// <summary>
        /// ��Ч��
        /// </summary>
        ExtAudioSource[] audioSources;
        /// <summary>
        /// ��һ��������
        /// </summary>
        ExtAudioClip nextBGM;

        /// <summary>
        /// ��ʼ��
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
        /// ��ʼ��
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
        /// ���ű�������
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
        /// ������Ч
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
        /// ��ȡһ��audioClip
        /// </summary>
        /// <param name="audioClip"></param>
        /// <returns></returns>
        private ExtAudioClip GetClip(AudioClip audioClip) {
            ExtAudioClip extAudioClip = audioClipPool.Get();
            extAudioClip.Init(audioClip);
            return extAudioClip;
        }

        /// <summary>
        /// ����һ��audioClip
        /// </summary>
        /// <param name="extAudioClip"></param>
        private void ReleaseClip(ExtAudioClip extAudioClip) {
            if (extAudioClip == null) return;
            audioClipPool.Release(extAudioClip);
        }

        /// <summary>
        /// ��ȡ���һ����Ч������
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
        /// ֹͣ������Ч
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
        /// �Ƿ񲥷�����
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
        /// �Ƿ񲥷���Ч
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