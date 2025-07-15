require("Base/BasePanel")
RankTopFivePanel = Inherit(BasePanel)
local this = RankTopFivePanel
--初始化组件（用于子类重写）
function RankTopFivePanel:InitComponent()
    this.mask=Util.GetGameObject(self.gameObject, "BackMask")
    this.BackBtn=Util.GetGameObject(self.gameObject, "btnBack")
    this.topList=Util.GetGameObject(self.gameObject, "bg")
    Util.GetGameObject(self.gameObject, "Top/tip"):GetComponent("Text").text=GetLanguageStrById("50206")
end

--绑定事件（用于子类重写）
function RankTopFivePanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function()
        self:ClosePanel()
    end)
end

function this.showTip()
    PopupTipPanel.ShowTip(GetLanguageStrById(11711))
end

function this.SetHeadInfo(grid,root, data, playerName, playerHead, playerFrame, PlayerLevel)
    -- local integral = Util.GetGameObject(root,"integral"):GetComponent("Text")
    -- local _integral = data.param1 or 0
    -- if _integral < 0 then _integral = 0 end
    -- integral.text = _integral
    --玩家信息
    local headpos = Util.GetGameObject(root,"Head")
    local name = Util.GetGameObject(grid,"name"):GetComponent("Text")
    if not this.playerHead then
        this.playerHead = {}
    end
    if not this.playerHead[root] then
        this.playerHead[root] = SubUIManager.Open(SubUIConfig.PlayerHeadView, headpos.transform)
    end
    this.playerHead[root]:SetScale(Vector3.one * 0.6)
    name.text = playerName
    this.playerHead[root]:SetHead(playerHead)
    this.playerHead[root]:SetFrame(playerFrame)
    this.playerHead[root]:SetLevel(PlayerLevel)
end

--添加事件监听（用于子类重写）
function RankTopFivePanel:AddListener()
end

--移除事件监听（用于子类重写）
function RankTopFivePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function RankTopFivePanel:OnOpen(_sData)    
    --yh todo 数据刷新
      this.RefreshTopFive(_sData)  
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function RankTopFivePanel:OnShow()
end

-- tab可用性检测
function this.PageTabIsLockCheck(index)
end

--切换视图
function this.SwitchView(index)
end

-- 设置排名 无 
function this.SetTopZero(go)
    for i = 1, 4 do
        Util.GetGameObject(go, "SortNum_"..i):SetActive(false)
    end
end

-- 设置排名 无 
function this.SetTopRank(go,rank)
    if rank <=3 then
        Util.GetGameObject(go, "SortNum_"..rank):SetActive(true)
    else
        local obj=Util.GetGameObject(go, "SortNum_"..4)
        obj:SetActive(true)
        Util.GetGameObject(obj, "TitleText"):GetComponent("Text").text=rank
    end
end

function this.RefreshTopFive(data)
    for i = 1, 5 do
        local go = Util.GetGameObject(this.topList, "top_"..i.."/armorInfo")
        local reward = Util.GetGameObject(go, "rewardTime"):GetComponent("Text")
        local name = Util.GetGameObject(go, "name"):GetComponent("Text")
        local item = Util.GetGameObject(go, "grid/Item")
        local head = Util.GetGameObject(item, "Head").gameObject
        local sortNum = Util.GetGameObject(go, "SortNum")
        this.SetTopZero(sortNum)       
        if data[i]~=nil then
            reward.text=this.getTimeStamp(data[i].time)
            name.text=data[i].name
            this.SetHeadInfo(go,head,data,data[i].name, data[i].head, data[i].headFrame, data[i].level)
            this.SetTopRank(go,data[i].rank) 
            this.AddPlayerInfoClick(head, data[i].uid) 
            go:SetActive(true)                             
        else
            go:SetActive(false)
        end
    end
   
end

--玩家信息弹窗
function this.AddPlayerInfoClick(root,uid)
    -- LogError("id "..uid)
    Util.AddOnceClick(root,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, uid)
    end)
end

--界面关闭时调用（用于子类重写）
function RankTopFivePanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function RankTopFivePanel:OnDestroy()
end

-- 时间戳转化
function this.getTimeStamp(t)
    return os.date("%Y-%m-%d %H:%M:%S",t/1000)
end


return RankTopFivePanel