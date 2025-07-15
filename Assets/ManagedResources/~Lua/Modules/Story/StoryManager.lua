-- 剧情管理类， 包含副本以及关卡剧情
StoryManager = {};
local this = StoryManager
local chapterDataConfig = ConfigManager.GetConfig(ConfigName.ChapterEventPointConfig)
local chapterOptionData = ConfigManager.GetConfig(ConfigName.ChapterOptionConfig)
local chapterTitleData = ConfigManager.GetConfig(ConfigName.LevelSetting)
local dialogueSetData = ConfigManager.GetConfig(ConfigName.DialogueViewConfig)
local artResConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local testFightRound=2


-- 当前对话的大关卡ID
this.curAreaID = 0
local lastResName
local lastLive2d
--- 男主立绘
this.boyRes = "live2d_npc_boy"

--- 女主立绘
this.bitchRes = "live2d_npc_girl" 


function this.Initialize()

end

-- 根据剧情传入的事件ID打开对应的对话面板
function this.EventTrigger(eventId, callBack)
    MyPCall(function()
        if not eventId then

            return
        end
        
        local showType = chapterDataConfig[eventId].ShowType
        local showValues = GetLanguageStrById(chapterDataConfig[eventId].ShowValues)
        local options = chapterDataConfig[eventId].Option

        if showType and showValues and options then
            -- 如果是第一次打开，则打开开幕界面
            if showType == 11 or showType==16 then -- 对话界面
                if callBack then 
                    UIManager.OpenPanel(UIName.StoryDialoguePanel, eventId, false, callBack)
                else
                    UIManager.OpenPanel(UIName.StoryDialoguePanel, eventId, false)
                end
            elseif showType == 12 then -- 选择界面
                UIManager.OpenPanel(UIName.StoryDialoguePanel, eventId, false)
                --UIManager.OpenPanel(UIName.StoryOptionPopup, eventId)
            elseif  showType == 10 then -- 起名字界面
                UIManager.OpenPanel(UIName.CreateNamePopup, showType, eventId, showValues, options)
            elseif showType == 14 then -- 引导战斗
                -- local fdata, fseed = BattleManager.GetFakeBattleData(1017)
                -- local testFightData = {
                --     fightData = fdata,
                --     fightSeed = fseed,
                --     fightType = 0,
                --     maxRound = 20
                -- }
                -- local panel = UIManager.OpenPanel(UIName.GuideBattlePanel, testFightData, function()
                --     StoryManager.EventTrigger(100004)
                -- end, BattleGuideType.FakeBattle)

                local fb = ConfigManager.GetConfigData(ConfigName.FakeBattleNew, 1017)
                local testFightData = BattleManager.GetBattleServerDataEVE(fb.OwnId,fb.EnnemiId)
                testFightData.maxRound=testFightRound
                UIManager.OpenPanel(UIName.GuideBattlePanel, testFightData, function()
                    --   StoryManager.EventTrigger(300007)
                     end, BattleGuideType.FakeBattle)
            end
        else

        end
    end)
end

--- 对话剧情触发
function this.DialogueTrigger(eventId, callback)
    MyPCall(function()
        if not eventId then

            return
        end

        local showType = chapterDataConfig[eventId].ShowType
    
        --- 对话弹窗
        if showType == 13 then 
            if callback then 
                UIManager.OpenPanel(UIName.DialoguePopup, eventId, callback)
            else
                UIManager.OpenPanel(UIName.DialoguePopup, eventId)
            end
        end
    end)
end

