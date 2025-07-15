local GuideBattleLogic = {}

-- 引导节点配置
local _GuideConfig = {
    -- 轮数 = {阵营（0左1右 = { 释放位置 = 对话id}}}    新手引导假战斗
    [BattleGuideType.FakeBattle] = {
        [-1] = {
             [0] = {},    -- 战斗开始时
            [1] = 500070,   -- 战斗结束时
        },
        [1] = {
            [0] = {
                    [2] = 500010,    ----雅典娜
                },
            [1] = {
                    [5] = 500020,    ----织田信长
                },
        },
        [2] = {
            [0] = {
					[2] = 500025,    ---雅典娜
					[7] = 500030,    ----南丁
					[9] = 500050,    ----赵云
					[6] = 500060,      ----唐吉坷德
                },
            [1] = {
					[1] = 500040,      ----布鲁图斯
                },
        },
        [3] = {
            [0] = {
               
                },
            [1] = {
                  
                },
        },
    },
    [BattleGuideType.QuickFight] = {
        -- 轮数 = {阵营 = { 释放位置 = 引导id}}}
        [1] = {
            [0] = {
                    [1] = 200000,
                }
            },
    }
}
function GuideBattleLogic:Init(guideType)
    self.guideType = guideType
end


function GuideBattleLogic:RoleTurnChange(curRound, role)
    local curCamp = role.camp
    local curPos = role.position
    local _config = _GuideConfig[self.guideType]
    if not _config 
    or not _config[curRound]
    or not _config[curRound][curCamp]
    or not _config[curRound][curCamp][curPos]
    then
        return 
    end
    -- 对话形式的引导
    if self.guideType == BattleGuideType.FakeBattle then
        BattleManager.SetGuidePause(true)
        local storyId = _config[curRound][curCamp][curPos]
        StoryManager.EventTrigger(storyId, function()            
            BattleManager.SetGuidePause(false)
        end)
    -- 引导形式的引导
    elseif self.guideType == BattleGuideType.QuickFight then
        BattleManager.SetGuidePause(true)
        local guideId = _config[curRound][curCamp][curPos]
        GuideManager.ShowGuide(guideId)
        local function _onGuideDone()
            Game.GlobalEvent:RemoveEvent(GameEvent.Guide.BattleGuideDone, _onGuideDone)
            BattleManager.SetGuidePause(false)
        end
        Game.GlobalEvent:AddEvent(GameEvent.Guide.BattleGuideDone, _onGuideDone)
    end
end

function GuideBattleLogic:OnBattleEnd(func)
    local _config = _GuideConfig[self.guideType]
    if not _config 
    or not _config[-1]
    or not _config[-1][1] then
        if func then
            func()
        end
        return
    end
    -- 对话形式的引导
    if self.guideType == BattleGuideType.FakeBattle then
        UIManager.OpenPanel(UIName.BackGroundInfoPanel,GetLanguageStrById(22721),function()        
            BattleManager.SetGuidePause(true)
            local storyId = _config[-1][1]
            StoryManager.EventTrigger(storyId, function()
                BattleManager.SetGuidePause(false)
                if func then 
                    func()
                end
            end)
        end)                 
    end
end

return GuideBattleLogic