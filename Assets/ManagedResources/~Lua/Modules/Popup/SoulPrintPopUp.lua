----- 魂印弹窗 -----
require("Base/BasePanel")
SoulPrintPopUp = Inherit(BasePanel)
local this = SoulPrintPopUp
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local equipConfig=ConfigManager.GetConfig(ConfigName.EquipConfig)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)
local propertyconfig=ConfigManager.GetConfig(ConfigName.PropertyConfig)

--面板类型
local Type={
    Up=1,       --穿戴
    Down=2,      --卸下
    Access=3,   --有获取途径  传nil就不显示了
}
--打开面板类型
local curType=0

local heroId --当前英雄id
local soulId --魂印id
local pos    --位置
local callback --回调
local localData --本地存储的魂印数据 包含soulId 该数据只在魂印装备时（Type.Up）才有用

--适用范围英雄容器
local proList = {}
local jumpGoList = {}
function SoulPrintPopUp:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")

    this.name=Util.GetGameObject(this.panel,"Info/Text"):GetComponent("Text") --m5
    this.backBtn= Util.GetGameObject(this.panel, "Info/BackBtn") --m5
    this.maskBtn= Util.GetGameObject(this.gameObject, "mask")
    --基础信息
    this.info=Util.GetGameObject(this.panel,"Info")
    --魂印基础信息
    this.frame=Util.GetGameObject(this.info,"Head/Frame"):GetComponent("Image")
    this.icon=Util.GetGameObject(this.info,"Head/circleFrameBg/Icon"):GetComponent("Image")
    this.circleFrameBg=Util.GetGameObject(this.info,"Head/circleFrameBg"):GetComponent("Image")
    this.circleFrame=Util.GetGameObject(this.info,"Head/circleFrameBg/circleFrame"):GetComponent("Image")
    this.power=Util.GetGameObject(this.info,"PowerNum"):GetComponent("Text")
    this.desc=Util.GetGameObject(this.info,"Desc"):GetComponent("Text")
    --魂印效果
    this.effectText=Util.GetGameObject(this.panel,"Effect/Info"):GetComponent("Text")
    this.effectTextGo=Util.GetGameObject(this.panel,"Effect")
    this.effectTextLine=Util.GetGameObject(this.panel,"Effect_Line")
    --适用范围(还没做具体内容)
    this.trialScope=Util.GetGameObject(this.panel,"TrialScope")
    this.trialScopeText=Util.GetGameObject(this.trialScope,"Text"):GetComponent("Text")
    --数据小于4自动布局
    this.scroll_1=Util.GetGameObject(this.trialScope,"Scroll_1")--静态布局根节点
    this.trialScopePre=Util.GetGameObject(this.trialScope,"Scroll_1/TrialScopePre")--适用范围预设
    --数据大于4优化布局
    this.scroll_2=Util.GetGameObject(this.trialScope,"Scroll_2")--优化滚动条
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll_2.transform,this.trialScopePre, nil,Vector2.New(899.5,490),1,1,Vector2.New(0,15))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    --获取途径
    this.access=Util.GetGameObject(this.panel,"Access")
    this.accessScroll=Util.GetGameObject(this.panel,"Access/Scroll")
    this.accessPre=Util.GetGameObject(this.panel,"Access/Scroll/AccessPre")
    this.accessPre:SetActive(false)
    --操作按钮
    this.btns=Util.GetGameObject(this.panel,"Btns")
    this.upBtn=Util.GetGameObject(this.panel,"Btns/UpBtn")
    this.downBtn=Util.GetGameObject(this.panel,"Btns/DownBtn")

    --Line图片
    this.effect_Line=Util.GetGameObject(this.panel,"Effect_Line")
    -- this.trialScope_Line=Util.GetGameObject(this.panel,"TrialScope_Line")
    this.access_Line=Util.GetGameObject(this.panel,"Access_Line")
end