-- 剧情跳转
function this.StoryJumpType(optionId, panel)
   
    local jumpType = chapterOptionData[optionId].JumpType


    if jumpType then
        if jumpType == 4 then  -- 关闭所有界面，结束对话
            panel:ClosePanel()
            if UIManager.IsOpen(UIName.StoryDialoguePanel) then
                UIManager.ClosePanel(UIName.StoryDialoguePanel)
            end
        elseif jumpType == 5 then
            -- 打开主城
            PatFaceManager.isLogin = true
            UIManager.OpenPanelAsync(UIName.MainPanel, function ()
                UIManager.OpenPanel(UIName.FightPointPassMainPanel)
                LoadingPanel.End()
            end)            

            -- 关闭剧情
            if panel then
                panel:ClosePanel()
            end
            if UIManager.IsOpen(UIName.StoryDialoguePanel) then
                UIManager.ClosePanel(UIName.StoryDialoguePanel)
            end
        elseif jumpType == 1 then -- 继续对话，往下跳转
            local nextEventId = chapterOptionData[optionId].JumpTypeValues
            local nextEventShowType = chapterDataConfig[nextEventId].ShowType
            if nextEventShowType ~= 13 then
                this.EventTrigger(nextEventId, false)
            else
              
                this.DialogueTrigger(nextEventId)
            end
        end
    end
end


-- 返回当前关卡的标题
function this.GetTitle()
    local str = ""
    str = chapterTitleData[this.curAreaID].Title
    return str
end
-- ============================= 人物对话控制 =================================== --
-- 加载人物立绘并设置初始状态, 是否需要加载一次立绘
function this.InitLive2dState(setId, resPath, live2dRoot, effectRoot, isNeedLoad, dialoguePanel)
    -- 没有配置数据，直接返回
    local setData = dialogueSetData[setId]
    if not setData then return end

    this.SetLive2dState(setData, isNeedLoad, resPath, live2dRoot, effectRoot, dialoguePanel)
end

-- 设置立绘的大小位置，入场动画以及是否抖动
function this.SetLive2dState(setData, isNeedLoad, resPath, live2dRoot, effectRoot, dialoguePanel)
    -- 加载立绘之前清空
    ClearChild(live2dRoot)
    -- 立绘的位置大小
    -- local scale = 0
    -- local position = Vector3.New(0,0,0)
    -- scale = setData.Scale
    -- position =  Vector3(setData.Position[1], setData.Position[2], 0)

    -- if resPath == this.bitchRes then 
    --     position = Vector3.New(0, -250, 0)  
    --     scale = 0.5
    -- end

    -- 设置立绘最终大小位置
    local go
    if not resPath or resPath == "" then 
        return 
    end
    go = this.LoadHeroStaticLive(resPath, live2dRoot)
    if not go then 
        return  
    end
    lastLive2d = go
    

    -- 是否播放入场动画
    local isPlay = true
    if isNeedLoad  then
        isPlay = setData.isSkipShow == 1
        local shakeTime = setData.ShakeTime
        local shakeDis = setData.ShakeScale
        local isNeedShake = setData.IsShake == 1
        local ainIndex = setData.Animation

        --this.InitAnim(go)

        if isPlay and isNeedShake then  -- 震动，入场动画
            PlayUIAnim(live2dRoot, function ()
                this.SetShake(go, shakeTime, shakeDis[1], shakeDis[2], function ()
                    this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

                end)
            end)
        elseif isPlay and not isNeedShake then -- 入场动画无震动
            PlayUIAnim(live2dRoot, function ()
                this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

            end)
        elseif not isPlay and isNeedShake then -- 震动无入场动画
            this.SetShake(go, shakeTime, shakeDis[1], shakeDis[2], function ()
                this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

            end)
        elseif not isPlay and not isNeedShake then -- 都没有
            this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

        end
    end
end
function this.InitLive2dState2(setId, resPath, live2dRoot, effectRoot, isNeedLoad, dialoguePanel,moveStart,moveEnd,times,isNeedShake,inagefun,scaleAni)
    -- 没有配置数据，直接返回
    local setData = dialogueSetData[setId]

    -- if not setData then return end

    this.SetLive2dState2(setData, isNeedLoad, resPath, live2dRoot, effectRoot, dialoguePanel,moveStart,moveEnd,times,isNeedShake,inagefun,scaleAni)
