using System.Collections;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(Image))]
public class ImageHelper : MonoBehaviour
{

    private Image img;
    private Coroutine img_Co;

    void Awake()
    {
        img = GetComponent<Image>();
    }

    public void StopCo()
    {
        if (!gameObject.activeInHierarchy)
            return;

        if (img_Co != null)
            StopCoroutine(img_Co);
    }

    public void ResetFillImage(float value)
    {
        StopCo();

        if (img != null)
            img.fillAmount = value;
    }

    public void FillImage(float startValue, float toValue, float time)
    {
        if (!gameObject.activeInHierarchy)
            return;

        StopCo();

        if (img == null)
            return;

        img_Co = StartCoroutine(FillImage_Co(startValue, toValue, time));
    }

    IEnumerator FillImage_Co(float startValue, float toValue, float time)
    {
        var increaseValue = (toValue - startValue) / time;
        var startTime = Time.realtimeSinceStartup;
        while (true)
        {
            yield return new WaitForEndOfFrame();
            if (Time.realtimeSinceStartup - startTime >= time)
            {
                img.fillAmount = toValue;
                break;
            }

            startValue = Mathf.Clamp01(startValue + increaseValue * Time.deltaTime);
            img.fillAmount = startValue;
        }
    }
}
