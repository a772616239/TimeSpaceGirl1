----- 公会红包-抢红包 -----
local this = {}
local sortingOrder = 0

function this:InitComponent(gameObject)
    this.group = Util.GetGameObject(gameObject,"Root/Group")--红包父节点
    this.noInfo = Util.GetGameObject(gameObject,"NoInfo")--无红包提示

    this.redPacketPre = Util.GetGameObject(gameObject,"ScrollRoot/RedPacketPre")--红包预设
    this.scrollRoot = Util.GetGameObject(gameObject,"ScrollRoot")
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,this.redPacketPre, nil,
        Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),1,3,Vector2.New(0,10))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function this:BindEvent()

end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.GuildRedPacket.OnRefreshGetRedPacket, this.InitGetView)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.GuildRedPacket.OnRefreshGetRedPacket, this.InitGetView)
end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    this:InitGetView()
end

function this:OnClose()

end

function this:OnDestroy()
    this.scrollView = nil
end

--初始化抢红包面板
function this:InitGetView()
    local dataLength = 0
    NetManager.GetAllRedPacketResponse(function(msg)
        -- for index, value in ipairs(msg.info) do
        -- end

        local data = {}
        for i,v in ipairs(msg.info) do
            table.insert(data,v)
        end
        this:DataSort(data)
        dataLength = #msg.info

        this.noInfo:SetActive(dataLength == 0)

        this.scrollView:SetData(data,function(index,root)
            this:SetView(root,data[index])
        end)
        this.scrollView:SetIndex(1)
    end)
end

function this:SetView(root,data)
    local fromPlayer = Util.GetGameObject(root,"FromPlayer"):GetComponent("Text")--红包来自玩家名
    local getBtn = Util.GetGameObject(root,"GetBtn")--抢红包按钮
    local mask = Util.GetGameObject(root,"Mask"):GetComponent("Image")--红包遮罩
    local getBtnImage = Util.GetGameObject(root,"GetBtn/Image"):GetComponent("Image")--按钮状态图片
    local numOrRecordBtn = Util.GetGameObject(root,"NumOrRecord")
    local numOrRecordText = Util.GetGameObject(root,"NumOrRecord/Text"):GetComponent("Text")--剩余礼包数或查看记录
    local redId = data.redId
    local config = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,data.redType)

    fromPlayer.text = GetLanguageStrById(11067)..data.userName.."</color>"
    root:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_hongbao_0"..data.redType))
    getBtn:GetComponent("Button").interactable = (config.Num - data.getCount) ~= 0 and data.isGet == 0 --抢红包按钮开关
    numOrRecordBtn:GetComponent("Button").interactable = data.isGet == 1 or (config.Num - data.getCount) == 0
    mask.gameObject:SetActive(data.isGet == 1 or (config.Num - data.getCount) == 0) --已领取或已领完 打开遮罩
    mask.transform:SetSiblingIndex(2)
    getBtnImage.gameObject:SetActive(true)
    if data.isGet == 1 then
        numOrRecordText.text = ""--GetLanguageStrById(11068)
        -- getBtnImage.sprite = Util.LoadSprite(BtnStateImage[2])            --GetLanguageStrById(10350)
        getBtnImage.gameObject:SetActive(false)
    else
        numOrRecordText.text = GetLanguageStrById(10535)..(config.Num - data.getCount).."/"..config.Num
        if config.Num == 10 then
            getBtnImage.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_qiang_01"))            --GetLanguageStrById(11069)
        else
            getBtnImage.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_qiang_02"))
        end
    end
    if (config.Num - data.getCount) == 0 then
        numOrRecordText.text = ""--GetLanguageStrById(11068)
        -- getBtnImage.sprite = Util.LoadSprite(BtnStateImage[3])            --GetLanguageStrById(11070)
        if config.Num == 10 then
            getBtnImage.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_qiang_03"))            --GetLanguageStrById(11069)
        else
            getBtnImage.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_gonghui_qiang_04"))
        end
    end
    getBtnImage:SetNativeSize()

    Util.AddOnceClick(getBtn,function()
        NetManager.GetRobRedPackageRequest(redId,function(msg)
            local success = msg.isSuccess
            local itemId = msg.itemId
            local count = msg.count
            if success == 1 then--红包抢成功
                local itemName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,itemId).Name)
                UIManager.OpenPanel(UIName.RedPacketPopup,redId,data.redType)
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11071),itemName,count))
            else--抢红包失败
                PopupTipPanel.ShowTipByLanguageId(11072)
            end
            this:InitGetView()
        end)
    end)
    Util.AddOnceClick(numOrRecordBtn,function()--查看记录
        NetManager.GetRedPackageDetailRequest(redId,function(msg)
            UIManager.OpenPanel(UIName.RedPacketPopup,redId,data.redType)
            this:InitGetView()
        end)
    end)
end

--数据排序
function this:DataSort(data)
     table.sort(data,function(a,b)
        if a.isGet == b.isGet then
            return a.sendTime > b.sendTime
        else
            return this:SortFun(a) < this:SortFun(b)
        end
     end)
end
function this:SortFun(x)
    if x.isGet == 0 then
        return 1 --抢
    else
        local config = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,x.redType)
        if x.isGet == 1 then
            return 2--已领取
        elseif (config.Num - x.getCount) == 0 then
            return 3 --已领完
        end
    end
end

return this