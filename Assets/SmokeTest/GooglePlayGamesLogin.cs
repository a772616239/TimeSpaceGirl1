using System;
using System.Linq;
using GooglePlayGames;
using GooglePlayGames.BasicApi;
using GooglePlayGames.BasicApi.SavedGame;
using UnityEngine;
public class GooglePlayGamesLogin
{
    private string _mStatus = "Ready";
    internal string Status
    {
        get { return _mStatus; }
        set { _mStatus = value; }
    }

    public void LoginAuth(Action<bool> callback)
    {
        PlayGamesPlatform.DebugLogEnabled = true;
        PlayGamesPlatform.Activate();
        PlayGamesPlatform.Instance.Authenticate(OnSignInResult);
    }
    private void OnSignInResult(SignInStatus signInStatus)
    {
        if (signInStatus == SignInStatus.Success)
        {
            Status = "Authenticated. Hello, " + Social.localUser.userName + " (" + Social.localUser.id + ")";
        }
        else
        {
            Status = "*** Failed to authenticate with " + signInStatus;
        }
        Debug.Log(Status);
    }

}