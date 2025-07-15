local ActivityDetail = quick_class("ActivityDetail")
local sortingOrder = 0
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local listUpPre = {}   --限时召唤
local rate = {}
local listSoulUpPre = {}   --魂印
local soulRate = {}

local panelType
local detailText = {
    [1] = HELP_TYPE.TimeLimitedCall,
    [2] = HELP_TYPE.QianKunBox,
}

function ActivityDetail:ctor(gameObject,type)
    self.gameObject = gameObject
    panelType = type
    self:InitComponent(gameObject)
    self:BindEvent()
    self:OnShow()

end

function ActivityDetail:InitComponent(gameObject)
    self.closeBtn = Util.GetGameObject(self.gameObject,"close")
    self.itemGrid = Util.GetGameObject(self.gameObject,"panel/itemGrid")
    self.LookDetailBtn = Util.GetGameObject(self.gameObject,"panel/Title3/updetail")
    self.content = Util.GetGameObject(self.gameObject,"panel/content/Text"):GetComponent("Text")
    self.time = Util.GetGameObject(self.gameObject,"tip"):GetComponent("Text")
end

function ActivityDetail:BindEvent()
    Util.AddClick(self.closeBtn.gameObject,function() self:OnHide()  end)
    Util.AddClick(self.LookDetailBtn.gameObject,function() self:LookDetailBtnAction() end)
end

function ActivityDetail:OnShow()
    self.gameObject:SetActive(true)
    local str = GetLanguageStrById(ConfigManager.TryGetConfigData(ConfigName.QAConfig,detailText[panelType]).content)--内容详情可以复用
    str = string.gsub(str,"{","<color=#D48A07>")
    str = string.gsub(str,"}","</color>")
    str = string.gsub(str,"|","\n")--换行
    self.content.text = str
    local str2
    --判断抽取的类型
    if panelType == 1 then--破阵诛仙
        self:ReFreshUpHero()
        self:RefreshHeroRate()
        str2 = ActivityGiftManager.GetTimeStartToEnd(ActivityTypeDef.FindFairy)
    elseif panelType == 2 then--乾坤包囊
        self:ReFreshUpSoul()
        self:RefreshSoulRate()
        str2 = ActivityGiftManager.GetTimeStartToEnd(ActivityTypeDef.FindFairy)
    end

    self.time.text = GetLanguageStrById(12170)..str2
end
--============================乾坤包囊功能======================================
function ActivityDetail:ReFreshUpSoul()
    self.LookDetailBtn:SetActive(false)
    local UpSoul = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.LOTTERY_SOUL_UP)
    if not listSoulUpPre then
        listSoulUpPre = {}
    end
    if not soulRate then
        soulRate = {}
    end
    for n,m in ipairs(UpSoul) do
        if m then
            if not listSoulUpPre[n] then
                listSoulUpPre[n] = SubUIManager.Open(SubUIConfig.ItemView,self.itemGrid.transform)
            end
            listSoulUpPre[n]:OnOpen(false, {m.Reward[1], m.Reward[2]}, 1.1, true)
            local weight = self:ReculateUpSoulRate(m.Reward[1])
            local tempName = listSoulUpPre[n].name:GetComponent("Text").text
            listSoulUpPre[n].name:GetComponent("Text").text="<color=#EDB64C>"..string.format("%.2f", (weight/100000)*100) .."%</color>"
            listSoulUpPre[n].gameObject:SetActive(true)
            table.insert(soulRate,{tag = GetLanguageStrById(12223),name=tempName,value = weight})
        end
    end
end
--计算所有的比重
function ActivityDetail:ReculateUpSoulRate(id)
    local Soul = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.LOTTERY_SOUL)
    for n,m in ipairs(Soul) do
        if m and id == m.Reward[1] then
            return m.Weight
        end
    end
    return 0
end

function ActivityDetail:RefreshSoulRate()
    local list4 = {}
    local list5 = {}
    local list6 = {}
    local list7 = {}

    local soul = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.LOTTERY_SOUL)
    for index, v in ipairs(soul) do
        if itemConfig[v.Reward[1]].Quantity == 4 and itemConfig[v.Reward[1]].ItemType == 13 then
            table.insert(list4,v)--紫色
        elseif itemConfig[v.Reward[1]].Quantity == 5 and itemConfig[v.Reward[1]].ItemType == 13 then
            table.insert(list5,v)--金色
        elseif itemConfig[v.Reward[1]].Quantity == 6 and itemConfig[v.Reward[1]].ItemType == 13 then
            table.insert(list6,v)--红色
        else
            table.insert(list7,v)--其他
        end
    end

    table.insert(soulRate,{tag = GetLanguageStrById(10193), name = GetLanguageStrById(11766)..GetLanguageStrById(10193), value = self:ReculateRate(list6)-soulRate[1].value-soulRate[2].value-soulRate[3].value})
    table.insert(soulRate,{tag = GetLanguageStrById(10192), name = GetLanguageStrById(10192), value = self:ReculateRate(list5)})
    table.insert(soulRate,{tag = GetLanguageStrById(10195), name = GetLanguageStrById(10195), value = self:ReculateRate(list4)})
    table.insert(soulRate,{tag = GetLanguageStrById(11766), name = GetLanguageStrById(11766), value = self:ReculateRate(list7)})
    
    for n,m in ipairs(soulRate) do
        if m and m.value > 0 then
            local o = Util.GetGameObject(self.gameObject,"panel/rate/rate/rateprefab"..n)
            if not o then
            else
                o.gameObject:SetActive(true)
                Util.GetGameObject(o.gameObject,"star"):GetComponent("Text") .text = m.tag
                Util.GetGameObject(o.gameObject,"name"):GetComponent("Text") .text = m.name
                Util.GetGameObject(o.gameObject,"rate"):GetComponent("Text") .text = string.format("%.2f",(m.value/100000)*100).."%"
            end
        end
    end