function SoulPrintPopUp:BindEvent()
    --关闭面板
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.maskBtn, function()
        self:ClosePanel()
    end)
    --穿戴
    Util.AddClick(this.upBtn,function()
        --检测是否已穿过该类型魂印
        local curHeroData = HeroManager.GetSingleHeroData(heroId)
        if curHeroData and curHeroData.soulPrintList and #curHeroData.soulPrintList > 0 then
            for i = 1, #curHeroData.soulPrintList do
                if curHeroData.soulPrintList[i].equipId == soulId then
                    PopupTipPanel.ShowTipByLanguageId(11602)
                    return
                end
            end
        end

        --如果装备位置满了 显示替换界面
        if pos==0 then
            UIManager.OpenPanel(UIName.SoulPrintPopUpV2,2,curHeroData,localData,function()
                self:ClosePanel()
                SoulPrintPanel.RefreshShow()
            end)
            return
        end

        --如果是别人装备的
        if localData.upHero~="" then
            --当前点击魂印被装到的英雄数据
            local curClickHeroData=HeroManager.GetSingleHeroData(localData.upHero)
            local str=string.format(GetLanguageStrById(11603),GetLanguageStrById(itemConfig[curClickHeroData.id].Name),equipConfig[localData.id].Name,itemConfig[curHeroData.id].Name)
            MsgPanel.ShowTwo(str, nil, function()
                local _pos = 0
                for i = 1, #curClickHeroData.soulPrintList do
                    if curClickHeroData.soulPrintList[i].equipId == localData.id then
                        _pos = curClickHeroData.soulPrintList[i].position
                    end
                end
                NetManager.SoulEquipUnLoadWearRequest(tostring(curClickHeroData.dynamicId),localData.id,_pos,function()
                    HeroManager.DelSoulPrintUpHeroDynamicId(curClickHeroData.dynamicId,localData.id)
                    local wearInfo = {heroId = tostring(curHeroData.dynamicId),equipId = localData.id,position = pos}
                    NetManager.SoulEquipWearRequest(wearInfo,nil,function()
                        HeroManager.AddSoulPrintUpHeroDynamicId(curHeroData.dynamicId,localData.id,pos)
                        PopupTipPanel.ShowTipByLanguageId(11604)
                        SoulPrintPanel.RefreshShow()
                        self:ClosePanel()
                    end)
                end)
            end)
            return
        end
        -- else--选择的魂印没有被其他猎妖师装备 可直接装备
        --穿戴
        local wearInfo = {heroId = tostring(heroId),equipId = soulId,position = pos}
        NetManager.SoulEquipWearRequest(wearInfo,nil,function()
            HeroManager.AddSoulPrintUpHeroDynamicId(heroId,soulId,pos)
            if callback then
                callback()
            end
        end)
        self:ClosePanel()
        -- end
    end)
    --卸下
    Util.AddClick(this.downBtn,function()
        NetManager.SoulEquipUnLoadWearRequest(tostring(heroId),soulId,pos,function()
            HeroManager.DelSoulPrintUpHeroDynamicId(heroId,soulId)
            if callback then
                callback()
            end
        end)
        self:ClosePanel()
    end)
end

function SoulPrintPopUp:AddListener()
end

function SoulPrintPopUp:RemoveListener()
end

--curtype 面板类型(看最上面解释)  heroId 英雄ID  soulId魂印ID  pos位置  callback回调 localData本地存储魂印数据（只在穿戴时用）
function SoulPrintPopUp:OnOpen(...)
    local args={...}
    curType=args[1]
    heroId= args[2]
    soulId=args[3]
    pos=args[4]
    callback=args[5]
    localData=args[6]
end

function SoulPrintPopUp:OnShow()
    this.RefreshShow(curType)
end

function SoulPrintPopUp:OnClose()
end

function SoulPrintPopUp:OnDestroy()
    this.scrollView=nil
    proList={}
    jumpGoList = {}
end

--读取魂印适用英雄效果
local x= function(index)
    local args={}
    for i, v in ipairs(equipConfig[soulId].Parameter[index]) do
        args[i]=v
    end
    return string.format(equipConfig[soulId].Describe,unpack(args))
