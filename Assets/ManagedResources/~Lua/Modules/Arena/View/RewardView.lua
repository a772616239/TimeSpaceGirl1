RewardView = {}
local goList={}
local viewList={}
local DAILYREWARD=1
local SEASONREWARD=2
--初始化组件（用于子类重写）
function RewardView:InitComponent()
    self.item = Util.GetGameObject(self.gameObject, "item")
    self.contentItem = Util.GetGameObject(self.gameObject, "contentItem")
    self.rewardBtn1=Util.GetGameObject(self.gameObject, "switchRewardPage/rewardBtn1")
    self.rewardBtn2=Util.GetGameObject(self.gameObject, "switchRewardPage/rewardBtn2")
    self.rewardBtn1Text=Util.GetGameObject(self.gameObject, "switchRewardPage/rewardBtn1/Text")
    self.rewardBtn2Text=Util.GetGameObject(self.gameObject, "switchRewardPage/rewardBtn2/Text")
    for i = 1, #ArenaManager.arenaRewardKey do
        local go = newObject(self.item)
        if(i==1) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("cn2-X1_tongyong_diyi")
        end
        if(i==2) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("cn2-X1_tongyong_dier")
        end
        if(i==3) then
            Util.GetGameObject(go, "rank2/Text"):GetComponent("Text").text=""
            Util.GetGameObject(go, "rank"):SetActive(true)
            Util.GetGameObject(go, "rank2"):SetActive(false)
            Util.GetGameObject(go, "rank"):GetComponent("Image").sprite =Util.LoadSprite("cn2-X1_tongyong_disan")
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
function RewardView:BindEvent()
    Util.AddClick(self.rewardBtn1, function()
        self:SwitchRewardPanel(DAILYREWARD)
    end)
    Util.AddClick(self.rewardBtn2, function()
        self:SwitchRewardPanel(SEASONREWARD)
    end)
end

--切换周奖励和赛季奖励
function RewardView:SwitchRewardPanel(index)
    if(index==DAILYREWARD) then
        self.rewardBtn1:GetComponent("Image").sprite =Util.LoadSprite("r_jingjichang_xiayeqian_01")
        self.rewardBtn2:GetComponent("Image").sprite =Util.LoadSprite("r_jingjichang_xiayeqian_02")
        self.rewardBtn1Text:GetComponent("Text").text=string.format("<color=#D0C3A6FF>%s</color>",GetLanguageStrById(10106))
        self.rewardBtn2Text:GetComponent("Text").text=string.format("<color=#47403BFF>%s</color>",GetLanguageStrById(10107))
        for i = 1, #ArenaManager.arenaRewardKey do
            for j=1,5 do
                local index = 5*(i-1)+j
                if viewList[index] then
                    if ArenaManager.dailyReward[i][j] then
                        viewList[index].gameObject:SetActive(true)
                        viewList[index]:OnOpen(false, ArenaManager.dailyReward[i][j], 0.97)
                    else
                        viewList[index].gameObject:SetActive(false)
                    end

                end
            end
        end
    end
    if(index==SEASONREWARD) then
        self.rewardBtn1:GetComponent("Image").sprite = Util.LoadSprite("r_jingjichang_xiayeqian_02")
        self.rewardBtn2:GetComponent("Image").sprite = Util.LoadSprite("r_jingjichang_xiayeqian_01")
        self.rewardBtn1Text:GetComponent("Text").text = string.format("<color=#47403BFF>%s</color>",GetLanguageStrById(10106))
        self.rewardBtn2Text:GetComponent("Text").text = string.format("<color=#D0C3A6FF>%s</color>",GetLanguageStrById(10107))
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
end




--添加事件监听（用于子类重写）
function RewardView:AddListener()
end

--移除事件监听（用于子类重写）
function RewardView:RemoveListener()
end

--界面打开时调用（用于子类重写）
function RewardView:OnOpen(...)

end

--界面关闭时调用（用于子类重写）
function RewardView:OnClose()

end

--界面销毁时调用（用于子类重写）
function RewardView:OnDestroy()
    goList = {}
    viewList = {}
end

return RewardView