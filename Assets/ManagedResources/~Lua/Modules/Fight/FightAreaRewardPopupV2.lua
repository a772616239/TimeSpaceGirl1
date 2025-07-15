require("Base/BasePanel")
local FightAreaRewardPopupV2 = Inherit(BasePanel)
local this = FightAreaRewardPopupV2
local _ItemList = {}
local _bossRewardList= {}
local _bossObjectList= {}
local _RewardList={}
local _RewardItemList= {}
local _RewardLevelList= {}
local _bossList= {}
local _levelList= {}
local tem = {}
local temlevel = {}
local indexNum=nil
--初始化组件（用于子类重写）
function FightAreaRewardPopupV2:InitComponent()
    this.btnClose=Util.GetGameObject(self.gameObject,"Bg/closeBtn")

    --获取背景遮罩
    this.mask=Util.GetGameObject(self.gameObject,"mask")
    this.bossDropPre=Util.GetGameObject(self.gameObject,"Bg/BossDropInfoGroupPre")
    this.levelDropPre=Util.GetGameObject(self.gameObject,"Bg/LevelDropPart")
    this.rewardPre=Util.GetGameObject(self.gameObject,"Bg/RewardInfoGroupPre")
    this.bossDropView=Util.GetGameObject(self.gameObject,"Bg/BossDropPart")
    this.BossDropTab=Util.GetGameObject(self.gameObject,"Tab/BossDropTab")
    this.LevelDropTab=Util.GetGameObject(self.gameObject,"Tab/LevelDropTab")
    this.SystemScrollView = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.bossDropView.transform,
         this.bossDropPre, Vector2.New(970, 937.5), 1, 10)
    this.SystemLevelScrollView = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.levelDropPre.transform,
         this.rewardPre, Vector2.New(970, 937.5), 1, 10)
end

--绑定事件（用于子类重写）
function FightAreaRewardPopupV2:BindEvent()
    Util.AddClick(this.btnClose,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)

    --绑定背景遮罩事件
     Util.AddClick(this.mask,function ()
        UIManager.OpenPanel(UIName.FightPointPassMainPanel)
    end)
    Util.AddClick(this.BossDropTab,function ()
        this.bossDropView.gameObject:SetActive(true)
        this.levelDropPre.gameObject:SetActive(false)
        Util.GetGameObject(this.BossDropTab,"select"):SetActive(true)
        Util.GetGameObject(this.LevelDropTab,"select"):SetActive(false)
    end)
    Util.AddClick(this.LevelDropTab,function ()
        this.bossDropView.gameObject:SetActive(false)
        this.levelDropPre.gameObject:SetActive(true)
        Util.GetGameObject(this.BossDropTab,"select"):SetActive(false)
        Util.GetGameObject(this.LevelDropTab,"select"):SetActive(true)
        local temlevel = {}
        for k, v in pairs(_levelList) do
           table.insert(temlevel, v)
        end
        this.SystemLevelScrollView:SetData(temlevel,function(dataIndex,go)
            self:showData(go,temlevel[dataIndex])
         end)
    end)
end

--添加事件监听（用于子类重写）
function FightAreaRewardPopupV2:AddListener()
    
end

--移除事件监听（用于子类重写）
function FightAreaRewardPopupV2:RemoveListener()
    
end

