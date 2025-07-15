require("Base/BasePanel")
LoadingPanel = Inherit(BasePanel)
local this = LoadingPanel

--初始化组件（用于子类重写）
function LoadingPanel:InitComponent()
    this.Slider = Util.GetGameObject(self.gameObject, "Slider"):GetComponent("Slider")
    this.Tip = Util.GetGameObject(self.gameObject, "Slider/Image/LoadingText"):GetComponent("Text")
    this.tip = Util.GetGameObject(self.gameObject, "tip"):GetComponent("Text")
    this.oriBg = Util.GetGameObject(self.gameObject, "BG")
    this.NewBg = Util.GetGameObject(self.gameObject, "LoadBg")
    LoadingPanel.SetRandoBg()

    screenAdapte(Util.GetGameObject(self.gameObject, "bg1"))
    screenAdapte(Util.GetGameObject(self.gameObject, "bg2"))
end

local callList = {}
local retStrs = {}  --< 标记信息
local curIndex
local lerp = 0
local maxIndex = 0
local function update()
    lerp = math.clamp(lerp + Time.fixedDeltaTime * 15,0,1)
    this.Slider.value = this.Slider.value * (1-lerp) + curIndex * lerp
    this.Tip.text = string.format("%d",this.Slider.value/this.Slider.maxValue*100) .. "%"
end

function LoadingPanel.SetRandoBg()
    math.randomseed(os.time()) 
    local pic = math.random(1, 9)
    local loadingSprit2 = "cn2-X1_loading_0%s"
    local loadingSprit = GetPictureFont(loadingSprit2)
    -- LogError(loadingSprit)
    local loadspr = string.format(loadingSprit,pic)
    local LoadingSprite = Util.LoadSprite(loadspr)
    if LoadingSprite ~= nil then
        this.oriBg:SetActive(false)
        this.NewBg:SetActive(true)
        Util.GetGameObject(this.NewBg, "pic"):GetComponent("Image").sprite = LoadingSprite
    else
        this.NewBg:SetActive(false)
        this.oriBg:SetActive(true)
    end
    NetManager.CampSimpleInfoGetReq(function ()end)
    NetManager.CampWarInfoGetReq(function ()end)
end

function LoadingPanel.AddStep(func)
    table.insert(callList, func)
    maxIndex = maxIndex + 1
end

function LoadingPanel.OnStep()
    lerp = 0
    curIndex = curIndex + 1

    if callList[curIndex] then
        local retStr = callList[curIndex]()
        table.insert(retStrs, retStr)
    end
end

-- 登录时有接口报错时执行，防止登录报错卡死导致进不去游戏的问题
function LoadingPanel.ErrorStep(msg)
    --
    if curIndex >= maxIndex then return end

    -- 强制进入下一步
    LoadingPanel.OnStep()
end

function LoadingPanel.Start()
    if #callList <= 1 then
        return
    end
    UIManager.OpenPanel(UIName.LoadingPanel)
    UpdateBeat:Add(update)
    lerp = 0
    curIndex = 0
    this.Slider.maxValue = #callList - 1
    this.Slider.value = curIndex
    this.Tip.text = curIndex .. "%"--GetLanguageStrById(11346)
    this.SetTip()

    LoadingPanel.OnStep()
end

function this.SetTip()
    local time = System.DateTime.Now
    local num = time.Second
    if num > 12 then
        num = math.modf(num/12)
        if num == 0 then
            num = 12
        end
    end
    this.tip.text = GetLanguageStrById(50100 + num)
end

function LoadingPanel.End()
    UpdateBeat:Remove(update)
    this:ClosePanel()
    callList = {}
end

return LoadingPanel