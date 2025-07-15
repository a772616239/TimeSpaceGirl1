require("Base/BasePanel")
DialoguePopup = Inherit(BasePanel)
local this = DialoguePopup

--- 角色所在位置0 --> 左边 1 --> 右边
local roleDir = 0
local opId = 0
local static_callBack
local chapterDataConfig = ConfigManager.GetConfig(ConfigName.ChapterEventPointConfig)
local chapterOptionData = ConfigManager.GetConfig(ConfigName.ChapterOptionConfig)
local artConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)


--初始化组件（用于子类重写）
function DialoguePopup:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "mask")
    this.dialogueRoot = Util.GetGameObject(self.gameObject, "dialog")
    this.talkText = Util.GetGameObject(this.dialogueRoot, "Text"):GetComponent("Text")
    this.roleIcon = Util.GetGameObject(this.dialogueRoot, "role"):GetComponent("Image")
end

--绑定事件（用于子类重写）
function DialoguePopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        -- 是否是最后一段对话
        local isEnd = chapterOptionData[opId].JumpType == 5
        if isEnd then 
            if static_callBack then 
                static_callBack() 
                static_callBack = nil
                self:ClosePanel()
            end
        else  -- 继续对话
            StoryManager.StoryJumpType(opId, this)
        end
    end)

end

--添加事件监听（用于子类重写）
function DialoguePopup:AddListener()

end

--移除事件监听（用于子类重写）
function DialoguePopup:RemoveListener()

end

function DialoguePopup:OnOpen(Id, func)
    if func then 
        static_callBack = func
    end

    if not Id or Id == 0 then 

        return 
    end

    local showType = chapterDataConfig[Id].ShowType
    local showValues = GetLanguageStrById(chapterDataConfig[Id].ShowValues)
    opId = chapterDataConfig[Id].Option[1]

    local contents = string.split(showValues, "|")
    

    ---设置对话内容s
    this.talkText.text = contents[2]
    local resId = tonumber(contents[1])

    -- 配音资源名
    local voice = chapterDataConfig[Id].VoiceRes
    if voice then
        -- 使用相同通道播放，避免跳过剧情导致音效重复
        SoundManager.PlaySound(voice, nil, nil, 10)
    end

    --- 设置表现形式
    if not artConfig[resId] then 

        return;
    end
    local resName = artConfig[resId].Name

    this.roleIcon.sprite = Util.LoadSprite(resName)
  
end

--界面打开时调用（用于子类重写）
function DialoguePopup:OnShow(...)

end

function DialoguePopup:OnSortingOrderChange()

end

--界面关闭时调用（用于子类重写）
function DialoguePopup:OnClose()
    -- 界面关闭，配音音效关闭
    SoundManager.StopSoundByChannel(10)
end

--界面销毁时调用（用于子类重写）
function DialoguePopup:OnDestroy()

end

return DialoguePopup