using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AudioPlayHelper : MonoBehaviour {

    List<AudioSource> sourceList = new List<AudioSource>();


    public void Reset()
    {
        for (int i = 0; i < sourceList.Count; i++)
        {
            sourceList[i].Stop();
            sourceList[i].clip = null;
        }
    }

    public void UnloadSound(AudioClip clip)
    {
        for (int i = 0; i < sourceList.Count; i++)
        {
            if (sourceList[i].clip.Equals(clip))
            {
                sourceList[i].Stop();
                sourceList[i].clip = null;
            }
        }
    }

    public void GenAudioSources(int count)
    {
        for (int i = 0; i < count; i++)
        {
            CreateAudioSource();
        }
    }

    public void PlayAudio(AudioClip clip, float volume)
    {
        if (clip == null)
            return;

        var source = GetAvaliableAudioSource();
        source.volume = volume;
        source.clip = clip;
        source.Play();
        //source.volume = volume;
        //source.PlayOneShot(clip);
    }

    public void PlayAudio(AudioClip clip, float volume,  Vector3 offset)
    {
        if (clip == null)
            return;

        var source = GetAvaliableAudioSource();
        source.transform.position = offset;
        source.volume = volume;
        source.clip = clip;
        source.Play();

        //source.volume = volume;
        //source.PlayOneShot(clip);
    }

    AudioSource GetAvaliableAudioSource()
    {
        for (int i = 0; i < sourceList.Count; i++)
        {
            if (sourceList[i].clip == null)
                return sourceList[i];

            if (!sourceList[i].isPlaying)
                return sourceList[i];
        }

        return CreateAudioSource();
    }

    AudioSource CreateAudioSource()
    {
        var go = new GameObject();
        go.transform.parent = transform;
        go.transform.localPosition = Vector3.zero;
        go.name = sourceList.Count.ToString();
        var soruce = go.AddComponent<AudioSource>();
        soruce.loop = false;
        soruce.playOnAwake = false;
        sourceList.Add(soruce);
        return soruce;
    }
}
