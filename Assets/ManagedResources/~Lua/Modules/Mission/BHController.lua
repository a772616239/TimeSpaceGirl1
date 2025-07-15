local BHController = {}
local this = BHController

--- 注册事件节点
this.BHNodeList = {
    Battle = require("Modules/Mission/Behaviour/BHBattle"),
    Buff = require("Modules/Mission/Behaviour/BHBuff"),
    DeletePoint = require("Modules/Mission/Behaviour/BHDeletePoint"),
    MapProgressChange = require("Modules/Mission/Behaviour/BHMapProgressChange"),
    MoveTo = require("Modules/Mission/Behaviour/BHMoveTo"),
    NewPoint = require("Modules/Mission/Behaviour/BHNewPoint"),
    ParseMission = require("Modules/Mission/Behaviour/BHParseMission"),
    ShowProgress = require("Modules/Mission/Behaviour/BHShowProgress"),
    ShowReward = require("Modules/Mission/Behaviour/BHShowReward"),
    SpendGoods = require("Modules/Mission/Behaviour/BHSpendGoods"),
}

--- 按数组顺序执行
function this.SeqExcuteNodeArray(nodeInfoList, func)
    -- 检测数组正确性
    if not nodeInfoList or #nodeInfoList == 0 then
        return
    end
    -- 递归执行节点，保证顺序执行
    local index = 1
    local function StartExcute(...)
        -- 获取节点id
        local BHNodeInfo = nodeInfoList[index]
        if BHNodeInfo then
            -- 下标后移，未下一次递归做准备
            index = index + 1
            -- 获取节点执行
            local option = BHNodeInfo[1]
            -- 判断是参数还是构建参数的方法
            local arg = BHNodeInfo[2]
            if type(arg) == "function" then
                arg = arg(...)
            end
            local BHNode = this.BHNodeList[option]
            if not BHNode then

                return
            end
            -- 单事件节点执行完成回调
            local function NodeDoneFunc(...)
                if BHNodeInfo[3] and type(BHNodeInfo[3]) == "function" then
                    BHNodeInfo[3](...)
                end
            end
            BHNode.Excute(arg, StartExcute, NodeDoneFunc)
        else
            -- 递归结束
            if func then func() end
        end
    end
    -- 开始执行
    StartExcute()
end



return this