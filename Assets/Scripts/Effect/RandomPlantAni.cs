using UnityEngine;
using System.Collections;
using System.Collections.Generic;


public class RandomPlantAni : MonoBehaviour {

	public string aniStr = "";

	private Animator animator = null;
	private string currClipName = "";
	private string[] aniList = null;


	// Use this for initialization
	void Start () {

		animator = gameObject.GetComponent<Animator>();

		if(aniStr != null){
			aniList = aniStr.Split(',');
		}else{
			return;
		}
		currClipName = aniList[Random.Range(0,aniList.Length)];
		//animator.Play(currClipName);
		animator.PlayInFixedTime (currClipName);
			
	}
	
	// Update is called once per frame
	//void Update(){
	void FixedUpdate () {
		AnimatorStateInfo state =  animator.GetCurrentAnimatorStateInfo(0);

		if(state.normalizedTime >= 1){
			//switch animator
			string name = aniList[Random.Range(0,aniList.Length)];
			//if(name == currClipName){
			//	name = aniList[Random.Range(0,aniList.Length)]; 
			//}
			//Debug.Log(name);
			currClipName = name;

			//animator.Play(currClipName);
			animator.PlayInFixedTime (currClipName);
		}

	}
}
