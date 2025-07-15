---- 魂印详情与替换弹窗 ----
require("Base/BasePanel")
SoulPrintPopUpV2 = Inherit(BasePanel)
local this=SoulPrintPopUpV2
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipConfig=ConfigManager.GetConfig(ConfigName.EquipConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local propertyconfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)
--面板类型
local Type={
    Detail=1,
    Replace=2
}
--当前面板类型
local curType=0
local curHeroData --当前英雄数据
local equipData --点击的魂印数据
local callBack

function SoulPrintPopUpV2:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")
    this.BackMask=Util.GetGameObject(this.gameObject,"BackMask") --m5
    this.title=Util.GetGameObject(this.panel,"Title"):GetComponent("Text")
    this.empty=Util.GetGameObject(this.panel,"Empty")
    this.scrollRoot=Util.GetGameObject(this.gameObject,"ScrollRoot")
    this.pre=Util.GetGameObject(this.scrollRoot,"Pre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.pre, nil,--
    Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,1,Vector2.New(0,10))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.tihuan=Util.GetGameObject(this.panel,"tihuan")
end

function SoulPrintPopUpV2:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask,function()
        self:ClosePanel()
    end) --m5

    Util.AddClick(this.tihuan,function()
        local wearInfo = {heroId = "10042304010015867490050000",equipId = 5000048,position = 1}
        local unloadInfo = {heroId = "10042304010015867490050000",equipId = 5000044,position = 1}
        NetManager.SoulEquipWearRequest(wearInfo,unloadInfo,function ()
            HeroManager.DelSoulPrintUpHeroDynamicId("10042304010015867490050000",5000044)
            HeroManager.AddSoulPrintUpHeroDynamicId("10042304010015867490050000",5000048,1)
            self:ClosePanel()
        end)
    end)
end

function SoulPrintPopUpV2:AddListener()
end

function SoulPrintPopUpV2:RemoveListener()
end

--curType 1为详情 2为替换
function SoulPrintPopUpV2:OnOpen(...)
    local args={...}
    curType=args[1]
    curHeroData=args[2]
    equipData=args[3]
    callBack=args[4]
end

function SoulPrintPopUpV2:OnShow()
    this.RefreshShow(curType)
end

function SoulPrintPopUpV2:OnClose()
end

function SoulPrintPopUpV2:OnDestroy()
    this.scrollView=nil
end


