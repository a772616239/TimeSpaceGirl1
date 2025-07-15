local ActivityDetail= quick_class("ActivityDetail")
local sortingOrder = 0
local itemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local listUpPre={}   --限时召唤
local rate={}
local listSoulUpPre={}   --魂印
local soulRate={}

local panelType
local detailText={
    [1] = HELP_TYPE.TimeLimitedCall,
    [2] = HELP_TYPE.QianKunBox,
}

function ActivityDetail:ctor(gameObject,type,effect, sortingOrder)
    self.gameObject = gameObject
    self.sortingOrder = sortingOrder
    if effect then
        self.effect = effect
    end
    panelType = type
    self:InitComponent(gameObject)
    self:BindEvent()
    self:OnShow()

end

function ActivityDetail:InitComponent(gameObject)
    self.closeBtn = Util.GetGameObject(self.gameObject,"close")
    self.itemGrid = Util.GetGameObject(self.gameObject,"panel/itemGrid")
    self.pre = Util.GetGameObject(self.gameObject,"panel/pre")
    self.LookDetailBtn = Util.GetGameObject(self.gameObject,"panel/Title3/updetail")
    self.content = Util.GetGameObject(self.gameObject,"panel/content/Text"):GetComponent("Text")
    self.time = Util.GetGameObject(self.gameObject,"tip"):GetComponent("Text")

    self.canvas = self.gameObject:GetComponent("Canvas")
    if self.canvas and self.sortingOrder then
        self.canvas.sortingOrder = self.sortingOrder + 1
    end
end

function ActivityDetail:BindEvent()
    Util.AddClick(self.closeBtn,function() 
        self:OnHide()
    end)
    Util.AddClick(self.LookDetailBtn,function() 
        self:LookDetailBtnAction()
    end)
end

function ActivityDetail:OnShow()
    self.gameObject:SetActive(true)
    local str = GetLanguageStrById(ConfigManager.TryGetConfigData(ConfigName.QAConfig,detailText[panelType]).content)--内容详情可以复用
    str = string.gsub(str,"{","<color=#9FE07C>") --m5
    str = string.gsub(str,"}","</color>")
    str = string.gsub(str,"|","\n")--换行
    self.content.text= str
    local str2
    --判断抽取的类型
    if panelType == 1 then--限时招募
        self:ReFreshUpHero()
        self:RefreshHeroRate()
        str2 = ActivityGiftManager.GetTimeStartToEnd(ActivityTypeDef.FindFairy)
    elseif panelType == 2 then--神秘盲盒
        self:ReFreshUpSoul()
        self:RefreshSoulRate()
        str2 = ActivityGiftManager.GetTimeStartToEnd(ActivityTypeDef.FindFairy)
    end

    self.time.text = GetLanguageStrById(12170)..str2
end
--============================乾坤包囊功能======================================
function ActivityDetail:ReFreshUpSoul()
    self.LookDetailBtn:SetActive(false)
    local UpSoul=RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.LOTTERY_SOUL_UP)
    if(not listSoulUpPre) then
        listSoulUpPre={}
    end
    if(not soulRate) then
        soulRate={}
    end
    
    
    local total = self:ReculateRate(UpSoul)
    for n,m in ipairs(UpSoul) do
        local weight = self:ReculateUpSoulRate(m.Reward[1])
        if m and weight > 0 then
            if not listSoulUpPre[n] then
                local pre = newObjToParent(self.pre,self.itemGrid.transform)
                pre:SetActive(true)
                listSoulUpPre[n] = SubUIManager.Open(SubUIConfig.ItemView,pre.transform)
                Util.GetGameObject(pre,"probability"):GetComponent("Text").text = string.format("%.2f", (weight/total)*100) .."%"
            end
            listSoulUpPre[n]:OnOpen(false, {m.Reward[1], m.Reward[2]}, 0.75, false)
            -- local weight = self:ReculateUpSoulRate(m.Reward[1])
            local tempName = listSoulUpPre[n].name:GetComponent("Text").text
            -- listSoulUpPre[n].name:GetComponent("Text").text = "<color=#EDB64C>"..string.format("%.2f", (weight/total)*100) .."%</color>"
            listSoulUpPre[n].gameObject:SetActive(true)
            table.insert(soulRate,{tag = GetLanguageStrById(12223),name = tempName,value = weight})
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
    local total = self:ReculateRate(soul)
    for index, v in ipairs(soul) do
        if itemConfig[v.Reward[1]].Quantity == 4 then
            table.insert(list4,v)--紫色
        elseif itemConfig[v.Reward[1]].Quantity == 5 then
            table.insert(list5,v)--金色
        elseif itemConfig[v.Reward[1]].Quantity == 6 then
            table.insert(list6,v)--红色
        else
            table.insert(list7,v)--其他
        end
    end

    local rate5other = self:ReculateRate(list6)
    for i = 1, #rate do
        rate5other = rate5other - rate[i].value
    end
    -- table.insert(soulRate,{tag=GetLanguageStrById(10193),name=GetLanguageStrById(11766)..GetLanguageStrById(10193),value=self:ReculateRate(list6)-soulRate[1].value-soulRate[2].value-soulRate[3].value})
    table.insert(soulRate,{tag = GetLanguageStrById(10193),name = GetLanguageStrById(11766)..GetLanguageStrById(10193),value = rate5other})
    table.insert(soulRate,{tag = GetLanguageStrById(10192),name = GetLanguageStrById(10192),value = self:ReculateRate(list5)})
    table.insert(soulRate,{tag = GetLanguageStrById(10195),name = GetLanguageStrById(10195),value = self:ReculateRate(list4)})
    table.insert(soulRate,{tag = GetLanguageStrById(11766),name = GetLanguageStrById(11766),value = self:ReculateRate(list7)})
    
    for n,m in ipairs(soulRate) do
        if m and m.value > 0 then
            local o = Util.GetGameObject(self.gameObject,"panel/rate/rate/rateprefab"..n)
            if not o then
            else
            o.gameObject:SetActive(true)
            Util.GetGameObject(o.gameObject,"star"):GetComponent("Text") .text = m.tag
            Util.GetGameObject(o.gameObject,"name"):GetComponent("Text") .text = m.name
            Util.GetGameObject(o.gameObject,"rate"):GetComponent("Text") .text = string.format("%.2f",(m.value/total)*100).."%"
            end
        end
    end

