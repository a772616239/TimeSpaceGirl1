require("Base/BasePanel")
MedalParticularsPopup = Inherit(BasePanel)
local this = MedalParticularsPopup
local MedalConfig = ConfigManager.GetConfig(ConfigName.MedalConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local MedalSuitConfig = ConfigManager.GetConfig(ConfigName.MedalSuitConfig)
local MedalSuitType = ConfigManager.GetConfig(ConfigName.MedalSuitType)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local MedalConfigData
local suitTypeList----勋章分类List
--local isShowBtn=false --是否显示按钮
--初始化组件（用于子类重写）
function MedalParticularsPopup:InitComponent()

    this.mask = Util.GetGameObject(self.gameObject,"mask")
	this.backbtn = Util.GetGameObject(self.gameObject,"mask/backbtn")
    this.describe = Util.GetGameObject(self.gameObject,"bg/describe")
    -- this.bg = Util.GetGameObject(this.describe,"BG")
    this.frame = Util.GetGameObject(this.describe,"frame")
    this.icon = Util.GetGameObject(this.describe,"frame/icon")
    -- this.pro = Util.GetGameObject(this.describe,"frame/pro")
    --this.starPre=Util.GetGameObject(go,"frame/starPre")
    this.star = Util.GetGameObject(this.describe,"frame/star")
    this.name = Util.GetGameObject(this.describe,"name")
    this.type = Util.GetGameObject(this.describe,"type")
    -- this.suitIcon = Util.GetGameObject(this.describe,"suitIcon")
    this.suitName = Util.GetGameObject(this.describe,"suitName")
    this.Tiptext = Util.GetGameObject(this.describe,"tip")

    -- this.helpBtn = Util.GetGameObject(this.describe,"helpBtn")

    this.base = Util.GetGameObject(self.gameObject,"base")
    this.baseIcon = Util.GetGameObject(this.base,"icon")
    this.baseName = Util.GetGameObject(this.base,"icon/name")
    this.baseValue = Util.GetGameObject(this.base,"icon/value")

    this.random = Util.GetGameObject(self.gameObject,"random")
    this.randomPro1 = Util.GetGameObject(this.random,"pro1")
    this.randomIcon1 = Util.GetGameObject(this.randomPro1,"icon")
    this.randomName1 = Util.GetGameObject(this.randomPro1,"name")
    this.randomValue1 = Util.GetGameObject(this.randomPro1,"value")
    this.randomPro2 = Util.GetGameObject(this.random,"pro2")
    this.randomIcon2 = Util.GetGameObject(this.randomPro2,"icon")
    this.randomName2 = Util.GetGameObject(this.randomPro2,"name")
    this.randomValue2 = Util.GetGameObject(this.randomPro2,"value")

    this.suit = Util.GetGameObject(self.gameObject,"suit")
    this.suitname = Util.GetGameObject(this.suit,"name")
    this.suitIcon1 = Util.GetGameObject(this.suit,"icon1")
    this.suitValue1 = Util.GetGameObject(this.suit,"icon1/value")
    this.suitActivate1 = Util.GetGameObject(this.suit,"icon1/activate")
    this.suitIcon2 = Util.GetGameObject(this.suit,"icon2")
    this.suitValue2 = Util.GetGameObject(this.suit,"icon2/value")
    this.suitActivate2 = Util.GetGameObject(this.suit,"icon2/activate")

    this.skill = Util.GetGameObject(self.gameObject,"skill")
    this.skillIcon = Util.GetGameObject(this.skill,"skillIcon")
    this.skillName = Util.GetGameObject(this.skill,"skillIcon/name")
    this.skillValue = Util.GetGameObject(this.skill,"skillIcon/value")


    this.Btns = Util.GetGameObject(self.gameObject,"Btns")
    this.DownBtn = Util.GetGameObject(this.Btns,"DownBtn")
    this.SellBtn = Util.GetGameObject(this.Btns,"SellBtn")
    this.TeachBtn = Util.GetGameObject(this.Btns,"TeachBtn")

    this.ChangelBtn = Util.GetGameObject(this.Btns,"ChangelBtn")
    this.WearBtn = Util.GetGameObject(this.Btns,"WearBtn")
    this.CompoundBtn = Util.GetGameObject(this.Btns,"CompoundBtn")
    this.ConversionBtn = Util.GetGameObject(this.Btns,"ConversionBtn")

    this.Image = Util.GetGameObject(self.gameObject,"Image")
end

--绑定事件（用于子类重写）
function MedalParticularsPopup:BindEvent()
    Util.AddClick(this.mask,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.backbtn,function()
        self:ClosePanel()
    end)	
    --出售
    Util.AddClick(this.SellBtn,function()
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.MedalSell, this.itemData)
        self:ClosePanel()
    end)

    --卸下
    Util.AddClick(this.DownBtn,function()
        MedalManager.UnloadMedal(this.heroId,this.sizeId,this.itemData.idDyn,function() 
            Log(GetLanguageStrById(23065))
           
        end)
     
        self:ClosePanel()
    end)
    --调教
    Util.AddClick(this.TeachBtn,function()
        -- 勋章调教条件限制
        if MedalConfigData.CanRefine==1 then
            UIManager.OpenPanel(UIName.MedalTeachPopup,this.itemData)--勋章
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(23066)
        end
       
    end)
     --穿戴
     Util.AddClick(this.WearBtn,function()
        UIManager.OpenPanel(UIName.HeroMainPanel)
        self:ClosePanel()
    end)
    --更换
    Util.AddClick(this.ChangelBtn,function()
        UIManager.OpenPanel(UIName.MedalChangelPopup,this.sizeId,this.heroId)--槽位id
        self:ClosePanel()
    end)
    --合成
    Util.AddClick(this.CompoundBtn,function()
        if MedalConfigData.NextId ~= 0 then
            UIManager.OpenPanel(UIName.CompoundPanel,3)
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(23067)
        end
        self:ClosePanel()
    end)
    --转化
    Util.AddClick(this.ConversionBtn,function()
        --勋章转化条件限制
        if MedalConfigData.CanChange == 1 then
            if this.isWear then
               UIManager.OpenPanel(UIName.MedalConversionPopup,this.itemData,this.heroId)--勋章
            else
                UIManager.OpenPanel(UIName.MedalConversionPopup,this.itemData,this.heroId)--勋章
            end
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(23068)
        end
    end)

    
