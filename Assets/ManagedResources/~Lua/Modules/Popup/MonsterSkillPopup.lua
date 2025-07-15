require("Base/BasePanel")
MonsterSkillPopup = Inherit(BasePanel)
local this = MonsterSkillPopup
--初始化组件（用于子类重写）
function MonsterSkillPopup:InitComponent()
    this.content = Util.GetGameObject(self.transform, "Content"):GetComponent("RectTransform")
    this.backBtn = Util.GetGameObject(self.transform, "Button")

    this.skillName = Util.GetGameObject(self.transform, "Content/CurLv/Title/Text"):GetComponent("Text")
    this.skillTypeIcon = Util.GetGameObject(self.transform, "Content/CurLv/Title/SkillTypeImage"):GetComponent("Image")
    this.skillContent = Util.GetGameObject(self.transform, "Content/CurLv/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function MonsterSkillPopup:BindEvent()
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function MonsterSkillPopup:AddListener()
end

--移除事件监听（用于子类重写）
function MonsterSkillPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
local SkillIconType = {"N1_iconbg_tongyong_baise", "N1_iconbg_tongyong_baise", "N1_iconbg_tongyong_baise"}
function MonsterSkillPopup:OnOpen(skillData)
    this.content.anchoredPosition = Vector2.New(0, 0)
    this.skillName.text = skillData.Name
    this.skillTypeIcon.sprite = Util.LoadSprite(SkillIconType[skillData.Type])
    this.skillContent.text = GetSkillConfigDesc(skillData)
end

--界面关闭时调用（用于子类重写）
function MonsterSkillPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function MonsterSkillPopup:OnDestroy()
end

return MonsterSkillPopup