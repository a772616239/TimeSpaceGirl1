require("Base/BasePanel")
ArenaTopMatchGuessTipViewPopup = Inherit(BasePanel)
local this = ArenaTopMatchGuessTipViewPopup
local betBattleInfo = nil
--倒计时
local count = 10
--标题                        竞猜失败                                     竞猜成功
local resultText = {[0] = GetLanguageStrById(10134), [1] = GetLanguageStrById(10133)}
--竞猜胜负图片
local resultImage = {
    [0] = {name = "cn2-X1_jinbiaosai_lose"},
    [1] = {name = "cn2-X1_jinbiaosai_win"}
}
--头像容器
local headList = {}
--竞猜币ItemId
local GUESS_COIN = ArenaTopMatchManager.GetGuessCoinID()
--竞猜币动态显示持续时长
local duration = 2
--计时间隔
local interval = 0.1
--竞猜结果
local endResult = -1

--初始化组件（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:InitComponent()
    this.title = Util.GetGameObject(self.gameObject, "bg/Text"):GetComponent("Text")
    this.backBtn = Util.GetGameObject(self.gameObject, "BackBtn")

    this.coinNum = Util.GetGameObject(self.gameObject, "CoinNum"):GetComponent("Text")

    this.time = Util.GetGameObject(self.gameObject, "Time"):GetComponent("Text")

    this.leftName = Util.GetGameObject(self.gameObject, "BattlePopup/Left/Grade/Name"):GetComponent("Text")
    this.leftHead = Util.GetGameObject(self.gameObject, "BattlePopup/Left/Grade/Head")
    this.leftResult = Util.GetGameObject(self.gameObject, "BattlePopup/Left/Result"):GetComponent("Image")

    this.rightName = Util.GetGameObject(self.gameObject, "BattlePopup/Right/Grade/Name"):GetComponent("Text")
    this.rightHead = Util.GetGameObject(self.gameObject, "BattlePopup/Right/Grade/Head")
    this.rightResult = Util.GetGameObject(self.gameObject, "BattlePopup/Right/Result"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:OnOpen(...)
    this.TimeCountDown()
    local IsCanBet = ArenaTopMatchManager.IsCanBet()
    if IsCanBet then
        betBattleInfo = ArenaTopMatchManager.GetBetBattleInfo()
        local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
        local isBetBlue = myBetTarget == betBattleInfo.myInfo.uid
        local isBetRed = myBetTarget == betBattleInfo.enemyInfo.uid
        if betBattleInfo.result == -1 then return end
        -- endResult = -1

        local oldNum = ArenaTopMatchManager.GetCoinNum() + ArenaTopMatchManager.GetMyBetCoins()
        local newNum = BagManager.GetItemCountById(GUESS_COIN)
        -- local tempNum = oldNum
        local value = newNum - oldNum

        --设置标题
        if isBetBlue then
            local result = betBattleInfo.result
            this.title.text = resultText[result]
            -- endResult = result

            this.coinNum.color = UIColor.GREEN
            this.coinNum.text = "+" .. Mathf.Abs(value)
        end
        if isBetRed then
            local result = (betBattleInfo.result+1)%2
            this.title.text = resultText[result]
            -- endResult = result

            this.coinNum.color = UIColor.RED
            this.coinNum.text = "-" .. Mathf.Abs(value)
        end

        --设置玩家名
        SetRobotName(betBattleInfo.myInfo.uid, betBattleInfo.myInfo.name)
        SetRobotName(betBattleInfo.enemyInfo.uid, betBattleInfo.enemyInfo.name)

        this.SetHead(this.leftHead, betBattleInfo.myInfo)
        this.SetHead(this.rightHead, betBattleInfo.enemyInfo)
        this.SetResultIcon(this.leftResult, this.rightResult, betBattleInfo.result)

        --设置竞猜币
        -- this.SetCoin()
    end
end
--倒计时
function this.TimeCountDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    count = 10
    if not this.timer then
        this.timer = Timer.New(function()
                this.time.text = string.format(GetLanguageStrById(10163), count)
                count = count - 1
                if count <= 0 then
                    count = 0
                    this.timer:Stop()
                    this.timer = nil
                    this:ClosePanel()
                end
            end, 1, -1, true)
        this.timer:Start()
    end
end

--设置头像
function this.SetHead(head, data)
    if not headList[head] then
        headList[head] = CommonPool.CreateNode(POOL_ITEM_TYPE.PLAYER_HEAD, head)
    end
    headList[head]:Reset()
    headList[head]:SetScale(Vector3.one * 0.5)
    headList[head]:SetHead(data.head)
    headList[head]:SetFrame(data.headFrame)
    headList[head]:SetLevel(data.level)
end

--设置胜负图片
function this.SetResultIcon(obj1, obj2, result)
    if result == 1 then
        obj1.sprite = Util.LoadSprite(resultImage[1].name)
        obj2.sprite = Util.LoadSprite(resultImage[0].name)
    elseif result == 0 then
        obj1.sprite = Util.LoadSprite(resultImage[0].name)
        obj2.sprite = Util.LoadSprite(resultImage[1].name)
    end
end

--设置竞猜币
function this.SetCoin()
    -- local oldNum = ArenaTopMatchManager.GetCoinNum() + ArenaTopMatchManager.GetMyBetCoins()
    -- local newNum = BagManager.GetItemCountById(GUESS_COIN)
    -- local tempNum = oldNum

    -- local value = newNum - oldNum
    -- if value > oldNum then
    --     this.coinNum.color = UIColor.GREEN
    --     this.coinNum.text = "+" .. Mathf.Abs(value)
    -- else
    --     this.coinNum.color = UIColor.RED
    --     this.coinNum.text = "-" .. Mathf.Abs(value)
    -- end

    -- if this.coinTimer then
    --     this.coinTimer:Stop()
    --     this.coinTimer = nil
    -- end
    -- if not this.coinTimer then
    --     this.coinTimer = Timer.New(function()
    --     local addNum = math.floor((newNum-tempNum)/(duration/interval))
    --     if newNum-tempNum > 0 then
    --         addNum = addNum > 0 and addNum or 1
    --     end
    --     oldNum = oldNum+addNum
    --     if oldNum >= newNum then
    --         oldNum = newNum
    --         this.coinTimer:Stop()
    --     end

    --     if endResult == 0 then
    --         this.coinNum.color = UIColor.GREEN
    --         this.coinNum.text = "+" .. oldNum
    --     else
    --         this.coinNum.color = UIColor.RED
    --         this.coinNum.text = "-" .. oldNum
    --     end

    --     end,interval,-1,true)
    --     this.coinTimer:Start()
    -- end
end

--界面关闭时调用（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    -- if this.coinTimer then
    --     this.coinTimer:Stop()
    --     this.coinTimer=nil
    -- end
end

--界面销毁时调用（用于子类重写）
function ArenaTopMatchGuessTipViewPopup:OnDestroy()
end

return ArenaTopMatchGuessTipViewPopup