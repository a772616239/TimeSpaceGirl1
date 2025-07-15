--[[
 * @ClassName BindPhoneNumberManager
 * @Description 手机绑定管理
 * @Date 2019/9/2 9:39
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
BindPhoneNumberManager = {}
local this = BindPhoneNumberManager
local json = require 'cjson'

local bindInfo = {}

local GetBindUrl = "http://act-api.37.com.cn/reserve/elvesSms/"
local pid = 1
local gid = 1006856
local signKey = "sliDPl39kdksAfa"
local token, bindType

BindType = {
    GetCode = 1,
    Confirm = 2
}

function this.Initialize()

end

--phoneNum,state:0未绑定1已绑定未领奖2已领奖
function this.InitBindInfo(context)
    bindInfo.phoneNum = context.phoneNum
    bindInfo.state = context.state
end

function this.GetBindInfo()
    return bindInfo
end

function this.SetBindNumber(number)
    bindInfo.phoneNum = number
end

function this.SetBindState(state)
    bindInfo.state = state
end

function this.GetFormatNumber()
    local str1 = string.sub(bindInfo.phoneNum, 1, 3)
    local str2 = "****"
    local str3 = string.sub(bindInfo.phoneNum, -4)
    return str1 .. str2 .. str3
end

function this.SetPtToken(_token)
    token = _token
end

function this.DOGetBindPhone(type, phoneNumber, code)
    bindType = type
    local time = math.floor(GetTimeStamp())
    local sign = Util.MD5Encrypt(string.format("%s%s%s%s%s%s", pid,
            gid, type, phoneNumber, time, signKey))
    local code = code and code or ""
    networkMgr:SendGetHttp(string.format("%s?pid=%s&gid=%s&token=%s&type=%s&phone=%s&code=%s&time=%s&sign=%s",
            GetBindUrl, pid, gid, token, type, phoneNumber, code, time, sign), this.OnCodeResult, nil, nil, nil)
end

function this.OnCodeResult(str)
    str = json.decode(str)
    if str.state == 1 then
        if bindType == BindType.GetCode then
            PopupTipPanel.ShowTipByLanguageId(10286)
        else
            PopupTipPanel.ShowTipByLanguageId(10287)
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.BindPhone.OnBindStatusChange)
    else
        PopupTipPanel.ShowTip(str.msg)
    end
end

return this