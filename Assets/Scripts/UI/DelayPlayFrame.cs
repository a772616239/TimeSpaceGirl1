using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnrealM;

public class DelayPlayFrame : MonoBehaviour
{
    // Start is called before the first frame update
    public float delayA = 0;
    public float delayB = 0;
    //private float dtincrease = 0;
    private float time = 0;
    //private bool isSet = false;
    void Start()
    {
        gameObject.GetComponent<Image>().enabled = false;
        gameObject.GetComponent<ImageAnimation>().enabled = false;
        time = Random.Range(delayA, delayB);

        Invoke("DelayFunc", time);
    }

    // Update is called once per frame
    void Update()
    {
        //dtincrease += Time.deltaTime;
        //if(dtincrease >= time && !isSet)
        //{
        //    gameObject.GetComponent<Image>().enabled = true;
        //    gameObject.GetComponent<ImageAnimation>().enabled = true;
        //}
    }

    void DelayFunc()
    {
        gameObject.GetComponent<Image>().enabled = true;
        gameObject.GetComponent<ImageAnimation>().enabled = true;
    }
}
