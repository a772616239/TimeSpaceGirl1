--竞猜提示面板
local ATM_GuessTipView = {}
local this = ATM_GuessTipView
local betBattleInfo = nil
--主面板
local matchPanel = require("Modules/ArenaTopMatch/ArenaTopMatchPanel")
--倒计时
local count = 10
--标题
local resultText = {[0] = GetLanguageStrById(10134), [1] = GetLanguageStrById(10133)}
local resultColor = {
    [0] = Color.New(165 / 255, 165 / 255, 165 / 255, 1),
    [1] = Color.New(232 / 255, 216 / 255, 186 / 255, 1)
}
--竞猜胜负图片
local resultImage = {
    [0] = {name = "UI_effect_JJC_JieSuan_ShiBai_png"},
    [1] = {name = "UI_effect_JJC_JieSuan_ShengLi_png"}
}
--头像容器
local headList = {}
--竞猜币ItemId
local GUESS_COIN = ArenaTopMatchManager.GetGuessCoinID()
--竞猜币动态显示持续时长
local duration = 2
--计时间隔
local interval = 0.1
--竞猜币数量浮动图
local upAndDownImage = {[0] = "r_hero_zhanlixiajiang_png",[1] = "r_hero_zhanlishangsheng_png"}
--竞猜结果
local endResult = -1

function ATM_GuessTipView:InitComponent()
    this.title = Util.GetGameObject(this.gameObject, "Title"):GetComponent("Image")
    this.backBtn = Util.GetGameObject(this.gameObject, "BackBtn")
    -- this.coinNum = Util.GetGameObject(this.gameObject, "CoinNum"):GetComponent("Text")
    -- this.coinState = Util.GetGameObject(this.gameObject, "CoinNum/CoinState"):GetComponent("Image")
    this.time = Util.GetGameObject(this.gameObject, "Time"):GetComponent("Text")

    this.leftName = Util.GetGameObject(this.gameObject, "BattlePopup/Left/Grade/Name"):GetComponent("Text")
    this.leftHead = Util.GetGameObject(this.gameObject, "BattlePopup/Left/Grade/Head")
    this.leftMark = Util.GetGameObject(this.gameObject,"BattlePopup/Left/Grade/Mark"):GetComponent("Image")
    -- this.leftResult = Util.GetGameObject(this.gameObject, "BattlePopup/Left/Result"):GetComponent("Image")

    this.rightName = Util.GetGameObject(this.gameObject, "BattlePopup/Right/Grade/Name"):GetComponent("Text")
    this.rightHead = Util.GetGameObject(this.gameObject, "BattlePopup/Right/Grade/Head")
    this.rightMark = Util.GetGameObject(this.gameObject,"BattlePopup/Right/Grade/Mark"):GetComponent("Image")
    -- this.rightResult = Util.GetGameObject(this.gameObject, "BattlePopup/Right/Result"):GetComponent("Image")
end

function ATM_GuessTipView:BindEvent()
    Util.AddClick(
        this.backBtn,
        function()
            -- ArenaTopMatchManager.isGuessTipView=false
            matchPanel.CloseView(6)
        end
    )
end

function ATM_GuessTipView:AddListener()
end

function ATM_GuessTipView:RemoveListener()
end

function ATM_GuessTipView:OnOpen(...)
    -- if ArenaTopMatchManager.isGuessTipView then
    --     PlayUIAnim(Util.GetGameObject(this.gameObject,"BattlePopup"))
    -- end

    this.TimeCountDown()
    local IsCanBet = ArenaTopMatchManager.IsCanBet()
    
    if IsCanBet then
        betBattleInfo = ArenaTopMatchManager.GetBetBattleInfo()
        local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
        local isBetBlue = myBetTarget == betBattleInfo.myInfo.uid
        local isBetRed = myBetTarget == betBattleInfo.enemyInfo.uid
        if betBattleInfo.result == -1 then return end
        endResult = -1
        --设置标题
        if isBetBlue then
            local result = betBattleInfo.result
            this.title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jinbiaosai_jingcaichenggong"))
            -- this.title.color = resultColor[result]
            this.coinState.sprite = Util.LoadSprite(upAndDownImage[result])
            -- endResult = result
        end
        if isBetRed then
            local result = (betBattleInfo.result+1)%2
            this.title.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_jinbiaosai_jingcaichenggong"))
            -- this.title.color = resultColor[result]
            this.coinState.sprite = Util.LoadSprite(upAndDownImage[result])
            -- endResult = result
        end
        this.coinState:SetNativeSize()

        --设置玩家名
        SetRobotName(betBattleInfo.myInfo.uid, betBattleInfo.myInfo.name)
        SetRobotName(betBattleInfo.enemyInfo.uid, betBattleInfo.enemyInfo.name)
        
        this.SetHead(this.leftHead, betBattleInfo.myInfo)
        this.SetHead(this.rightHead, betBattleInfo.enemyInfo)
        this.SetResultIcon(this.leftResult, this.rightResult, betBattleInfo.result)

        --设置押注标志
        this.leftMark.enabled = isBetBlue
        this.rightMark.enabled = isBetRed

        --设置竞猜币
        -- this.SetCoin()
    end
end

function ATM_GuessTipView:OnShow()
end

function ATM_GuessTipView:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if this.coinTimer then
        this.coinTimer:Stop()
        this.coinTimer=nil
    end
    -- ArenaTopMatchManager.isGuessTipView=false
end

function ATM_GuessTipView:OnDestroy()
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
                    matchPanel.CloseView(6)
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
    headList[head]:SetScale(Vector3.one * 0.7)
    headList[head]:SetHead(data.head)
    headList[head]:SetFrame(data.headFrame)
    headList[head]:SetLevel(data.level)
end

--设置胜负图片
function this.SetResultIcon(obj1, obj2, result)
    if result == 1 then
        -- obj1.sprite = Util.LoadSprite(resultImage[1].name)
        -- obj2.sprite = Util.LoadSprite(resultImage[0].name)
    elseif result == 0 then
        -- obj1.sprite = Util.LoadSprite(resultImage[0].name)
        -- obj2.sprite = Util.LoadSprite(resultImage[1].name)
    end
end

-- --设置竞猜币
-- function this.SetCoin()
--     local oldNum= ArenaTopMatchManager.GetCoinNum() + ArenaTopMatchManager.GetMyBetCoins()
--     local newNum = BagManager.GetItemCountById(GUESS_COIN)
    
--     local tempNum = oldNum

--     if this.coinTimer then
--         this.coinTimer:Stop()
--         this.coinTimer = nil
--     end
--     if not this.coinTimer then
--         this.coinTimer = Timer.New(function()
--             local addNum = math.floor(tonumber((newNum-tempNum)/(duration/interval))) 
--             if newNum - tempNum > 0 then
--                 addNum = addNum > 0 and addNum or 1
--             end
--             oldNum = oldNum + addNum
--             if oldNum >= newNum then
--                 oldNum = newNum
--                 this.coinTimer:Stop()
--             end
            
--             this.coinNum.text = string.format(GetLanguageStrById(10164),oldNum)
--         end,interval,-1,true)
--         this.coinTimer:Start()
--     end
-- end

return ATM_GuessTipView