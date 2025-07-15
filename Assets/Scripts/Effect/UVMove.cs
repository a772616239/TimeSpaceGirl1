using UnityEngine;
using System.Collections;

public class UVMove : MonoBehaviour 
{
	public Material Mat;
	public float XSpeed;
	public float YSpeed;

	// Use this for initialization
	void Start ()
	{
	
	}
	
	// Update is called once per frame
	void Update () 
	{
		if (Mat != null) 
		{
			float x = Time.time * XSpeed;
			float y = Time.time * YSpeed;
			Mat.mainTextureOffset = new Vector2(x,y);
		}
	}
}
