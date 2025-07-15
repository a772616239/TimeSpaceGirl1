using System.Collections;
using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(Text))]
public class TextHelper : MonoBehaviour
{
    private Text content;
    private Coroutine cur_Co;

    void Awake()
    {
        content = GetComponent<Text>();
    }

    public void Stop_Co()
    {
        if (!gameObject.activeInHierarchy)
            return;

        if (cur_Co != null)
            StopCoroutine(cur_Co);
    }

    public void ResetText(string text)
    {
        Stop_Co();

        if (content != null)
            content.text = text;
    }


    /// <summary>
    /// 
    /// </summary>
    /// <param name="startNumber">begin</param>
    /// <param name="endNumber">end</param>
    /// <param name="overText">endText</param>
    /// <param name="time">Time</param>
    public void AddNumberText(int startNumber, int endNumber, string overText, float time)
    {
        if (!gameObject.activeInHierarchy)
            return;

        Stop_Co();
        if (content == null)
            return;

        cur_Co = StartCoroutine(AddNumber_Co_Second(startNumber, endNumber, overText, time));
    }

    IEnumerator AddNumber_Co_Second(float startValue, float endValue, string overText, float time)
    {
        var increaseValue = (endValue - startValue) / time;
        var maxValue = startValue > endValue ? startValue : endValue;
        var minValue = startValue < endValue ? startValue : endValue;
        
        content.text = startValue.ToString();
        while (true)
        {
            yield return new WaitForSeconds(1.0f);
            if (startValue == endValue)
            {
                content.text = overText;
                break;
            }

            startValue = Mathf.Clamp(startValue + increaseValue, minValue, maxValue);
            content.text = startValue.ToString();
        }
    }
}
