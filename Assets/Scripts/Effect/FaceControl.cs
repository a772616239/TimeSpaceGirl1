using System;
using System.Collections.Generic;
using UnityEngine;


public class FaceControl : MonoBehaviour
{

	//======== eye
	public Transform leftEye;  //左眼
	public Transform rightEye; //右眼
	public Vector2 eyeRowCol;  //眼行列数
	public Vector2 eyeLeftEmotionNormal; //左眼默认眼帧
	public Vector2 eyeRightEmotionNormal; //右眼默认帧
	public Vector2 eyeLeftEmotionChange; //左眼表情帧
	public Vector2 eyeRightEmotionChange; //右眼表情帧
	public int eyeEmotionRepeat = 1;  //眼动画总次数
	public float eyeEmotionFps = 1; //每秒动画次数
	public bool eyeEmotionSwitch = false; //眼动画开头

	private bool eyeRunning = false;
	private int currEyeIndex = 0;
	private int currEyeRepeatCount = 0;
	private float currEyeTime = 0.0f;
	private float lastEyeTime = 0.0f;

	//======== mouth
	public Transform mouth;   //嘴
	public Vector2 mouthRowCol;  //嘴行列数
	public int mouthEamotionRepeat =-1; //嘴动画次数, -1为一直动
	public float mouthEmotionFps = 2; //第秒嘴动画次数
	public bool mouthSwitch =false; //嘴动画开关

	private bool mouthRunning = false;
	private int currMouthIndex = 0;
	private int currMouthRepeatCount = 0;
	private float currMouthTime = 0.0f;
	private float lastMouthTime =0.0f;


	private void ResetEye(){
		leftEye.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", new Vector2(eyeLeftEmotionNormal.x*1.0f/eyeRowCol.x, (eyeRowCol.y-1-eyeLeftEmotionNormal.y)*1.0f/eyeRowCol.y));
		rightEye.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", new Vector2(eyeRightEmotionNormal.x*1.0f/eyeRowCol.x, (eyeRowCol.y-1-eyeRightEmotionNormal.y)*1.0f/eyeRowCol.y));
	}
	private void ResetMouth(){
		mouth.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", new Vector2(0,(mouthRowCol.y-1)/mouthRowCol.y));
	}

    void Start()
    {
		if(leftEye != null && rightEye !=null){
			leftEye.GetComponent<MeshRenderer>().materials[0].SetTextureScale("_MainTex", new Vector2(1.0f/eyeRowCol.x, 1.0f/eyeRowCol.y));
			rightEye.GetComponent<MeshRenderer>().materials[0].SetTextureScale("_MainTex", new Vector2(1.0f/eyeRowCol.x, 1.0f/eyeRowCol.y));

			ResetEye();
		}

		if(mouth !=null){
			mouth.GetComponent<MeshRenderer>().materials[0].SetTextureScale("_MainTex", new Vector2(1.0f/mouthRowCol.x, 1.0f/mouthRowCol.y));

			ResetMouth();
		}
			
	
	}

	void FixedUpdate()
    {
		//eye
		if(leftEye !=null && rightEye !=null && eyeEmotionSwitch){
			eyeRunning = true;
			eyeEmotionSwitch = false;

			ResetEye();
		}
		if(eyeRunning){

			if(currEyeTime >= lastEyeTime + 1.0f/eyeEmotionFps){

				if(eyeEmotionRepeat>0 && currEyeRepeatCount >= eyeEmotionRepeat){
					eyeRunning = false;
					currEyeTime = 0.0f;
					lastEyeTime = 0.0f;
					currEyeIndex = 0;
					currEyeRepeatCount = 0;

					ResetEye();


					return;
				}



				if(currEyeIndex >= 1){
					currEyeRepeatCount ++;
					currEyeIndex = 0;

					ResetEye();
				}else{

					float lx = eyeLeftEmotionChange.x * 1.0f/eyeRowCol.x;
					float ly = (eyeRowCol.y - 1 - eyeLeftEmotionChange.y) * 1.0f/eyeRowCol.y;

					float rx = eyeRightEmotionChange.x * 1.0f/eyeRowCol.x;
					float ry = (eyeRowCol.y - 1 - eyeRightEmotionChange.y) * 1.0f/eyeRowCol.y;

					leftEye.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", new Vector2(lx, ly));
					rightEye.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", new Vector2(rx, ry));

					currEyeIndex ++;
				}

				lastEyeTime = currEyeTime;
			}else{
				currEyeTime += Time.fixedDeltaTime;
			}
		}

		//mouth
		if(mouth !=null && mouthSwitch){
			mouthRunning = true;
			mouthSwitch = false;
			ResetMouth();
		}
		if(mouthRunning){

			if(currMouthTime >= lastMouthTime + 1.0f / mouthEmotionFps){

				//判断是否完成重复次数
				if(mouthEamotionRepeat >0 && currMouthRepeatCount>=mouthEamotionRepeat){
					mouthRunning = false;
					currMouthTime =0.0f;
					lastMouthTime = 0.0f;
					currMouthIndex = 0;
					currMouthRepeatCount = 0;

					ResetMouth();


					return;
				}
					
				//解析行列
				int y = (int)(currMouthIndex / mouthRowCol.y);
				int x = (int)((currMouthIndex-y*mouthRowCol.x) % mouthRowCol.x);
				mouth.GetComponent<MeshRenderer>().materials[0].SetTextureOffset("_MainTex", 
					new Vector2(x * 1.0f/mouthRowCol.x, (mouthRowCol.y-1 - y)* 1.0f/mouthRowCol.y));
//				Debug.Log(currMouthRepeatCount + ": "+ x+":"+y);

				////序列帧循环结束，
				if(currMouthIndex >= (int)(mouthRowCol.x*mouthRowCol.y-1)){
					currMouthRepeatCount ++;
					currMouthIndex = 0; //重置index
				}else{
					currMouthIndex++;
				}
				//记录时间
				lastMouthTime = currMouthTime;
			}else{
				currMouthTime += Time.fixedDeltaTime;
			}
		}
			
    }
}