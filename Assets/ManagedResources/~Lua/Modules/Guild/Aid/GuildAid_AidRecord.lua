local this = {}
local recordPerList = {}
local titleText = {}
local errorCodeHint = ConfigManager.GetConfig(ConfigName.ErrorCodeHint)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function this:InitComponent(gameObject)
    this.emptyObj = Util.GetGameObject(gameObject, "GuildAid_AidRecord/emptyObj")
    this.rect = Util.GetGameObject(gameObject, "GuildAid_AidRecord/rect")
    for i = 1, 3 do
        recordPerList[i] = Util.GetGameObject(gameObject, "GuildAid_AidRecord/rect/grid/ver/recordPer (".. i ..")")
        titleText[i] = {}
        titleText[i][1] = Util.GetGameObject(gameObject, "GuildAid_AidRecord/rect/grid/ver/recordPer (".. i ..")/Mask/recordTex (1)")
    end
end

--绑定事件（用于子类重写）
function this:BindEvent()
end

--添加事件监听（用于子类重写）
function this:AddListener()
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function this:OnShow()
    if #MyGuildManager.allGuildHelpRecordInfo <= 0 then
        NetManager.GuildGetHelpLogRequest(function (msg)
            MyGuildManager.SetAllGuildHelpLogInfo(msg)
            this.OnShowPanelData()
        end)
    else
        this.OnShowPanelData()
    end
end
function  this.OnShowPanelData()
    local curallAidData = {}
    curallAidData[1] = {}
    curallAidData[2] = {}
    

    table.sort(MyGuildManager.allGuildHelpRecordInfo, function(a,b) return a.time > b.time end)
    for i = 1, #MyGuildManager.allGuildHelpRecordInfo do
        if MyGuildManager.allGuildHelpRecordInfo[i].helperuid == PlayerManager.uid or MyGuildManager.allGuildHelpRecordInfo[i].targetuid == PlayerManager.uid then
            table.insert(curallAidData[1],MyGuildManager.allGuildHelpRecordInfo[i])
        else
            table.insert(curallAidData[2],MyGuildManager.allGuildHelpRecordInfo[i])
        end
    end
    local isShowEmptyObj = true
    for i = 1, #curallAidData do
        if curallAidData[i] and  #curallAidData[i] > 0 then
            for k = 1, #titleText[i] do
                titleText[i][k]:SetActive(false)
            end
            for j = 1, #curallAidData[i] do
                if titleText[i][j] then
                    titleText[i][j]:GetComponent("Text").text = this.GetSingleStrInfo(curallAidData[i][j])
                    Util.GetGameObject(titleText[i][j], "Image/Text"):GetComponent("Text").text = "["..this.TimeStampToDateString(curallAidData[i][j].time).."]"
                else
                    local go=newObject(titleText[i][1])
                    go.transform:SetParent(Util.GetGameObject(recordPerList[i], "Mask").transform)
                    go.transform.localScale = Vector3.one
                    go.transform.localPosition = Vector3.zero
                    titleText[i][j] = go
                    titleText[i][j]:GetComponent("Text").text = this.GetSingleStrInfo(curallAidData[i][j])
                    Util.GetGameObject(titleText[i][j], "Image/Text"):GetComponent("Text").text = "["..this.TimeStampToDateString(curallAidData[i][j].time).."]"
                end
                titleText[i][j]:SetActive(true)
                --Util.AddOnceClick(titleText[i][j], function()
                --    UIManager.OpenPanel(UIName.PlayerInfoPopup, curallAidData[i][j].uid)
                --end)
            end
            isShowEmptyObj = false
            recordPerList[i]:SetActive(true)
        else
            recordPerList[i]:SetActive(false)
        end
    end
    this.emptyObj:SetActive(isShowEmptyObj)
end
function this.GetSingleStrInfo(curallAidData)
    local str = ""
    if curallAidData.helperuid == PlayerManager.uid then
        str = string.format(errorCodeHint[118].Desc,curallAidData.targetname,GetLanguageStrById(itemConfig[curallAidData.type].Name),"1")
    elseif curallAidData.targetuid == PlayerManager.uid then
        str = string.format(errorCodeHint[119].Desc,curallAidData.helpername,GetLanguageStrById(itemConfig[curallAidData.type].Name),"1")
    else
        str = string.format(errorCodeHint[122].Desc,curallAidData.helpername,curallAidData.targetname,GetLanguageStrById(itemConfig[curallAidData.type].Name),"1")
    end
    return str
end
function this.TimeStampToDateString(second)
    return  os.date("%H:%M:%S", second)
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this