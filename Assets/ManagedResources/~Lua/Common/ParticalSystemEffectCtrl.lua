ParticalSystemEffectCtrl = {}
self =ParticalSystemEffectCtrl
local TimerManager=nil;



--计算粒子特效播放时长(EffectObjRoot特效父级)--暂时不支持多个特效添加
function ParticalSystemEffectCtrl.SetParticalSystemLength(EffectObjRoot,Plylength)

    if (Plylength) then
        ParticalSystemEffectCtrl.Plylength=Plylength
        return ParticalSystemEffectCtrl.Plylength
    end
    local particleSystemsArr= EffectObjRoot:GetComponentsInChildren(typeof(UnityEngine.ParticleSystem))
    local particleSystemsLuaArr=particleSystemsArr:ToTable()
    local float_maxDuration = 0;
    for i,v in pairs(particleSystemsLuaArr) do
        if(v.emission().enabled)then
            if(v.loop)then
                return -1;
            end
            local float_dunration = 0;
            if(v.emission.rateOverTime <=0)then
                float_dunration = v.main.startDelay + v.main.startLifetime;
            else
                float_dunration = v.main.startDelay + Mathf.Max(v.main.duration,v.mian.startLifetime);
            end
            if (float_dunration > float_maxDuration) then
                float_maxDuration = float_dunration;
            end
        end
    end
    return float_maxDuration;

end

--设置粒子效果播放完成后销毁/隐藏(Bool_Destroy==true,销毁)
function ParticalSystemEffectCtrl.SetParticalSystemDestroyOrDisable(EffectObjRoot,Bool_Destroy,plyLength)
    EffectObjRoot:SetActive(true)
    self.SetParticalSystemLength(EffectObjRoot,plyLength)
    local Num_NeedTimeLength=ParticalSystemEffectCtrl.Plylength


    self.TimerManager=Timer.New(function (NeedTimeLength)
        if EffectObjRoot==nil then
            if self.TimerManager~=nil then
                self.TimerManager:Stop();
                self.TimerManager = nil;
                return
            end
        end
        if NeedTimeLength<=0 and EffectObjRoot~=nil then
            if self.TimerManager~=nil then
                self.TimerManager:Stop();
                self.TimerManager = nil;
            end
            if Bool_Destroy then
                --销毁自己
                Destroy(EffectObjRoot)
            else
                --隐藏自己
                EffectObjRoot:SetActive(false)
            end
        end
    end ,1,Num_NeedTimeLength,false,true);
    self.TimerManager:Start();
end

--[[1,times,false,true);
local index=0;
local ChildObjArr={};
function FindEffectChildObj(effectObj)

    local ParticleSystem= effectObj:GetComponent('ParticleSystem')
    if ParticleSystem~=nil then
        index=index+1;
        ChildObjArr[index]=ParticleSystem
    end
    if effectObj.transform.childCount>0 then
        for i,v in pairs(effectObj.transform) do
            local trans=v;
            FindEffectChildObj(trans.gameObject)
        end
    end
end
--]]
--移除特效计时器(粒子特效播放计算时长销毁时用了计时器，需要在调用界面销毁时手动移除计时器)
function ParticalSystemEffectCtrl.RemoveTimerForParticalSystem()
    if self.TimerManager~=nil then
        self.TimerManager:Stop();
        self.TimerManager = nil;
    end
end
--层级暂留
function ParticalSystemEffectCtrl.Hierarchy()

end

return self