end

--添加事件监听（用于子类重写）
function MedalParticularsPopup:AddListener()
 
end

--移除事件监听（用于子类重写）
function MedalParticularsPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
--1.data勋章ID 2.槽位ID  3.是否穿戴 4.英雄ID 5.是否拥有 6.按钮显隐
function MedalParticularsPopup:OnOpen(...)
    local args = {...}
    this.itemData = args[1]--可代表id
    this.sizeId = args[2]
    this.isWear = args[3]
    this.heroId = args[4]
    this.isHave = args[5]--true:this.itemData为结构组 false:勋章道具ID
    this.btnShow = args[6]
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MedalParticularsPopup:OnShow()
    --this.Btns:SetActive(isShowBtn)
    --this:SuitIsActive()
    this:ShowItemInfo()
    
end
function MedalParticularsPopup:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MedalParticularsPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MedalParticularsPopup:OnDestroy()

end

function this:ShowItemInfo()
    if this.isHave then
       MedalConfigData=this.itemData.medalConfig
    else
        MedalConfigData=MedalConfig[this.itemData]
    end
    -- this.bg:GetComponent("Image").sprite=Util.LoadSprite(GetQuantityTipsColorByQuality(MedalConfigData.Quality))
    this.frame:GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(MedalConfigData.Quality))
    if this.isHave then
        this.icon:GetComponent("Image").sprite = Util.LoadSprite(this.itemData.icon)
    else
        this.icon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ItemConfig[this.itemData].ResourceID))
    end
    -- this.pro:GetComponent("Text").text = MedalManager.GetQualityName(MedalConfigData.Quality)
    -- this.star:SetActive(false)
    --if MedalConfigData.Star>1 then
        -- this.star:SetActive(true)
        -- this.star:GetComponent("Text").text = MedalConfigData.Star
    --end
    SetHeroStars(this.star,MedalConfigData.Star)
    local str = this.SetColor(MedalConfigData.Quality)

    if this.isHave then
        this.name:GetComponent("Text").text = GetStringByEquipQua(MedalConfigData.Quality,GetLanguageStrById(ItemConfig[this.itemData.id].Name))
        -- this.name:GetComponent("Text").text = string.format(str,GetLanguageStrById(ItemConfig[this.itemData.id].Name)) 
    else
        -- this.name:GetComponent("Text").text = string.format(str,GetLanguageStrById(ItemConfig[this.itemData].Name))
        this.name:GetComponent("Text").text = GetStringByEquipQua(MedalConfigData.Quality,GetLanguageStrById(ItemConfig[this.itemData].Name))
    end
    local Name = GetLanguageStrById(MedalSuitType[MedalSuitConfig[MedalConfigData.Suit].Type].Name)
    this.type:GetComponent("Text").text = string.sub(Name,1, 2*3)
    -- this.suitIcon:GetComponent("Image").sprite = Util.LoadSprite(MedalSuitType[MedalSuitConfig[MedalConfigData.Suit].Type].Icon)
    this.suitName:GetComponent("Text").text = Name--GetLanguageStrById(Name)
    --基础
    local PropertyConfigData = PropertyConfig[MedalConfigData.BasicAttr[1]]
    this.baseIcon:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfigData.Icon)
    this.baseName:GetComponent("Text").text = GetLanguageStrById(PropertyConfigData.Info)
    this.baseValue:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfigData.Style,MedalConfigData.BasicAttr[2])
    --随机
    this.random:SetActive(MedalConfigData.RefineAttrNum > 0 and this.isHave)
    if MedalConfigData.RefineAttrNum > 0 and this.isHave then
        local RandomProperty = this.itemData.RandomProperty
        this.randomIcon1:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[RandomProperty[1].id].Icon)
        this.randomName1:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[RandomProperty[1].id].Info)
        this.randomValue1:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfig[RandomProperty[1].id].Style,RandomProperty[1].value)
        if MedalConfigData.RefineAttrNum == 1 then
            this.randomPro2:SetActive(false)
            -- this.random:GetComponent("LayoutElement").minHeight = 100
        else
            this.randomPro2:SetActive(true)
            -- this.random:GetComponent("LayoutElement").minHeight = 130
            this.randomIcon2:GetComponent("Image").sprite = Util.LoadSprite(PropertyConfig[RandomProperty[2].id].Icon)
            this.randomName2:GetComponent("Text").text = GetLanguageStrById(PropertyConfig[RandomProperty[2].id].Info)
            this.randomValue2:GetComponent("Text").text = "+"..GetPropertyFormatStr(PropertyConfig[RandomProperty[2].id].Style,RandomProperty[2].value)
        end
    end
    --套装
    local MedalSuitConfigData = MedalSuitConfig[MedalConfigData.Suit]
    local MedalSuitTypeData = MedalSuitType[MedalSuitConfigData.Type]
    --不同打开位置对应不同显示
    --this.suitname:GetComponent("Text").text=string.format("%s(%s/4)",MedalSuitTypeData.Name,suitTypeList[MedalSuitConfigData.Type].num)
    local suitAttr = MedalSuitConfigData.SuitAttr

    local num1 = suitAttr[1][1]--件数
    local id1 = suitAttr[1][2]--属性id or 8888
    local value1 = suitAttr[1][3]--属性值 or 技能id
    local propertyConfigData = PropertyConfig[id1]
    this.suitIcon1:GetComponent("Image").sprite = Util.LoadSprite(propertyConfigData.Icon)
    this.suitValue1Text = string.format("%s:+%s",GetLanguageStrById(propertyConfigData.Info),GetPropertyFormatStr(propertyConfigData.Style,value1))
    this.suitActivate1Text = string.format(GetLanguageStrById(23069),num1,MedalSuitConfigData.Star)
    this.suitValue1:GetComponent("Text").text = string.format("%s:+%s",GetLanguageStrById(propertyConfigData.Info),GetPropertyFormatStr(propertyConfigData.Style,value1))
    this.suitActivate1:GetComponent("Text").text = string.format(GetLanguageStrById(23069),num1,MedalSuitConfigData.Star)

    local num2 = suitAttr[2][1]--件数
    local id2= suitAttr[2][2]--属性id or 8888
    local value2 = suitAttr[2][3]--属性值 or 技能id
    this.suitActivate2Text = string.format(GetLanguageStrById(23069),num2,MedalSuitConfigData.Star)
    if id2 == 8888 then
        this.skill:SetActive(true)
        local PassiveSkillConfigData = PassiveSkillConfig[value2]
        --this.suitIcon2:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(PassiveSkillConfigData.icon))
        this.suitValue2Text1 = GetLanguageStrById(PassiveSkillConfigData.Name)
        this.suitValue2:GetComponent("Text").text = GetLanguageStrById(PassiveSkillConfigData.Name)
        this.suitActivate2:GetComponent("Text").text = string.format(GetLanguageStrById(23069),num2,MedalSuitConfigData.Star)
        this.skillIcon:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(PassiveSkillConfigData.Icon))
        this.skillValueText = GetLanguageStrById(PassiveSkillConfigData.Desc)
        this.skillValue:GetComponent("Text").text = GetLanguageStrById(PassiveSkillConfigData.Desc)
        this.skillName:GetComponent("Text").text  = GetLanguageStrById(PassiveSkillConfigData.Name)
    else
        this.skill:SetActive(false)
        local propertyConfigData = PropertyConfig[id2]
        if propertyConfigData.Icon then
           this.suitIcon2:GetComponent("Image").sprite = Util.LoadSprite(propertyConfigData.Icon)
        end
        this.suitValue2Text2 = string.format("%s:+%s",GetLanguageStrById(propertyConfigData.Info),GetPropertyFormatStr(propertyConfigData.Style,value2))
        this.suitValue2:GetComponent("Text").text = string.format("%s:+%s",GetLanguageStrById(propertyConfigData.Info),GetPropertyFormatStr(propertyConfigData.Style,value2))
        this.suitActivate2:GetComponent("Text").text = string.format(GetLanguageStrById(23069),num2,MedalSuitConfigData.Star)
    end
    

    --套装激活显示
    if this.isWear then
        local colorTrue = Color.New(52, 243, 133, 255)
        local colorFalse = Color.New(255, 255, 255, 153)
        this.suitValue1:GetComponent("Text").color = colorFalse
        this.suitActivate1:GetComponent("Text").color = colorFalse
        this.suitValue2:GetComponent("Text").color = colorFalse
        this.suitActivate2:GetComponent("Text").color = colorFalse

        local suitActiveList = HeroManager.GetHeroSuitActive(this.heroId)
        if LengthOfTable(suitActiveList) > 0 then
            for i = 1,LengthOfTable(suitActiveList)do
                local data = suitActiveList[i]
                local medalSuitData= MedalManager.GetMedalSuitInfoById(data.suitId)
                --自己套装和激活套装是否一致
                if MedalSuitConfigData.Type == medalSuitData.Type then
                    if data.num == 2 then
                        --激活星数大于等于自身星数
                        if MedalSuitConfigData.Star >= medalSuitData.Star then
                            this.suitValue1:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.suitValue1Text)
                            this.suitActivate1:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.suitActivate1Text)
                        end
                    elseif data.num == 4 then
                        if MedalSuitConfigData.Star >= medalSuitData.Star then
                            this.suitActivate2:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.suitActivate2Text)
                            if id2 == 8888 then
                                this.skillValue:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.skillValueText)
                                this.suitValue2:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.suitValue2Text1)
                            else
                                this.suitValue2:GetComponent("Text").text = string.format("<color=#34F385>%s</color>",this.suitValue2Text2)
                            end
                        end
                    end
                end
            end
        end
    end

    --提示文字
    this.Tiptext:GetComponent("Text").text = GetLanguageStrById(MedalSuitType[MedalSuitConfig[MedalConfigData.Suit].Type].Desc)

    --按钮
    if this.isWear then
        this.DownBtn:SetActive(true)
        this.ChangelBtn:SetActive(true)
        this.SellBtn:SetActive(false)
        this.WearBtn:SetActive(false)

    else
        this.SellBtn:SetActive(true)
        this.WearBtn:SetActive(true)
        this.DownBtn:SetActive(false)
        this.ChangelBtn:SetActive(false)

    end

    this.Btns:SetActive(this.btnShow)
    this.Image:SetActive(not this.btnShow)

    Util.SetGray(this.ConversionBtn,MedalConfigData.CanChange~=1)
    Util.SetGray(this.TeachBtn,MedalConfigData.CanRefine~=1)
    Util.SetGray(this.CompoundBtn,MedalConfigData.NextId==0 )
    
