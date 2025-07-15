--[[
 * @ClassName QuestionnaireManager
 * @Description 调查问卷管理类
 * @Date 2019/9/3 15:40
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
QuestionnaireManager = {}
local this = QuestionnaireManager

local QuestionnaireArgs = nil
local questionState

function this.Initialize()

end

function this.OpenQuestionnairePanel()
    if not QuestionnaireArgs then
        NetManager.RequestGetQuestionnaireArgs(function(respond)
            QuestionnaireArgs = respond
            UIManager.OpenPanel(UIName.QuestionnairePanel, QuestionnaireArgs)
        end)
    else
        UIManager.OpenPanel(UIName.QuestionnairePanel, QuestionnaireArgs)
    end
end

function this.ResetArgs()
    QuestionnaireArgs = nil
end

function this.RefreshQuestionData()
    NetManager.RequestGetQuestionnaireArgs(function(respond)
        QuestionnaireArgs = respond
    end)
end

--0未答题1已答题-1没有问卷
function this.SetQuestionState(_state)
    questionState = _state
end

function this.GetQuestionState()
    return questionState
end

return this