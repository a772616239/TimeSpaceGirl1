require("Base/BasePanel")
require "Message/msgCommon_pb";
local MsgParser = require("BadWords/MsgParser")

WidelyCallPanel = Inherit(BasePanel)
local this = WidelyCallPanel
--初始化组件（用于子类重写）
function this:InitComponent()

    local transform = self.transform;
    this.PulicBtns = Util.GetGameObject(transform,"PulicBtns");
    this.CloseBtn = Util.GetGameObject(transform,"CloseBtn");
    this.SendMessageBtn = Util.GetGameObject(this.PulicBtns,"SendMessageBtn");
    this.gridParent = Util.GetGameObject(transform,"Grid").transform;
    this.input = Util.GetGameObject(transform,'input');
    this.ItemObj=Util.GetGameObject(this.gridParent,'NewsItem01');
    this._text = Util.GetGameObject(this.ItemObj,'Text'):GetComponent('Text')
    this._text.text=''
end

--绑定事件（用于子类重写）
function this:BindEvent()

    Util.AddClick(WidelyCallPanel.CloseBtn, this.OnCloseButtonClick);
    Util.AddClick(WidelyCallPanel.SendMessageBtn, this.SendMessagerequset);
end

--添加事件监听（用于子类重写）
function this:AddListener()

    Network.RegisterMessage(MSGID_Server2Client.MSG_SC_BROADCAST, this.ResWidelyCallInfo);
end

--移除事件监听（用于子类重写）
function this:RemoveListener()

    Network.UnRegisterMessage(MSGID_Server2Client.MSG_SC_BROADCAST, this.ResWidelyCallInfo);
end
function this:OnShow()
end
--界面打开时调用（用于子类重写）
function this:OnOpen(...)

end

--界面关闭时调用（用于子类重写）
function this:OnClose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end

--释放掉该面板--
function this.CheckAbleSendMessage()
    --[[
    local sprite =nil;
    if player.diamond~=nil and player.diamond >=50000 then
        sprite = Util.LoadSprite("Button_01", "Normal_asset");
    else
        sprite = Util.LoadSprite("Button_03", "Normal_asset");
    end
    this.SendMessageBtnbg.sprite = sprite;
    --]]
end

-- @param strurl  待解取字符串；
--        strchar 指定字符串
-- @return 截取后的字符串
-- end --
function this.getUrlFileName(strurl,strchar)

    local param1, param2 = string.find(strurl, strchar)
    local m = string.len(strurl) - param2 + 1
    print(m..'-------------------------m')
    local result
    result = string.sub(strurl, param2+1+8, string.len(strurl))
    --  result = string.sub(strurl, param2+1, string.len(strurl))
    return result
end

function this.ResWidelyCallInfo(buffer)

    local player = PlayerManager.player;

    --local textddd=this.getUrlFileName('fgrethgtruytue$dddqq3wedddrdfdsf657|57867856','|')
    --  print(textddd .."---textddd")
    local data=buffer:DataByte();
    local callInfo=msgCommon_pb.BroadCastSC();
    callInfo:ParseFromString(data);


    if this._text.text=='' then
        if callInfo.name=='系统' then  --FFFFFF00
            this._text.text='<color=#EE1C00>['..'系统'..']</color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'
        elseif callInfo.name==player.name then
            this._text.text='<color=#15FF1CFF>['..player.name..']  </color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'
        else
            this._text.text='<color=#2FFFEDFF>['..callInfo.name..']  </color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'
        end

    else
        if callInfo.name=='系统' then
            this._text.text=this._text.text..'\r\n'..'<color=#EE1C00>['..'系统'..']</color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'

        elseif callInfo.name==player.name then
            this._text.text=this._text.text..'\r\n'..'<color=#15FF1CFF>['..player.name..']</color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'
        else
            this._text.text=this._text.text..'\r\n'..'<color=#2FFFEDFF>['..callInfo.name..']</color>'..callInfo.content..'<color=#FFFFFF00>'..'|'..'</color>'
        end

    end
    if   this._text.preferredHeight>3450 then--3450
        --local textd= string.sub(this._text.text,90,string.len(this._text.text))
        local textddd=this.getUrlFileName(this._text.text,'|')
        print(textddd .."---textddd")

        this._text.text=textddd
    end
    if this._text.preferredHeight>282 then
        this.gridParent.localPosition=Vector3(271.74,(this._text.preferredHeight - 282), 1);
    end
    if this.ItemObj.activeSelf==false then
        this.ItemObj:SetActive(true)
    end
end


--初始化面板--
function this.InitPanel(objs)
    --[[
        local count = 100;
        local parent = WidelyCallPanel.gridParent;
        for i = 1, count do
            local go = newObject(objs[0]);
            go.name = 'Item'..tostring(i);
            go.transform:SetParent(parent);
            go.transform.localScale = Vector3.one;
            go.transform.localPosition = Vector3.zero;
            WidelyCall:AddClick(go, this.OnItemClick);

            local label = go.transform:Find('Text');
            label:GetComponent('Text').text = tostring(i);
        end
        ]]
end

--发送广播消息--
function this.SendMessagerequset(go)
    local player = PlayerManager.player;
    -- 系统颜色码dcc83e
    if player.diamond~=nil and player.diamond >=50000 then
        this.reqSendWidelyCall()
    else
        MsgPanel.ShowOne(GetLanguageStrById(11356))
    end
    ShareSoundConfig.PlayClickButtonSound()
end

--发送广播
function this.reqSendWidelyCall()
    local  _test= this.input.transform:Find('Text'):GetComponent('Text').text
    local s = MsgParser:getString(_test)
    print(s)

    if _test~=''  then
        local ReqSend = msgCommon_pb.SendBroadCastCS();
        ReqSend.content=s
        local msg = ReqSend:SerializeToString();
        Network.SendMessage(MSGID_Clinet2Server.MSG_CS_SEND_BROADCAST,msg);
    else
        print('输入为空....')
    end
end
--[[  36
282  0
318   36
354   72
390   108
426   144


]]


--单击事件--
function this.OnCloseButtonClick(go)
    this:ClosePanel();
    ShareSoundConfig.PlayClickButtonSound()
end


return WidelyCallPanel