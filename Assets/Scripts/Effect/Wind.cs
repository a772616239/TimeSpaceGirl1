using UnityEngine;
using System.Collections;
using DG.Tweening;

public class Wind : MonoBehaviour {

	public Material[] materials;

	public float duration = 5.0f;
	public float minSpeed = 3.0f;
	public float maxSpeed = 10.0f;


	void Reset(){
//		material.DOFloat(1,"_Speed",duration).SetEase(Ease.InOutSine);
		this.enabled = false;
	}

	void OnStart (){
		
	}

	void OnWind(){
		
	}
	// Use this for initialization
	void OnEnable () {

		for(int i=0;i<materials.Length;i++){
			Sequence s = DOTween.Sequence();
			s.Append(materials[i].DOFloat(maxSpeed,"_Speed",0.0f).SetEase(Ease.Linear));
	
			s.Append(materials[i].DOFloat(minSpeed,"_Speed",0.0f).SetEase(Ease.InOutSine).SetDelay(duration));
	
			s.AppendCallback(Reset);
		}


	}


}
