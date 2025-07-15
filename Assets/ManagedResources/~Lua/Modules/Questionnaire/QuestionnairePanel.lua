--[[
 * @ClassName QuestionnairePanel
 * @Description 调查问卷面板
 * @Date 2019/9/3 15:42
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local QuestionnaireListItem = require("Modules/Questionnaire/QuestionnaireListItem")
---@class QuestionnairePanel
local QuestionnairePanel = quick_class("QuestionnairePanel", BasePanel)

function QuestionnairePanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame/bg/closeBtn")

    self.questionContent = Util.GetGameObject(self.transform, "frame/bg/questionList/viewPort/content")
                               :GetComponent("RectTransform")
    self.questionPre = Util.GetGameObject(self.questionContent.transform, "questionPre")
    self.questionPre:SetActive(false)
    self.questionList = {}

    self.bottomPart = Util.GetGameObject(self.transform, "frame/bg/questionList/viewPort/content/bottomPart")
    --self.remainTime = Util.GetGameObject(self.bottomPart, "remainTime"):GetComponent("Text")
    self.commitBtn = Util.GetGameObject(self.bottomPart, "commitBtn")

end

function QuestionnairePanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.commitBtn, function()
        self:OnCommitBtnClicked()
    end)
end

function QuestionnairePanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Questionnaire.OnQuestionnaireChange, self.OnQuestionnaireCallBack, self)
end

function QuestionnairePanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Questionnaire.OnQuestionnaireChange, self.OnQuestionnaireCallBack, self)
end

function QuestionnairePanel:OnOpen(context)
    self.context = context
    self.questionContent.anchoredPosition = Vector2(0, 0)
end

function QuestionnairePanel:OnShow()
    if self.context then
        self:RemainTimeDown(self.context.endtime - math.floor(GetTimeStamp()))
        self:SetQuestList()
    end
end

function QuestionnairePanel:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function QuestionnairePanel:OnCommitBtnClicked()
    local answerList, noAnswerIndex = {}, nil
    for idx, questionInfo in ipairs(self.questionList) do
        if questionInfo.answer ~= "" then
            table.insert(answerList, questionInfo.answer)
        else
            if questionInfo.answerType == 0 then
                noAnswerIndex = idx
                break
            end
        end
    end
    if noAnswerIndex then
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11685), noAnswerIndex))
        return
    end
    NetManager.RequestUpDataQuestion(answerList, function(respond)
        if respond.result == 0 then
            PopupTipPanel.ShowTipByLanguageId(11686)
            QuestionnaireManager.SetQuestionState(1)
            Game.GlobalEvent:DispatchEvent(GameEvent.Questionnaire.OnQuestionnaireChange, 1)
            self:ClosePanel()
        else
            PopupTipPanel.ShowTipByLanguageId(11687)
        end
    end)
end

function QuestionnairePanel:SetQuestList()
    if table.nums(self.questionList) > 0 then
        return
    end
    for i = 1, #self.context.questOptions do
        local item = QuestionnaireListItem.create(self.questionPre, self.questionContent.transform)
        item:SetValue(i, self.context.questOptions[i])
        table.insert(self.questionList, item)
    end
    self.bottomPart.transform:SetAsLastSibling()
end

function QuestionnairePanel:RemainTimeDown(timeDown)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    --self.remainTime.text = "活动结束倒计时：" .. DateUtils.GetTimeFormatV2(timeDown)
    if timeDown <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10029)
        self:SetQuestionnaireOver()
        self:ClosePanel()
        return
    end
    self.timer = Timer.New(function()
        --self.remainTime.text = "活动结束倒计时：" .. DateUtils.GetTimeFormatV2(timeDown)
        if timeDown <= 0 then
            self.timer:Stop()
            self.timer = nil
            self:SetQuestionnaireOver()
            self:ClosePanel()
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    self.timer:Start()
end

function QuestionnairePanel:SetQuestionnaireOver()
    QuestionnaireManager.ResetArgs()
    QuestionnaireManager.SetQuestionState(-1)
    Game.GlobalEvent:DispatchEvent(GameEvent.Questionnaire.OnQuestionnaireChange)
end

function QuestionnairePanel:OnQuestionnaireCallBack(state)
    if state == -1 then
        self:ClosePanel()
    end
end

return QuestionnairePanel