end

--勋章激活状态
-- function this:SuitIsActive()

--     local suit1=0--两件套装id
--     local starNum1=0--两件套对应的星数

--     local suit2=0--四件套装id
--     local starNum2=0--四件套对应的星数


--     suitTypeList={}--勋章分类List
--     for i = 1, LengthOfTable(this.itemlist) do
--         local suitId=MedalConfig[this.itemlist[i]].Suit
--         local suitType=MedalSuitConfig[suitId].Type

--         local suitIdList={}
--         if suitTypeList[suitType] then

--             table.insert(suitTypeList[suitType].id,suitId)
--             suitTypeList[suitType]={["num"]=suitTypeList[suitType].num+1,["id"]=suitTypeList[suitType].id}
--         else
--             table.insert(suitIdList,suitId)
--             suitTypeList[suitType]={["num"]=1,["id"]=suitIdList}
--         end
--     end 


--     -- local bestNum=0 --最大数量
--     -- local type=0--suit类型
--     -- for k,v in pairs(suitTypeList) do
--     --       --k:typeID  v:num
--     --       if v>bestNum then
--     --         bestNum=v
--     --         type=k
--     --       end
--     -- end

--     -- if bestNum==4 then
--     --     local num_F,num_S=this:Star(suitTypeList,type)