end
--刷新面板
function this.RefreshShow(type)
    this.btns:SetActive(type==Type.Up or type==Type.Down)
    this.upBtn:SetActive(type==Type.Up)
    this.downBtn:SetActive(type==Type.Down)

    --基础信息
    this.name.text=GetLanguageStrById(equipConfig[soulId].Name)
    this.frame.sprite=Util.LoadSprite(GetQuantityImageByquality(equipConfig[soulId].Quality))
    this.icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[soulId].ResourceID))
    this.circleFrameBg.sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[soulId].Quantity].circleBg2)
    this.circleFrame.sprite=Util.LoadSprite(SoulPrintSpriteByQuantity[itemConfig[soulId].Quantity].circle)
    this.power.text=equipConfig[soulId].Score--战力
    this.desc.text = itemConfig[soulId].ItemDescribe

    -- local isShow = equipConfig[soulId] and equipConfig[soulId].PassiveSkill and true
    -- this.effectTextGo:SetActive(isShow)
    -- this.effectTextLine:SetActive(isShow)
    -- this.trialScope_Line:SetActive(isShow)
    if equipConfig[soulId] then --魂印效果
        local txt = ""
        if equipConfig[soulId].PassiveSkill then
            this.effectText.text = passiveSkillConfig[equipConfig[soulId].PassiveSkill[1]].Desc
        else
            for index, value in ipairs(equipConfig[soulId].Property) do --propertyconfig
                if index > 1 then
                    txt = txt .. "，"
                end
                if propertyconfig[value[1]].Style==1 then
                    txt=txt..propertyconfig[value[1]].Info.."+"..value[2]
                elseif propertyconfig[value[1]].Style==2 then
                    txt=txt..propertyconfig[value[1]].Info.."+"..math.floor((value[2]/100)).."%"
                end
            end
            this.effectText.text =txt
        end
    end
    --适用范围
    local isOpenTrialScope=equipConfig[soulId].Range and equipConfig[soulId].Range[1]~=0 and equipConfig[soulId].Range[1]--是否开启适用
    if isOpenTrialScope then
        this.trialScopeText.text=GetLanguageStrById(11605)
        this.scroll_1:SetActive(#equipConfig[soulId].Range<=3)
        this.scroll_2:SetActive(#equipConfig[soulId].Range>3)
        --适用英雄<=3时 固定长度生成（预设） 反之使用优化滚动条
        if #equipConfig[soulId].Range<=3 then
            for j = 0, this.scroll_1.transform.childCount-1 do
                this.scroll_1.transform:GetChild(j).gameObject:SetActive(false)
            end
            for i = 1, #equipConfig[soulId].Range do--遍历每个适用英雄
                local item= proList[i]
                if not item then
                    item= newObjToParent(this.trialScopePre,this.scroll_1)
                    item.name="ProPre"..i
                    proList[i]=item
                end
                proList[i].gameObject:SetActive(true)
                local _heroId=equipConfig[soulId].Range[i]
                local frame=Util.GetGameObject(item,"Head/Frame"):GetComponent("Image")
                local icon=Util.GetGameObject(item,"Head/Icon"):GetComponent("Image")
                local name=Util.GetGameObject(item,"Name"):GetComponent("Text")
                local info=Util.GetGameObject(item,"Info"):GetComponent("Text")
                frame.sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfig[_heroId].Quantity))
                icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[_heroId].ResourceID))
                name.text=itemConfig[_heroId].Name
                info.text=x(i)
            end
        else
            this.scrollView:SetData(equipConfig[soulId].Range,function(index,root)
                this.SetScrollPre(root,equipConfig[soulId].Range[index],index)
            end)
            this.scrollView:SetIndex(1)
        end
    else
        this.scroll_1:SetActive(false)
        this.scroll_2:SetActive(false)
        this.trialScopeText.text=GetLanguageStrById(11606)
    end

    --获取途径
    this.access:SetActive(type==Type.Access)
    this.access_Line:SetActive(type==Type.Access)
    --jumpGoList
    if itemConfig[soulId].Jump and #itemConfig[soulId].Jump > 0 then
        for i = 1, math.max(#itemConfig[soulId].Jump, #jumpGoList) do
            local go = jumpGoList[i]
            if not go then
                go = newObject(this.accessPre)
                go.transform:SetParent(this.accessScroll.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                jumpGoList[i] = go
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #itemConfig[soulId].Jump do
            if jumpGoList[i] then
                jumpGoList[i]:SetActive(true)
                local jumpId = itemConfig[soulId].Jump[i]
                local jumpSData=ConfigManager.GetConfigData(ConfigName.JumpConfig,jumpId)
                if jumpSData then
                    Util.GetGameObject(jumpGoList[i].gameObject, "Info"):GetComponent("Text").text=GetLanguageStrById(jumpSData.Title)
                    Util.GetGameObject(jumpGoList[i].gameObject, "GoBtn/Text"):GetComponent("Text").text = GetLanguageStrById(10509)
                    Util.AddOnceClick(Util.GetGameObject(jumpGoList[i].gameObject, "GoBtn"), function()
                        JumpManager.GoJump(jumpSData.Id)
                    end)
                end
            end
        end
    end
end

--优化滚动条数据赋值
function this.SetScrollPre(root,data,index)
    local frame=Util.GetGameObject(root,"Head/Frame"):GetComponent("Image")
    local icon=Util.GetGameObject(root,"Head/Icon"):GetComponent("Image")
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    local info=Util.GetGameObject(root,"Info"):GetComponent("Text")
    frame.sprite=Util.LoadSprite(GetQuantityImageByquality(itemConfig[data].Quantity))
    icon.sprite=Util.LoadSprite(GetResourcePath(itemConfig[data].ResourceID))
    name.text=GetLanguageStrById(itemConfig[data].Name)

    info.text=x(index)
end

return SoulPrintPopUp