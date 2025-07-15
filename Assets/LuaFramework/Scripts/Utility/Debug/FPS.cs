using UnityEngine;

public class FPS : MonoBehaviour
{
    private static int mFrame = 0;
    private static float mLastTime = 0;
    private static float mFps = 0;
    private static float mCount = 0;

    private void OnGUI()
    {
        mLastTime -= Time.deltaTime;
        mCount += Time.timeScale / Time.deltaTime;
        mFrame++;
        if (mLastTime <= 0)
        {
            mFps = mCount / mFrame;
            mLastTime = 0.5f;
            mFrame = 0;
            mCount = 0;
        }
        GUI.Label(new Rect(Screen.width * 0.5f, 0, 100, 20), "FPS:" + mFps.ToString("f2"));
    }


}