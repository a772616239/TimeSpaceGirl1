require("Base/BasePanel")
GenerlProInfoPopup = Inherit(BasePanel)
local this=GenerlProInfoPopup
this.generalListData={}
--初始化组件（用于子类重写）
function GenerlProInfoPopup:InitComponent()
    this.rewardPre=Util.GetGameObject(this.gameObject,"grid/recordPer")
    this.close=Util.GetGameObject(this.gameObject,"btnBack")
    this.rect=Util.GetGameObject(this.gameObject,"grid/rect")
    local rectTra=this.rect:GetComponent("RectTransform")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rect.transform,
            this.rewardPre, nil, Vector2.New(rectTra.rect.width, rectTra.rect.height), 1,1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function GenerlProInfoPopup:BindEvent()

end
--添加事件监听（用于子类重写）
function GenerlProInfoPopup:AddListener()
    Util.AddClick(this.close,function ()
        self:ClosePanel()
    end)
end

--移除事件监听（用于子类重写）
function GenerlProInfoPopup:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function GenerlProInfoPopup:OnOpen(generalID)
    this.generalindex=generalID
    this.generalListData=this.getRankList(generalID)
    this.ScrollView:SetData(this.generalListData, function(index, go)
        GenerlProInfoPopup.AddRankData(index,go,this.generalListData[index])
    end)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GenerlProInfoPopup:OnShow()

end

--界面关闭时调用（用于子类重写）
function GenerlProInfoPopup:OnClose()
    
end

--界面销毁时调用（ 用于子类重写）
function GenerlProInfoPopup:OnDestroy()

end
function this.SetUpdata (index)
   
end
function GenerlProInfoPopup:UpdateUpStarPosHeroData(curSelectHeroList)
   
end
function this.getRankList(index)
    local generalRank=this.generalRankConfigList(index)
    local lockadd=1
    local indexRankNum=1
    local rankData={
        speed=0,
        hp=0,
        atk=0,
        lev=0
    }
    local generalRanklist={}
    for i=1, #generalRank do
        local data=generalRank[i]
        if data.StepAtt[1]==61 then
            rankData.hp=rankData.hp+data.StepAtt[2]
        end
        if data.StepAtt[1]==62 then
            rankData.atk=rankData.atk+data.StepAtt[2]
        end
        if data.StepAtt[1]==5 then
            rankData.speed=rankData.speed+data.StepAtt[2]
        end
        lockadd=lockadd+1
        if lockadd>5 then
            lockadd=1
            generalRanklist[indexRankNum]={speed=rankData.speed,
            hp=rankData.hp,
            atk=rankData.atk,
            lev=indexRankNum}
            indexRankNum=indexRankNum+1
        end
    end
    return generalRanklist
end
function this.generalRankConfigList(index)
    local generalRank=ConfigManager.GetConfig(ConfigName.GeneralStepConfig)
    local generalList={}
    for key, value in ConfigPairs(generalRank) do
        if value.GeneralId==index then
            generalList[value.StepLev]=value
        end
    end
    return generalList
end
function GenerlProInfoPopup.AddRankData(index,go,data)
    -- go:SetActive(true)
    Util.GetGameObject(go,"name/text"):GetComponent("Text").text=string.format(GetLanguageStrById(12738),data.lev)
    Util.GetGameObject(go,"Mask/proPre1/pro1/proVale"):GetComponent("Text").text=data.hp/100 .."%"
    Util.GetGameObject(go,"Mask/proPre1/pro2/proVale"):GetComponent("Text").text=data.atk/100 .."%"
    Util.GetGameObject(go,"Mask/proPre2/proVale"):GetComponent("Text").text=data.speed
end
function this.loadSprie()
    
end
return GenerlProInfoPopup