--     --     suit1=type
--     --     starNum1=num_S

--     --     suit2=type
--     --     starNum2=num_F
--     --     return suit1,starNum1,suit2,starNum2
--     -- end

--     -- if bestNum==3 then
--     --     local num_F,num_S=this:Star(suitTypeList,type)

--     --     suit1=type
--     --     starNum1=num_S

--     --     suit2=0
--     --     starNum2=0
--     --     return suit1,starNum1,suit2,starNum2
--     -- end

--     -- if bestNum==2 then
--     --     --TODO特殊情况 第二组数据判断是两件还是四件
--     --     if LengthOfTable(suitTypeList)==2 and LengthOfTable(this.itemlist)==4 then
--     --         --两组两件激活
--     --         local isEnter=false
--     --         for k,v in ipairs(suitTypeList) do
--     --             if isEnter then
--     --                 local num_F,num_S=this:Star(suitTypeList,k)
--     --                 suit1=k
--     --                 starNum1=num_F
--     --             else
--     --                 local num_F,num_S=this:Star(suitTypeList,k)
--     --                 suit2=k
--     --                 starNum2=num_F
--     --                 isEnter=true
--     --             end

--     --         end
--     --         return suit1,starNum1,suit2,starNum2
--     --     else
--     --         --一组两件激活
--     --         local num_F,num_S=this:Star(suitTypeList,type)
--     --         suit1=type
--     --         starNum1=num_F

--     --         suit2=0
--     --         starNum2=0
--     --         return suit1,starNum1,suit2,starNum2
--     --     end
--     -- else
--     --     --四种type 两件四件均不可激活
--     --     return suit1,starNum1,suit2,starNum2
--     -- end
-- end

-- function this:Star(suitTypeList,type)

--     local ids=suitTypeList[type].id--同一个type的所有Id
--     local StartSort={}
--     for i = 1, LengthOfTable(ids)  do
--         local star=MedalSuitConfig[ids[i]].Star
--         table.insert(StartSort,star)
--     end 



--     table.sort(StartSort, function(a, b)
--          return a<b
--     end)
--     return StartSort[1],StartSort[LengthOfTable(ids)-1]--最小和第二大
-- end


function this.SetColor(qualityId)--蓝 紫 金
    local str=""
    if qualityId==3 then

        str="<color=#5979AD>%s</color>"
    elseif qualityId==4 then
        str="<color=#7F38A2>%s</color>"
    elseif qualityId==5 then
        str="<color=#C68C3B>%s</color>"
    end
    return str

end

return MedalParticularsPopup