end
-- 设置立绘的大小位置，入场动画以及是否抖动
function this.SetLive2dState2(setData, isNeedLoad, resPath, live2dRoot, effectRoot, dialoguePanel,moveStart,moveEnd,times,isNeedShake,inagefun,scaleAni)
    -- 加载立绘之前清空
    ClearChild(live2dRoot)
    -- 立绘的位置大小
    -- local scale = 0
    -- local position = Vector3.New(0,0,0)
    -- scale = setData.Scale
    -- position =  Vector3(setData.Position[1], setData.Position[2], 0)

    -- if resPath == this.bitchRes then 
    --     position = Vector3.New(0, -250, 0)  
    --     scale = 0.5
    -- end

    -- 设置立绘最终大小位置
    local go
    if not resPath or resPath == "" then Log(GetLanguageStrById(11973)) return end
    go = this.LoadHeroStaticLive(resPath, live2dRoot)
    if not go then Log(GetLanguageStrById(11974)) return  end
    lastLive2d = go
    -- 是否播放入场动画
    local isPlay = true
    if isNeedLoad  then
        -- isPlay = setData.isSkipShow == 1
        -- local shakeTime = setData.ShakeTime
        -- local shakeDis = setData.ShakeScale
        -- local isNeedShake = setData.IsShake == 1
        -- local ainIndex = setData.Animation
        local ainIndex = 0

        --this.InitAnim(go)

        if isPlay and isNeedShake then  -- 震动，入场动画
            this.PlayAnimRootMove(live2dRoot,dialoguePanel, function ()
                this.SetShake(go, nil, nil, nil, function ()
                    this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

                end)
            end,moveStart,moveEnd,times,scaleAni)
        elseif isPlay and not isNeedShake then -- 入场动画无震动
            this.PlayAnimRootMove(live2dRoot,dialoguePanel, function ()
                this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

            end,moveStart,moveEnd,times,scaleAni)
        elseif not isPlay and isNeedShake then -- 震动无入场动画
            this.SetShake(go, nil, nil, nil, function ()
                this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

            end)
        elseif not isPlay and not isNeedShake then -- 都没有
            this.SetLive2dAnim(go, ainIndex, 0, setData, effectRoot, dialoguePanel)

        end
        if inagefun then
            inagefun(go)
        end
    end
end
function this.PlayAnimRootMove(liveRoot,dialoguePanel,fun,moveStart,moveEnd,times,scaleAni)
    liveRoot.transform.localPosition=moveStart.transform.localPosition
    liveRoot.transform:DOLocalMove(moveEnd.transform.localPosition,times):OnComplete(function()
        if fun then
            fun()
        end
    end)
end

-- 设置图片以及表现
function this.InitImgState(setId, imgRoot, effectRoot)
    -- 没有配置数据，直接返回
    local setData = dialogueSetData[setId]
    if not setData then return end

    -- 设置需要显示的图片
    local imgShowData = string.split(setData.isShowImage, "#")
    local imgResId = tonumber(imgShowData[1])
    local imgName = imgShowData[2]
   
    local showImg = imgResId == 1
    if not showImg then return end

    local img = imgRoot:GetComponent("Image")
    img.sprite = Util.LoadSprite(imgName)
    img:SetNativeSize()

    -- 设置图片大小位置
    local scale = setData.imgSizeAndPos[1]
    local position = Vector2.New(setData.imgSizeAndPos[2], setData.imgSizeAndPos[3])
    imgRoot:GetComponent("RectTransform").anchoredPosition = position
    imgRoot.transform.localScale = Vector3.one * scale
end

-- 清除特效
function this.InitEffect(effectRoot)
    if lastResName then
        if effectRoot then
            ClearChild(effectRoot)
        end
        lastResName = nil
    end
end

