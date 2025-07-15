MailManager = {};
local this = MailManager
this.mialDataList = {}

function this.Initialize()

end

function this.InitMailDataList(_mialList)
    this.mialDataList = {}
    for i = 1, #_mialList do
        this.UpdateMialData(_mialList[i])
    end

    table.sort(this.mialDataList, function(a, b)
        if a.state == b.state then
            return a.sendTime > b.sendTime
        else
            return a.state < b.state
        end
    end)
end

function this.UpdateMialData(_mial)
    local singleMail = {}

    singleMail.mailId = _mial.mailId--
    singleMail.state = _mial.state--0:未读 1:已读取 2: 未领取 3 已领取
    singleMail.head = _mial.head--标题
    singleMail.content = _mial.content--详情
    singleMail.mailItem = _mial.mailItem--附件 奖励
    singleMail.sendTime = _mial.sendTime--
    singleMail.effectiveTime = _mial.effectiveTime--秒 0:永久有效
    singleMail.sendName = _mial.sendName--发送者名字
    singleMail.mailType = _mial.mailType--邮件类型 1:系统邮件 2:idip 业务邮件
    singleMail.mailparam= _mial.mailparam  --邮件内容
    singleMail.mailtitleparam = _mial.mailtitleparam   --邮件内容
    table.insert(this.mialDataList, singleMail)
end

--更新邮件状态
function this.UpdataMialIsReadState(_mailId, _state)
    for i = 1, #this.mialDataList do
        if this.mialDataList[i].mailId == _mailId then
            this.mialDataList[i].state = _state
            break
        end
    end
    CheckRedPointStatus(RedPointType.Mail_Local)
end
--删除邮件状态
function this.DelSingleMial(_mailId)
    local curmialDataList = {}
    for i = 1, #this.mialDataList do
        table.insert(curmialDataList,this.mialDataList[i])
    end
    for i = 1, #curmialDataList do
        if curmialDataList[i].mailId == _mailId then
            curmialDataList[i] = nil
        end
    end
    this.mialDataList = {}
    for i, v in pairs(curmialDataList) do
        this.mialDataList[#this.mialDataList+1] = v
    end
    --CheckRedPointStatus(RedPointType.Mail_Local)
end
--检测邮件红点
function this.GetMailRedPointState()
    local isShowRedPoint = false
    for i = 1, #this.mialDataList do
        if this.mialDataList[i].state == 0 then
            isShowRedPoint = true
            break
        end
    end
    -- 无红点可显示，重置服务器邮件红点
    if not isShowRedPoint then
        ResetServerRedPointStatus(RedPointType.Mail_Server)
    end
    return isShowRedPoint
end

return this