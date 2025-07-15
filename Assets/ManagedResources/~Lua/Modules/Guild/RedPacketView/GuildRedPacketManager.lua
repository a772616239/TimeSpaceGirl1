GuildRedPacketManager = {}
local this = GuildRedPacketManager

-- 默认未检查公会红包
this.isCheck=false

function this.Initialize()

end

-- 检查公会红包红点
function this.CheckGuildRedPacketRedPoint()
    
    if this.isCheck then
        return this.isCheck
    else
        return false
    end
end

return this