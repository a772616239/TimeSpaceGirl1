require("Base/BasePanel")
ReconnaissanceRecord = Inherit(BasePanel)
local this = ReconnaissanceRecord
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
this.myReward={}--个人记录
this.allReward={}--全服记录




function ReconnaissanceRecord:InitComponent()
    this.mask=Util.GetGameObject(self.transform,"mask")
    this.tip = Util.GetGameObject(self.transform, "Bg/tip")
    this.backBtn = Util.GetGameObject(self.transform, "backBtn")

    this.textShow = Util.GetGameObject(self.transform, "textShow")

    this.scrollUp = Util.GetGameObject(self.transform, "scrollUp")
    local v2 =this.scrollUp:GetComponent("RectTransform").rect
    this.ScrollViewUp = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollUp.transform,
            this.textShow, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(0,10))
    this.ScrollViewUp.moveTween.MomentumAmount = 1
    this.ScrollViewUp.moveTween.Strength = 1


    this.scrollDown = Util.GetGameObject(self.transform, "scrollDown")
    local v2 =this.scrollDown:GetComponent("RectTransform").rect
    this.ScrollViewDown = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollDown.transform,
            this.textShow, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(0,10))
    this.ScrollViewDown.moveTween.MomentumAmount = 1
    this.ScrollViewDown.moveTween.Strength = 1

    

end

function ReconnaissanceRecord:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
	Util.AddClick(this.mask, function()
        self:ClosePanel()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
    end)
end



function ReconnaissanceRecord:AddListener()
end

function ReconnaissanceRecord:RemoveListener()
end
function ReconnaissanceRecord:OnSortingOrderChange()
   
end

function ReconnaissanceRecord:OnShow(...)
    NetManager.WORKSHOP_PROSPECT_RECORD_REQUEST(function(msg)
        this.myReward=msg.goodsReward
        this.allReward=msg.allGoodsReward

        
        
        
        

        this.ScrollViewUp:SetData(this.myReward, function (index, go)
            this.myRewardData(go, this.myReward[index])
        end)

        this.ScrollViewDown:SetData(this.allReward, function (index, go)
            this.allRewardData(go, this.allReward[index])
        end)
    end)
  

end

function ReconnaissanceRecord:OnClose()
  
end

function ReconnaissanceRecord:OnDestroy()
   
end

function this.myRewardData(go,data)
    go:GetComponent("Text").text=string.format(GetLanguageStrById(23113),GetLanguageStrById(itemConfig[data.goodsId].Name),data.count)
end

function this.allRewardData(go,data)
    go:GetComponent("Text").text=string.format(GetLanguageStrById(23114),data.name,GetLanguageStrById(itemConfig[data.goodsId].Name),data.count)
   
end





return ReconnaissanceRecord