function this.LoadHeroStaticLive(resPath, live2dRoot)
    local roleStaticImg = poolManager:LoadAsset("StoryImg", PoolManager.AssetType.GameObject)
    roleStaticImg.transform:SetParent(live2dRoot.transform)
    roleStaticImg.transform.localScale = Vector3.one * 1
    roleStaticImg.transform.localPosition = Vector3.zero
    roleStaticImg.name = "StoryImg"
    
    roleStaticImg:GetComponent("Image").sprite = Util.LoadSprite(resPath)
    roleStaticImg:GetComponent("Image").raycastTarget = false

    return roleStaticImg
end

--============================= 封装表现方法 =========================
-- 播放特效方法
local preLayer = 10
function this.PlayEffect(setData, effectRoot, dialoguePanel)
    local effectData = string.split(setData.isPlayEffect, "#")
    local isPlay = tonumber(effectData[1])
    if isPlay == 1 then
        local resName = effectData[2]
        lastResName = resName
        local effect = this.LoadEffect(effectRoot, resName)
        --设置特效的位置方向
        local pos = Vector2.New(setData.effectPos[2], setData.effectPos[3])


        -- 黑人问号特殊处理
        local dir = setData.effectPos[1] == 1 and 180 or 0
        if resName == "UI_effect_emoji_3" then
            effect.transform.localRotation = Vector4.New(0, 0, 0, 1)
            local img = Util.GetGameObject(effect, "kuang")
            img.transform.localRotation = Vector4.New(0, dir, 0, 1)
        else
          
            effect.transform.localRotation = Vector4.New(0, dir, 0, 1)
        end
		 effect:GetComponent("RectTransform").anchoredPosition = pos

        -- 设置特效层级
        Util.AddParticleSortLayer(effectRoot, dialoguePanel.sortingOrder + preLayer)
        preLayer = dialoguePanel.sortingOrder
    end
end

-- 参数:object 抖动物体  timeScale 震动时长 dx, dy震动偏移量
function this.SetShake(object, timeScale, dx, dy, callBack)
    if not timeScale or timeScale == 0 then
        timeScale = 0.3
    end
    if not dx or not dy or dy == 0 and dx == 0 then
        dx = 10
        dy = 10
    end
    object:GetComponent("RectTransform"):DOShakeAnchorPos(timeScale, Vector2.New(dx, dy),
                        500, 90, true, true):OnComplete(function ()
        if callBack then callBack() end
    end)
end


-- 设置立绘动作
function this.SetLive2dAnim(object, ainIndex, delayTime, setData, effectRoot, dialoguePanel)
    -- 木有立绘资源
    if not object or not object.gameObject then return end
    -- local skeletonAnim = object.gameObject:GetComponent("SkeletonGraphic")
    -- if not skeletonAnim then return end
    -- local animName = {
    --     [1] = "idle",
    --     [2] = "hit",
    --     [3] = "attack",
    --     [4] = "touch",
    -- }
    -- if not delayTime then delayTime = 0 end
    -- if not  skeletonAnim then return end

    -- if animName[ainIndex] and ainIndex > 1 then -- idel状态不做处理
    --     skeletonAnim.AnimationState:SetAnimation(delayTime, animName[ainIndex], false)
    -- end

    -- 播放特效
    this.PlayEffect(setData, effectRoot, dialoguePanel)
end

-- 设置立绘初始化动作
function this.InitAnim(go)
    if not go then return end
    local skeletonAnim = go:GetComponent("SkeletonGraphic")
    local InitAnim = function() skeletonAnim.AnimationState:SetAnimation(0, "idle", true) end
    skeletonAnim.AnimationState.Complete = skeletonAnim.AnimationState.Complete + InitAnim
end

-- 加载特效
function this.LoadEffect(effectParent, resName)
    local go = poolManager:LoadAsset(resName, PoolManager.AssetType.GameObject)
    go.transform:SetParent(effectParent.transform)
    go.transform.localScale = Vector3.one
    go.transform.position = effectParent.transform.position
    go:SetActive(true)
    return go
end

-- 卸载特效
function this.UnLoadEffect(resName, res)
    poolManager:UnLoadAsset(resName, res, PoolManager.AssetType.GameObject)
end

return this