end

--============================破阵诛仙功能======================================
function ActivityDetail:ReFreshUpHero()
    self.LookDetailBtn:SetActive(true)
    local UpHero=RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED_UP)
    if not listUpPre then
        listUpPre = {}
    end
    if not rate then
        rate = { }
    end
    local total = self:ReculateRate(UpHero)
    for n,m in ipairs(UpHero) do
        local weight = self:ReculateUpHeroRate(m.Reward[1])
        if m and weight > 0 then
            if not listUpPre[n] then
                local pre = newObjToParent(self.pre,self.itemGrid.transform)
                pre:SetActive(true)
                listUpPre[n] = SubUIManager.Open(SubUIConfig.ItemView,pre.transform)
            end
            listUpPre[n]:OnOpen(false, {m.Reward[1], m.Reward[2]}, 0.75, false)

            local weight = self:ReculateUpHeroRate(m.Reward[1])
            local tempName = listUpPre[n].name:GetComponent("Text").text
            Util.GetGameObject(listUpPre[n].transform.parent,"probability"):GetComponent("Text").text = string.format("%.2f", (weight/total)*100).."%"
            listUpPre[n].gameObject:SetActive(true)
            table.insert(rate,{tag = GetLanguageStrById(12171),name = tempName,value = weight})
        end
    end
end
function ActivityDetail:ReculateUpHeroRate(id)
    local Hero = RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED)
    for n,m in ipairs(Hero) do
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

    local hero=RecruitManager.GetRewardPreviewData(PRE_REWARD_POOL_TYPE.TIME_LIMITED)
    local total = self:ReculateRate(hero)
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

    local rate5other = self:ReculateRate(list5)
    for i = 1, #rate do
        rate5other = rate5other - rate[i].value
    end
    table.insert(rate,{tag = GetLanguageStrById(12173),name = GetLanguageStrById(12174),value = rate5other})
    table.insert(rate,{tag = GetLanguageStrById(12175),name = GetLanguageStrById(12176),value = self:ReculateRate(list4)})
    table.insert(rate,{tag = GetLanguageStrById(12177),name = GetLanguageStrById(12178),value = self:ReculateRate(list3)})
    table.insert(rate,{tag = GetLanguageStrById(12179),name = GetLanguageStrById(12180),value = self:ReculateRate(list2)})

    for n,m in ipairs(rate) do
        if m and m.value > 0 then
            local o = Util.GetGameObject(self.gameObject,"panel/rate/rate/rateprefab"..n)
            if not o then
            else
                o.gameObject:SetActive(true)
                Util.GetGameObject(o.gameObject,"star"):GetComponent("Text") .text = m.tag
                Util.GetGameObject(o.gameObject,"name"):GetComponent("Text") .text = m.name
                Util.GetGameObject(o.gameObject,"rate"):GetComponent("Text") .text = string.format("%.2f",(m.value/total)*100).."%"
            end
        end
    end
end

--通用计算权重功能
function ActivityDetail:ReculateRate(list)
    local weight = 0
    for index, v in ipairs(list) do
        weight = v.Weight+weight
    end
    return weight
end

function ActivityDetail:LookDetailBtnAction()
    if panelType == 1 then
        UIManager.OpenPanel(UIName.HeroPreviewPanel, 1, false)
    elseif panelType == 2 then

    end
end

function ActivityDetail:OnHide()
    self.gameObject:SetActive(false)
    if self.effect then
        self.effect:SetActive(true)
    end
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