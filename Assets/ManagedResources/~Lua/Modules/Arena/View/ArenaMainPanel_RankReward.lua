local ArenaMainPanel_RankReward = {}
local goList={}
local viewList={}
local DAILYREWARD=1
local SEASONREWARD=2
local myViewList={}
--初始化组件（用于子类重写）
function ArenaMainPanel_RankReward:InitComponent()
    self.item = Util.GetGameObject(self.gameObject, "item")
    self.contentItem = Util.GetGameObject(self.gameObject, "contentItem")
    -- self.rewardBtn2=Util.GetGameObject(self.gameObject, "rewardBtn2")
    -- self.rewardBtn2Text=Util.GetGameObject(self.gameObject, "rewardBtn2/Text")
    for i = 1, #ArenaManager.arenaRewardKey do
        local go = newObject(self.item)
        if(i==1) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("N1_icon_paihangbang_mingci1")
        end
        if(i==2) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("N1_icon_paihangbang_mingci2")
        end
        if(i==3) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("N1_icon_paihangbang_mingci3")
        end
        if(i>3) then
            Util.GetGameObject(go, "rank"):SetActive(false)
            Util.GetGameObject(go, "rank2"):SetActive(true)
            -- Util.GetGameObject(go, "rank2"):GetComponent("Image").sprite =Util.LoadSprite("r_hero_zhuangbeidi")
            if ArenaManager.minRank[i] == ArenaManager.maxRank[i] then
                Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.maxRank[i]
            else
                if ArenaManager.maxRank[i] == 999999 then
                    Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.minRank[i].."+"
                else
                    Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text = ArenaManager.minRank[i].."-"..ArenaManager.maxRank[i]
                end
            end
        end
        for j=1,5 do
            local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(go, "content").transform)
            table.insert(viewList,view)
            if ArenaManager.dailyReward[i][j] then
                view.gameObject:SetActive(true)
                view:OnOpen(false,ArenaManager.dailyReward[i][j],0.97)
            else
                view.gameObject:SetActive(false)
            end
        end

        go.transform:SetParent(Util.GetTransform(self.gameObject, "rewardlist/Viewport"))
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go:SetActive(true)
        goList[i]=go
    end
end

--绑定事件（用于子类重写）
function ArenaMainPanel_RankReward:BindEvent()

end

--切换周奖励和赛季奖励
function ArenaMainPanel_RankReward:SwitchRewardPanel()

  
        -- self.rewardBtn2:GetComponent("Image").sprite = Util.LoadSprite("r_jingjichang_xiayeqian_01")
        -- self.rewardBtn2Text:GetComponent("Text").text = string.format("<color=#D0C3A6FF>%s</color>",GetLanguageStrById(10107))
        for i = 1, #ArenaManager.arenaRewardKey do
            for j=1,5 do
                local index = 5*(i-1)+j
                if viewList[index] then
                    if ArenaManager.seasonReward[i][j] then
                        viewList[index].gameObject:SetActive(true)
                        viewList[index]:OnOpen(false, ArenaManager.seasonReward[i][j], 0.97)
                    else
                        viewList[index].gameObject:SetActive(false)
                    end

                end
            end
        end
end




--添加事件监听（用于子类重写）
function ArenaMainPanel_RankReward:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaMainPanel_RankReward:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ArenaMainPanel_RankReward:OnOpen(...)
    self:SwitchRewardPanel()

    local myReward=Util.GetGameObject(self.gameObject, "myReward")
    self.rank=Util.GetGameObject(myReward, "rank"):GetComponent("Text")
    self.desc=Util.GetGameObject(myReward, "tip (1)")
    self.content=Util.GetGameObject(myReward, "content")
    if(ArenaManager.MyRank.rank ~= -1)
    then
        self.rank.text=ArenaManager.MyRank.rank
        self.desc:SetActive(true)

        for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArenaReward)) do
            if ArenaManager.MyRank.rank <= configInfo.MaxRank and ArenaManager.MyRank.rank >= configInfo.MinRank then
                self.ArenaRewardData = configInfo
            end
        end
        if  myViewList[ArenaManager.MyRank.rank]==nil then
            myViewList[ArenaManager.MyRank.rank]={}
        
        for j=1,5 do
            myViewList[ArenaManager.MyRank.rank][j] = SubUIManager.Open(SubUIConfig.ItemView, self.content.transform)
            if ArenaManager.seasonReward[self.ArenaRewardData.Id][j] then
                myViewList[ArenaManager.MyRank.rank][j].gameObject:SetActive(true)
                myViewList[ArenaManager.MyRank.rank][j]:OnOpen(false,ArenaManager.seasonReward[self.ArenaRewardData.Id][j],0.97)
            else
                myViewList[ArenaManager.MyRank.rank][j].gameObject:SetActive(false)
            end
        end
        end
    else
        self.rank.text=GetLanguageStrById(10041)
        self.desc:SetActive(false)
    end
end

--界面关闭时调用（用于子类重写）
function ArenaMainPanel_RankReward:OnClose()

end

--界面销毁时调用（用于子类重写）
function ArenaMainPanel_RankReward:OnDestroy()
    goList = {}
    viewList = {}
end

return ArenaMainPanel_RankReward