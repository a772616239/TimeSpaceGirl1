using UnityEngine;
using System.Collections;

public class UVScroll : MonoBehaviour {
	private float offsetX = 0.0f;
	public float speedX = 0.4f;
	private Material material;

	// Use this for initialization
	void Start () {
		material = gameObject.GetComponent<Renderer>().material;
	}
	
	// Update is called once per frame
	void Update () {

		offsetX = speedX * Time.time % 1.0f;
		Vector2 offset = new Vector2(offsetX, 0);
		material.SetTextureOffset("_LightTex",offset);
	}
}
