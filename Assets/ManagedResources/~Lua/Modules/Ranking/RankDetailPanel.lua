require("Base/BasePanel")
RankDetailPanel = Inherit(BasePanel)
local this = RankDetailPanel
local RankingRewardConfig = ConfigManager.GetConfig(ConfigName.RankingRewardConfig)
local isFirstOn = true--是否首次打开页面
local ItemView={}
local redPointList={}
local boxType={}
--初始化组件（用于子类重写）
function RankDetailPanel:InitComponent()
    this.mask = Util.GetGameObject(self.gameObject, "mask")
    this.BackBtn = Util.GetGameObject(self.gameObject, "btnBack")        

    this.scrollParentView = Util.GetGameObject(self.gameObject,"ScrollParentView")
    this.itemPre = Util.GetGameObject(self.gameObject,"ScrollParentView/ItemPre")
    local v21 = Util.GetGameObject(self.gameObject,"ScrollParentView"):GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(v21.width, v21.height),1,1,Vector2.New(0,20)) 

    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    -- 还没用到的    
    this.heroName = Util.GetGameObject(this.go, "contains/name")
    this.detail = Util.GetGameObject(this.go, "contains/detail")

    RankingRewardConfig = ConfigManager.GetConfig(ConfigName.RankingRewardConfig)    
    this.RefreshScroll(1)

end

function this.RefreshScroll(index)
    -- 根据Type 读表    
    local datalist={1,2,3,4,5,6,7,8,9,10,11,12}

    this.scrollView:SetData(datalist, function(index, root)    
        local item = Util.GetGameObject(root, "rewardList")
        local Received = Util.GetGameObject(root, "Received")
        local infoBtn = Util.GetGameObject(root, "helpBtn")
        if Received==true then
            SubUIManager.Open(SubUIConfig.ItemView, item.transform):OnOpen(false, {60190+index, 0}, 0.85)  
        end
        local data={}
        data.param1=0 
        this.SetHeadInfo(root,data,"测试玩家名字"..index,nil,10001,100)
        -- SubUIManager.Open(SubUIConfig.ItemView, hero.transform):OnOpen(false, {10001+index, 0}, 0.5)   
        Util.GetGameObject(root, "titleImage/titleText"):GetComponent("Text").text=GetLanguageStrById(RankingRewardConfig[1001+index].ContentsShow)

        --获取服务器参数刷新红点数据
        BindRedPointObject(RedPointType.RankingSort, redPointList[1])

        Util.AddClick(infoBtn, function()
            -- UIManager.OpenPanel(UIName.RewardItemPopup,{10001,10002},1)
            UIManager.OpenPanel(UIName.RankTopFivePanel,index)     
        end)
    end)
    if index then
        this.scrollView:SetIndex(index)
    end
end

function this.SetHeadInfo(root, data, playerName, playerHead, playerFrame, PlayerLevel)
    -- local integral = Util.GetGameObject(root,"integral"):GetComponent("Text")
    -- local _integral = data.param1 or 0
    -- if _integral < 0 then _integral = 0 end
    -- integral.text = _integral
    --玩家信息
    local headpos = Util.GetGameObject(root,"Head")
    local name = Util.GetGameObject(root,"name"):GetComponent("Text")
    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[root] then
        this.playerHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[root]:SetScale(Vector3.one * 0.5)
    name.text = playerName
    this.playerHead[root]:SetHead(playerHead)
    this.playerHead[root]:SetFrame(playerFrame)
    this.playerHead[root]:SetLevel(PlayerLevel)
end

function this.SetInfoShow()
    RankingRewardConfig = ConfigManager.GetConfig(ConfigName.RankingRewardConfig)

    -- 奖励界面
    -- UIManager.OpenPanel(UIName.RewardItemPopup,msg,1)
    -- RankingRewardConfig[4001].Reward[1][1]
    --文字描述 
    
    if RankingRewardConfig~=nil then
        -- this.titletip.text=GetLanguageStrById(RankingRewardConfig[1001].ContentsShow)
    else
        -- ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", data.AdjutantId, "SkillLvl", 11)
        Util.GetGameObject(this.go, "titleImage/titleText"):GetComponent("Text").text=GetLanguageStrById(RankingRewardConfig[1001].ContentsShow)
    end

    Util.AddClick(this.infoBtn, function()        
        -- 刷新红点数据
        PopupTipPanel.ShowTip(GetLanguageStrById(11711))      
    end)
 end

--绑定事件（用于子类重写）
function RankDetailPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.infoBtn, function()
        PopupTipPanel.ShowTip(GetLanguageStrById(11711))
        self:ClosePanel()
    end)
end

function this.showTip()
    PopupTipPanel.ShowTip(GetLanguageStrById(11711))
end

--添加事件监听（用于子类重写）
function RankDetailPanel:AddListener()
end

--移除事件监听（用于子类重写）
function RankDetailPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function RankDetailPanel:OnOpen(index) 
    -- 获取对应id  
    boxType=index 
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RankDetailPanel:OnShow()
    self:SetInfoShow()
end

-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
    if index == 2 then
        return true, GetLanguageStrById(11709)
    else
        return false
    end
end

--切换视图
function this.SwitchView(index)
end

function this.SingleRankKingListShow(index)
end

--界面关闭时调用（用于子类重写）
function RankDetailPanel:OnClose()
    isFirstOn = true
end

--界面销毁时调用（用于子类重写）
function RankDetailPanel:OnDestroy()
end

return RankDetailPanel