--界面打开时调用（用于子类重写）
function FightAreaRewardPopupV2:OnOpen()
    local curFightId = FightPointPassManager.GetCurFightId()
    local _levelConfig={}
    this.bossDropView.gameObject:SetActive(true)
    this.levelDropPre.gameObject:SetActive(false)
    Util.GetGameObject(this.BossDropTab,"select"):SetActive(true)
    Util.GetGameObject(this.LevelDropTab,"select"):SetActive(false)
    local _lsLevelConfig=ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)
    _levelConfig=ConfigManager.GetConfig(ConfigName.MainLevelConfig)
    local _lsint=1
    local _lslevelInt=1
    for i = 1, FightPointPassManager.maxChapterNum, 1 do
        _bossRewardList[i]=_lsLevelConfig[i].SimpleLevel
    end
    for i = FightPointPassManager.maxChapterNum, 15, 1 do
        if _lsint<=2 then
            _bossRewardList[i]=_lsLevelConfig[i].SimpleLevel
            _lsint=_lsint+1
        end
    end
    local _bo=false
    for key, value in pairs(_lsLevelConfig[FightPointPassManager.maxChapterNum].SimpleLevel) do
        if value>=FightPointPassManager.curOpenFight and _lslevelInt<=3 then
            _levelList[value]=ConfigManager.GetConfigData(ConfigName.MainLevelConfig, value)
            _lslevelInt=_lslevelInt+1
        end
    end
    tem = {}
    for k, v in pairs(_bossRewardList) do
        table.insert(tem, v)
    end
    indexNum=FightPointPassManager.maxChapterNum
    this.SystemScrollView:SetData(tem,function(dataIndex,go)
        self:BossLevelItem(tem[dataIndex],go,dataIndex,indexNum)
    end,1)
    temlevel = {}
    for k, v in pairs(_levelList) do
        table.insert(temlevel, v)
    end
    -- local data = {{isOpen = true}, {isOpen = true}, {isOpen = true}, {isOpen = true}, {isOpen = true}, {isOpen = true}}
    -- self.SystemScrollView:SetData(data, function(dataIndex, go) 
    --     Util.GetGameObject(go, "Text"):GetComponent("Text").text = dataIndex
    --     Util.AddOnceClick(go, function()
    --         Util.GetGameObject(go, "Image"):SetActive(not Util.GetGameObject(go, "Image").activeSelf)
    --         data[dataIndex].isOpen = Util.GetGameObject(go, "Image").activeSelf
    --         self.SystemScrollView:SetIndex(dataIndex)
    --     end)
    --     Util.GetGameObject(go, "Image"):SetActive(data[dataIndex].isOpen)
    -- end)

    -- this.SystemLevelScrollView:SetData(temlevel,function (dataIndex,go)
    --     self:showData(go,temlevel[dataIndex])
    -- end)
    
end
function this:BossLevelItem(temlevel,go,index,opIndex)
    if opIndex~=nil and index==opIndex then
        if not Util.GetGameObject(go,"ScrollFitterView")  then
            local _bossList={}

            for key, value in pairs(tem[index]) do
                if ConfigManager.GetConfigData(ConfigName.MainLevelConfig, value).BossDrop ==1 then
                    _bossList[value]=ConfigManager.GetConfigData(ConfigName.MainLevelConfig, value)
                end
            end
            local _lsLevel = {}
            for k, v in pairs(_bossList) do
                table.insert(_lsLevel, v)
            end
            local item=SubUIManager.Open(SubUIConfig.ScrollFitterView, go.transform,this.rewardPre, Vector2.New(970, #_lsLevel*254), 1, 10)

            item:SetData(_lsLevel,function (dataIndex,go)
                this:showData(go,_lsLevel[dataIndex])
            end)
        else
            destroy(Util.GetGameObject(go,"ScrollFitterView"))
        end
    else
        if Util.GetGameObject(go,"ScrollFitterView")  then
            destroy(Util.GetGameObject(go,"ScrollFitterView"))
        end
    end
    
    Util.AddOnceClick(Util.GetGameObject(go,"title/arrow"),function ()
        indexNum=index
        this.SystemScrollView:SetIndex(index)
    end)
    if FightPointPassManager.maxChapterNum>=index then
        Util.GetGameObject(go,"title/lock"):SetActive(false)
    else
        Util.GetGameObject(go,"title/lock"):SetActive(true)
    end
    Util.GetGameObject(go,"title/Name"):GetComponent("Text").text=GetLanguageStrById(ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)[index].Name)
    
end
function this:showData(go,data,Id)
    if not _RewardList[data.Id] then
        _RewardList[data.Id]=go
        local _lswardList={}
        for key, value in pairs(data.RewardShowMin) do
            _lswardList[key] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go,"Scroll View/Viewport/Content").transform)
            local rdata = {value[1], 0}    -- 不显示数量
            _lswardList[key]:OnOpen(false, rdata, 1)
        end
        _RewardItemList[data.Id]=_lswardList
        Util.GetGameObject(go,"Name"):GetComponent("Text").text=data.Name
    else
        _RewardList[data.Id]=go
        local _lswardList={}
        for key, value in pairs(data.RewardShowMin) do
            _lswardList[key] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go,"Scroll View/Viewport/Content").transform)
            local rdata = {value[1], 0}    -- 不显示数量
            _lswardList[key]:OnOpen(false, rdata, 1)
        end
        _RewardItemList[data.Id]=_lswardList
        Util.GetGameObject(go,"Name"):GetComponent("Text").text=data.Name
    end