end

--============================破阵诛仙功能======================================
function ActivityDetail:ReFreshUpHero()
    self.LookDetailBtn:SetActive(true)
    local UpHero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED_UP)
    if not listUpPre then
        listUpPre = {}
    end
    if not rate then
        rate = {}
    end
    for n,m in ipairs(UpHero) do
        if m then
            if not listUpPre[n] then
                listUpPre[n] = SubUIManager.Open(SubUIConfig.ItemView,self.itemGrid.transform)
            end
            listUpPre[n]:OnOpen(false, {m.Reward[1], m.Reward[2]}, 1.1, true)
            local weight = self:ReculateUpHeroRate(m.Reward[1])
            local tempName = listUpPre[n].name:GetComponent("Text").text
            listUpPre[n].name:GetComponent("Text").text = "<color=#EDB64C>"..string.format("%.2f", (weight/100000)*100) .."%</color>"
            listUpPre[n].gameObject:SetActive(true)
            table.insert(rate,{tag = GetLanguageStrById(12171),name = tempName,value=weight})
        end
    end
end
function ActivityDetail:ReculateUpHeroRate(id)
    local Hero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED)
    for n, m in ipairs(Hero) do
        if m and id == m.Reward[1] then
            return m.Weight
        end
    end
    return 0
end

function ActivityDetail:RefreshHeroRate()
    local list3 = {}
    local list4 = {}
    local list5 = {}
    local list2 = {}

    local hero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED)
    for index, v in ipairs(hero) do
        if itemConfig[v.Reward[1]].HeroStar[2] == 3 then
            table.insert(list3,v)
        elseif itemConfig[v.Reward[1]].HeroStar[2] == 4 then
            table.insert(list4,v)
        elseif itemConfig[v.Reward[1]].HeroStar[2] == 5 then
            table.insert(list5,v)
        elseif itemConfig[v.Reward[1]].HeroStar[2] == 2 then
            table.insert(list2,v)
        end
    end

    table.insert(rate, {tag = GetLanguageStrById(12173), name = GetLanguageStrById(12174), value = self:ReculateRate(list5)-rate[1].value-rate[2].value-rate[3].value})
    table.insert(rate, {tag = GetLanguageStrById(12175), name = GetLanguageStrById(12176), value = self:ReculateRate(list4)})
    table.insert(rate, {tag = GetLanguageStrById(12177), name = GetLanguageStrById(12178), value = self:ReculateRate(list3)})
    table.insert(rate, {tag = GetLanguageStrById(12179), name = GetLanguageStrById(12180), value = self:ReculateRate(list2)})
    
    for n,m in ipairs(rate) do
        if m and m.value > 0 then
            local o = Util.GetGameObject(self.gameObject,"panel/rate/rate/rateprefab"..n)
            if not o then
            else
            o.gameObject:SetActive(true)
            Util.GetGameObject(o.gameObject,"star"):GetComponent("Text") .text = m.tag
            Util.GetGameObject(o.gameObject,"name"):GetComponent("Text") .text = m.name
            Util.GetGameObject(o.gameObject,"rate"):GetComponent("Text") .text = string.format("%.2f",(m.value/100000)*100).."%"
            end
        end
    end
end

--通用计算权重功能
function ActivityDetail:ReculateRate(list)
    local weight = 0
    for index, v in ipairs(list) do
        weight = v.Weight + weight
    end
    return weight
end

function ActivityDetail:LookDetailBtnAction()
    if panelType == 1 then
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 1,false)
    elseif panelType == 2 then

    end
end

function ActivityDetail:OnHide()
    self.gameObject:SetActive(false)
    if rate then
        for n,m in ipairs(rate) do
            if not rate[n] then
                local o = Util.GetGameObject(self.gameObject,"panel/rate/rateprefab"..n)
                o.gameObject.SetActive(false)
            end
        end
        rate = {}
    end

    if soulRate then
        for n,m in ipairs(soulRate) do
            if not soulRate[n] then
                local o = Util.GetGameObject(self.gameObject,"panel/rate/rateprefab"..n)
                o.gameObject.SetActive(false)
            end
        end
        soulRate = {}
    end
end

function ActivityDetail:OnDestroy()
    listUpPre = nil
    rate = nil
    listSoulUpPre = nil
    soulRate = nil
end

return ActivityDetail