require("Base/BasePanel")
FightPointPassRankPopup = Inherit(BasePanel)
local this=FightPointPassRankPopup

this.rankListData={}
this.playerScrollHead={}--滚动条头像
this.mainLevelConfig=nil
--初始化组件（用于子类重写）
function FightPointPassRankPopup:InitComponent()

    this.backBtn=Util.GetGameObject(self.gameObject, "Panel/BackBtn")

    this.scrollParentView=Util.GetGameObject(self.gameObject,"Panel/ScrollParentView")
    this.itemPre=Util.GetGameObject(self.gameObject,"Panel/ScrollParentView/ItemPre")
    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollParentView.transform,this.itemPre,
            nil,Vector2.New(903,928.53),1,1,Vector2.New(0,0))
    this.scrollView.gameObject:GetComponent("RectTransform").anchoredPosition= Vector2.New(0,0)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.myRankText=Util.GetGameObject(self.gameObject,"MyRank/MyRankText"):GetComponent("Text")
    this.myGateText=Util.GetGameObject(self.gameObject,"MyRank/MyGateText"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function FightPointPassRankPopup:BindEvent()

    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function FightPointPassRankPopup:AddListener()

end

--移除事件监听（用于子类重写）
function FightPointPassRankPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FightPointPassRankPopup:OnOpen(...)

    this.mainLevelConfig=ConfigManager.GetConfig(ConfigName.MainLevelConfig)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FightPointPassRankPopup:OnShow()
    this.SetInfo()
end

--界面关闭时调用（用于子类重写）
function FightPointPassRankPopup:OnClose()

    --SubUIManager.Close(this.scrollView)
    FightPointPassManager.isBeginFight = false

end

--界面销毁时调用（用于子类重写）
function FightPointPassRankPopup:OnDestroy()

    this.scrollView=nil
end


function this.SetInfo()
    this.rankListData={}
    NetManager.RequestRankInfo(RANK_TYPE.FIGHT_LEVEL_RANK, function (msg)
        if tostring(msg.myRankInfo.rank)=="-1" then
            this.myRankText.text=GetLanguageStrById(10041)
            this.myGateText.text=""--tostring(this.mainLevelConfig[msg.myMainLevelRankInfo.fightId].Name)
        else
            this.myRankText.text=tostring(msg.myRankInfo.rank)
           
            this.myGateText.text=tostring(this.mainLevelConfig[msg.myRankInfo.param1].Name)
        end

        local length=#this.rankListData
        for i, rank in ipairs(msg.ranks) do
            this.rankListData[length+i]=rank
        end
        this.scrollView:SetData(this.rankListData,function(index,root)
            this.ShowInfo(root,this.rankListData[index],msg.myRankInfo.rank)
        end)
        this.scrollView:SetIndex(1)
    end)
end
--显示每条信息 1根物体 2数据 3排名
function this.ShowInfo(root,data,rank)
    --设置表现背景
    if rank==data.rankInfo.rank then
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(true)
    else
        Util.GetGameObject(root,"SelfBG").gameObject:SetActive(false)
    end
    --设置名次
    --local sortFrame = Util.GetGameObject(root, "SortNum/SortNum (1)"):GetComponent("Image")
    --sortFrame.sprite = SetRankNumFrame(data.rank)
    --设置名次
    local sortNumTabs={}
    for i = 1, 4 do
        sortNumTabs[i]=Util.GetGameObject(root,"SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if data.rankInfo.rank < 4 then
        sortNumTabs[data.rankInfo.rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = data.rankInfo.rank
    end
    --设置头像
    local head=Util.GetGameObject(root,"Head")
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root]=CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,head)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(data.head)
    this.playerScrollHead[root]:SetFrame(data.headFrame)
    this.playerScrollHead[root]:SetLevel(data.level)
    this.playerScrollHead[root]:SetScale(Vector3.one*0.7)
    --设置角色信息
    local name=Util.GetGameObject(root,"Name"):GetComponent("Text")
    --local level=Util.GetGameObject(root,"Level"):GetComponent("Text")
    local gate=Util.GetGameObject(root,"Gate"):GetComponent("Text")
    name.text=data.userName
    --level.text="等级："..data.level
    gate.text=this.mainLevelConfig[data.rankInfo.param1].Name
    --战力
    local force=Util.GetGameObject(root,"Force"):GetComponent("Text")
    force.text=data.force
end

return FightPointPassRankPopup