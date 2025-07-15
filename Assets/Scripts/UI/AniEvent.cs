using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using LuaInterface;
using GameLogic;

public class AniEvent : MonoBehaviour
{
    // Start is called before the first frame update
    private LuaFunction func;

    void Start()
    {
        //Animator ani = this.gameObject.GetComponent<Animator>();
        //ani.SetInteger("road", 555);
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void SetAniDelegate(LuaFunction func)
    {
        this.func = func;
    }

    public void AniEventCallBack()
    {
        if (this.func == null) return;
        this.func.Call();
        //App.LuaMgr.CallLuaFunction("Modules/Battle/BattleManager.lua", "FireSound");
    }

    public void SetAniValue(int value)
    {
        Animator ani = this.gameObject.GetComponent<Animator>();
        ani.SetInteger("road", value);
        //Debug.LogWarning("road");
        //Debug.LogWarning(value);
        //Debug.LogWarning(ani.GetInteger("road"));

    }
}