--刷新面板
function this.RefreshShow(type)
    if type==Type.Detail then
        this.title.text=GetLanguageStrById(11951)
        this.empty.gameObject:SetActive(#curHeroData.soulPrintList==0)
    elseif type==Type.Replace then
        this.title.text=GetLanguageStrById(11952)
        this.empty.gameObject:SetActive(false)
    end
    --数据是无序的 需要按位置排序下
    table.sort(curHeroData.soulPrintList,function(a,b)
        return tonumber(a.position)<tonumber(b.position)
    end)

    this.scrollView:SetData(curHeroData.soulPrintList,function(index,root)
        this.SetScrollPre(root,curHeroData.soulPrintList[index],type,index)
    end)
    this.scrollView:SetIndex(1)
end

--优化滚动条数据赋值
function this.SetScrollPre(root,data,type,index)
    local frame=Util.GetGameObject(root,"Frame"):GetComponent("Image")
    local icon=Util.GetGameObject(root,"circleFrameBg/Icon"):GetComponent("Image")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local info=Util.GetGameObject(root,"Info"):GetComponent("Text")
    local Info2=Util.GetGameObject(root,"Info2"):GetComponent("Text")
    local goBtn=Util.GetGameObject(root,"GoBtn")
    Util.GetGameObject(root,"Info"):SetActive(type==Type.Replace)
    Util.GetGameObject(root,"Info2"):SetActive(type==Type.Detail)
    frame.sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfig[data.equipId].Quantity))
    icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[data.equipId].ResourceID))
    Util.GetGameObject(root,"circleFrameBg"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[data.equipId].Quantity].circleBg2)
    Util.GetGameObject(root,"circleFrameBg/circleFrame"):GetComponent("Image").sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[data.equipId].Quantity].circle)
    name.text=GetLanguageStrById(itemConfig[data.equipId].Name)
    local infoStr = ""
    if equipConfig[data.equipId] then
        if equipConfig[data.equipId].PassiveSkill then
            infoStr=passiveSkillConfig[equipConfig[data.equipId].PassiveSkill[1]].Desc
        else
            for index, value in ipairs(equipConfig[data.equipId].Property) do --propertyconfig
                if index > 1 then
                    infoStr = infoStr .. "，"
                end
                if propertyconfig[value[1]].Style==1 then
                    infoStr=infoStr..propertyconfig[value[1]].Info.."+"..value[2]
                elseif propertyconfig[value[1]].Style==2 then
                    infoStr=infoStr..propertyconfig[value[1]].Info.."+"..math.floor((value[2]/100)).."%"
                end
            end
        end
        -- for index, pid in ipairs(equipConfig[data.equipId].PassiveSkill) do
        --     if index > 1 then
        --         infoStr = infoStr .. "，"
        --     end
        --     infoStr = infoStr .. ConfigManager.GetConfigData(ConfigName.PassiveSkillConfig, pid).Desc
        -- end
    end
    -- if infoStr == "" then
    --     if equipConfig[data.equipId].Property and #equipConfig[data.equipId].Property > 0 then
    --         for i = 1, #equipConfig[data.equipId].Property do
    --             local curPropertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig,equipConfig[data.equipId].Property[1][1])
    --             infoStr =infoStr .. curPropertyConfig.Info.."   +"..equipConfig[data.equipId].Property[1][2]
    --         end
    --     end
    -- end
    info.text = infoStr
    Info2.text = infoStr



    goBtn:SetActive(type==Type.Replace)
    --替换操作
    Util.AddOnceClick(goBtn,function()
        --检测是否已穿过该类型魂印
        if curHeroData and curHeroData.soulPrintList and #curHeroData.soulPrintList > 0 then
            for i = 1, #curHeroData.soulPrintList do
                if curHeroData.soulPrintList[i].equipId == equipData.id then
                    PopupTipPanel.ShowTipByLanguageId(11602)
                    return
                end
            end
        end

        local wearInfo = {heroId =curHeroData.dynamicId,equipId = equipData.id,position = index} --点击魂印
        local unloadInfo = nil
        --是其他人装备的魂印
        if equipData.upHero~="" then
            local curClickHeroData= HeroManager.GetSingleHeroData(equipData.upHero)
            local pos = 0
            for i = 1, #curClickHeroData.soulPrintList do
                if curClickHeroData.soulPrintList[i].equipId == equipData.id then
                        pos = curClickHeroData.soulPrintList[i].position
                    end
            end
            unloadInfo={heroId =equipData.upHero,equipId = equipData.id,position = pos} --被替换的目标魂印

            local curClickHeroData=HeroManager.GetSingleHeroData(equipData.upHero)
            local str=string.format(GetLanguageStrById(11603),itemConfig[curClickHeroData.id].Name,equipConfig[equipData.id].Name,itemConfig[curHeroData.id].Name)
            MsgPanel.ShowTwo(str, nil, function()
                NetManager.SoulEquipWearRequest(wearInfo,unloadInfo,function ()
                    HeroManager.DelSoulPrintUpHeroDynamicId(curHeroData.dynamicId,data.equipId)--卸下自身魂印
                    if unloadInfo then
                        HeroManager.DelSoulPrintUpHeroDynamicId(unloadInfo.heroId,unloadInfo.equipId)--卸下别人魂印
                    end
                    HeroManager.AddSoulPrintUpHeroDynamicId(curHeroData.dynamicId,equipData.id,index)--装上自身魂印
                    if callBack then
                        callBack()
                    end
                    this:ClosePanel()
                    PopupTipPanel.ShowTipByLanguageId(11953)
                end)
            end)
            return
        end
        --不是其他人装备的魂印
        NetManager.SoulEquipWearRequest(wearInfo,unloadInfo,function ()
            HeroManager.DelSoulPrintUpHeroDynamicId(curHeroData.dynamicId,data.equipId)--卸下自身魂印
            if unloadInfo then
                HeroManager.DelSoulPrintUpHeroDynamicId(unloadInfo.heroId,unloadInfo.equipId)--卸下别人魂印
            end
            HeroManager.AddSoulPrintUpHeroDynamicId(curHeroData.dynamicId,equipData.id,index)--装上自身魂印
            if callBack then
                callBack()
            end
            this:ClosePanel()
            PopupTipPanel.ShowTipByLanguageId(11953)
        end)
    end)
end

return SoulPrintPopUpV2