end
function this:showLevelData(go,data,Id)
    if not _RewardLevelList[data.Id] then
        _RewardLevelList[data.Id]=go
        local _lswardList={}
        for key, value in pairs(data.RewardShowMin) do
            _lswardList[key] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go,"RewardInfoGroupPre/Scroll View/Viewport/Content").transform)
            local rdata = {value[1], 0}    -- 不显示数量
            _lswardList[key]:OnOpen(false, rdata, 0.9)
        end
        Util.GetGameObject(go,"title/Name"):GetComponent("Text").text=data.Name
    end
    if data.Id<=FightPointPassManager.curOpenFight then
        Util.GetGameObject(go,"title/lock"):SetActive(false)
    else
        Util.GetGameObject(go,"title/lock"):SetActive(true)
    end
    Util.GetGameObject(go,"RewardInfoGroupPre"):SetActive(false)
    if Id~=nil then
        if data.Id==Id then
            Util.GetGameObject(go,"RewardInfoGroupPre"):SetActive(true)
        end
    end
    Util.AddOnceClick(Util.GetGameObject(go,"title/arrow"),function ()
        this.SystemLevelScrollView:SetData(temlevel,function(dataIndex,go)
           self:showLevelData(go,temlevel[dataIndex],data.Id)
         end,1)
    end)
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightAreaRewardPopupV2:OnShow()
    -- Timer.New(function()
    --     -- 刷新数据
    --     for key, value in pairs(_bossList) do
    --         value:SetActive(true)
    --     end
    -- end, 0.2):Start()
end
function this.ItemAdapter(ItemConfig,curFightId,bossbo)
    local newGropPre=newObjToParent(this.bossDropPre,this.bossDropView.transform)
    local newRewardPre=newObjToParent(this.rewardPre,newGropPre.transform)
    for index, reward in ipairs(ItemConfig.RewardShowMin) do
        if not _RewardList[index] then
            _RewardList[index] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(newRewardPre,"Scroll View/Viewport/Content").transform)
        end
        local rdata = {reward[1], 0}    -- 不显示数量
        _RewardList[index]:OnOpen(false, rdata, 1, true)
    end
    if bossbo then
        Util.GetGameObject(newRewardPre,"title/lock"):SetActive(false)
    end
    Util.AddClick(Util.GetGameObject(newRewardPre,"title/arrow"),function ()
        for key, value in pairs(_bossList) do
            Util.GetGameObject(newRewardPre,"RewardInfoGroupPre"):SetActive(false)
            value:SetActive(false)
        end
        Util.GetGameObject(_bossList[curFightId],"RewardInfoGroupPre(Clone)"):SetActive(false)
        Timer.New(function()
            -- 刷新数据
            for key, value in pairs(_bossList) do
                value:SetActive(true)
            end
        end, 0.2):Start()
    end)
    newRewardPre:SetActive(false)
    return newGropPre
end
--界面关闭时调用（用于子类重写）
function FightAreaRewardPopupV2:OnClose()
    
end

--界面销毁时调用（用于子类重写）
function FightAreaRewardPopupV2:OnDestroy()

end

return FightAreaRewardPopupV2