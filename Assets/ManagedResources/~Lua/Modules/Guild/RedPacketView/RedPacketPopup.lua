require("Base/BasePanel")
local RedPacketPopup = Inherit(BasePanel)
local this=RedPacketPopup
this.playerScrollHead={}--滚动条头像
this.sendPlayerHead={}--发送者头像
--红包资源名
local RedPacketName = {"cn2-X1_gonghui_hongbao_01_zh","cn2-X1_gonghui_hongbao_02_zh","cn2-X1_gonghui_hongbao_03_zh"}

function RedPacketPopup:InitComponent()
    this.panel = Util.GetGameObject(self.gameObject,"Panel")
    this.backBtn = Util.GetGameObject(this.panel,"BackBtn")
    this.title = Util.GetGameObject(this.panel,"RedPack"):GetComponent("Image")--红包类型名
    this.titleTip = Util.GetGameObject(this.panel,"Info/Text"):GetComponent("Text")--红包寄语

    this.playerHead = Util.GetGameObject(this.panel,"Info/PlayerHead")--发送者头像
    this.playerInfo = Util.GetGameObject(this.panel,"Info/PlayerInfo/Name"):GetComponent("Text")
    -- this.image = Util.GetGameObject(this.panel,"Info/Image"):GetComponent("Image")--已领完提示

    this.surplusNum = Util.GetGameObject(this.panel,"Info/SurplusNum/Num"):GetComponent("Text")--剩余个数
    this.surplusTime = Util.GetGameObject(this.panel,"Info/SurplusTime/Time"):GetComponent("Text")--剩余时间

    this.scrollRoot = Util.GetGameObject(this.panel,"ScrollRoot")--滚动条根节点
    this.redPacketPre = Util.GetGameObject(this.panel,"ScrollRoot/RedPacketPre")
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.redPacketPre, nil,
    Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,1,Vector2.New(0,0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2

    this.id = 0 --红包表Id
    this.redId = 0 --红包动态Id
end

function RedPacketPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

function RedPacketPopup:AddListener()

end

function RedPacketPopup:RemoveListener()

end

function RedPacketPopup:OnOpen(...)
    local args = {...}
    this.redId = args[1]
    this.id = args[2]
end

function RedPacketPopup:OnShow()
    this.InitView(this.redId, this.id)
end

function RedPacketPopup:OnClose()

end

function RedPacketPopup:OnDestroy()
    this.scrollView = nil
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--初始化面板
function this.InitView(redId,id)
    local config = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig, id)

    this.title.sprite = Util.LoadSprite(RedPacketName[id])
    this.titleTip.text = GetLanguageStrById(config.SendWord)

    NetManager.GetRedPackageDetailRequest(redId,function(msg)
        if not this.sendPlayerHead[this.panel] then
            this.sendPlayerHead[this.panel] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,this.playerHead)
        end
        this.sendPlayerHead[this.panel]:Reset()
        this.sendPlayerHead[this.panel]:SetHead(msg.head)
        this.sendPlayerHead[this.panel]:SetFrame(msg.headFrame)
        this.sendPlayerHead[this.panel]:SetScale(Vector3.one*0.65)
        this.playerInfo.text = msg.sendName

        local data = msg.info
        table.sort(data,function(a,b)
            return a.count > b.count
        end)

        this.scrollView:SetData(data,function(index,root)
            this.SetShow(root,data[index],index)
        end)
        this.scrollView:SetIndex(1)

        this.surplusNum.text = --[[GetLanguageStrById(11066)..]]config.Num - #data.."/"..config.Num
        this.TimeCountDown(msg.remainTime)
    end)
end

--设置每一条数据
function this.SetShow(root,data,index)
    root:SetActive(true)
    local bg = Util.GetGameObject(root,"Bg"):GetComponent("Image")
    local selfBG = Util.GetGameObject(root,"SelfBG/Text"):GetComponent("Text")
    local playerHead = Util.GetGameObject(root,"PlayerHead")
    local bestImage = Util.GetGameObject(root,"BestImage"):GetComponent("Image")
    local playerName = Util.GetGameObject(root,"PlayerName"):GetComponent("Text")
    local time = Util.GetGameObject(root,"Time"):GetComponent("Text")
    local rewardIcon = Util.GetGameObject(root,"RewardIcon"):GetComponent("Image")
    local rewardNum = Util.GetGameObject(root,"RewardNum"):GetComponent("Text")

    selfBG.enabled = PlayerManager.uid == data.uid

    --设置头像
    if not this.playerScrollHead[root] then
        this.playerScrollHead[root] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD,playerHead)
    end
    this.playerScrollHead[root]:Reset()
    this.playerScrollHead[root]:SetHead(data.head)
    this.playerScrollHead[root]:SetFrame(data.headFrame)
    this.playerScrollHead[root]:SetScale(Vector3.one*0.6)

    --手气最佳
    bestImage.enabled = index == 1
    bestImage.transform:SetSiblingIndex(1)

    --职位
    local grant
    for k,v in pairs(GUILD_GRANT) do
        if data.position == v then
            grant = GUILD_GRANT_STR[v]
            break
       end
    end

    playerName.text = data.name.." <size=30>("..grant..")</size>"
    time.text = FindFairyManager.TimeStampToDateStr(data.time)
    rewardIcon.sprite = SetIcon(data.itemId)
    rewardNum.text = data.count
end

--活动时间倒计时
function this.TimeCountDown(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.surplusTime.text = --[[GetLanguageStrById(10028)..]]TimeToHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
            
            this.timer:Stop()
            this.timer = nil
            this:ClosePanel()
            Game.GlobalEvent:DispatchEvent(GameEvent.GuildRedPacket.OnRefreshGetRedPacket)
            return
        end
        timeDown = timeDown - 1
        this.surplusTime.text = --[[GetLanguageStrById(10028)..]]TimeToHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

return RedPacketPopup