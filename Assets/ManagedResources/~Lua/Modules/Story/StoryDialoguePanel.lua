require("Base/BasePanel")
StoryDialoguePanel = Inherit(BasePanel)
local this = StoryDialoguePanel
local chapterEventPointData = ConfigManager.GetConfig(ConfigName.ChapterEventPointConfig)
local OpConfig = ConfigManager.GetConfig(ConfigName.ChapterOptionConfig)
local artResConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local lastLive2DId = ""
local jumpId = 0
local optionID = 0
--是否这个面板是第一次打开
local isFirstOpen = false
-- 记录场景特效
local preEffPar = 0
local lastSceneEffect
-- 设置场景特效
local orginLayer
local static_callBack
this.Rootlist={}
this.rootlistTr={}
this.rootlistTrDev={}
this.rootlistTrup={}
this.rootlistTrother={}

--当前等待剩余时间
this.waitResidueTime = 5
--当前文本是否显示完成
this.isShowTextEnd = false
--是否等待中
this.isWaiting = false


function StoryDialoguePanel:InitComponent()
    orginLayer = 10
    -- 背景图
    this.Bg = Util.GetGameObject(self.gameObject, "bg"):GetComponent("Image")
    -- 右切入
    this.right2dRoot = Util.GetGameObject(self.gameObject, "RootNpc/rightLive2d")
    this.rightLive2dTr=Util.GetGameObject(self.gameObject, "TrLocation/rightLive2dTr")
    this.rightLive2dTrDev=Util.GetGameObject(self.gameObject, "TrLocation/rightLive2dTrDev")
    this.rightLive2dTrup=Util.GetGameObject(self.gameObject, "TrLocation/rightLive2dTrup")
    this.rightLive2dTrother=Util.GetGameObject(self.gameObject, "TrLocation/rightLive2dTrother")
    -- 左切入
    this.left2dRoot = Util.GetGameObject(self.gameObject, "RootNpc/leftLive2d")
    this.leftLive2dTr=Util.GetGameObject(self.gameObject, "TrLocation/leftLive2dTr")
    this.leftLive2dTrDev=Util.GetGameObject(self.gameObject, "TrLocation/leftLive2dTrDev")
    this.leftLive2dTrup=Util.GetGameObject(self.gameObject, "TrLocation/leftLive2dTrup")
    this.leftLive2dTrother=Util.GetGameObject(self.gameObject, "TrLocation/leftLive2dTrother")
    this.Rootlist[1]=this.left2dRoot
    this.Rootlist[2]=this.right2dRoot
    this.rootlistTr[1]=this.leftLive2dTr
    this.rootlistTr[2]=this.rightLive2dTr
    this.rootlistTrDev[1]=this.leftLive2dTrDev
    this.rootlistTrDev[2]=this.rightLive2dTrDev
    this.rootlistTrup[1]=this.leftLive2dTrup
    this.rootlistTrup[2]=this.rightLive2dTrup
    this.rootlistTrother[1]=this.leftLive2dTrother
    this.rootlistTrother[2]=this.rightLive2dTrother
    -- 点击按钮
    this.btnNext = Util.GetGameObject(self.gameObject, "goOnButton/Click")
    this.btnRoot = Util.GetGameObject(self.gameObject, "goOnButton")

    --对话文字内容
    this.RoleName = Util.GetGameObject(self.gameObject, "TextMask/Name"):GetComponent("Text")
    this.NameFrame = Util.GetGameObject(self.gameObject, "TextMask/Image")
    this.Context = Util.GetGameObject(self.gameObject, "TextMask/context")
    this.timetext = Util.GetGameObject(self.gameObject, "TextMask/timetext"):GetComponent("Text")

    --跳过按钮
    this.btnJump = Util.GetGameObject(self.gameObject, "btnContinue/btnGo")
    this.jumpRoot = Util.GetGameObject(self.gameObject, "btnContinue")
    -- 黑幕遮罩
    this.mask = Util.GetGameObject(self.gameObject, "Mask")
    -- 中间乱入的图片
    this.showImg = Util.GetGameObject(self.gameObject, "showImg")

    -- 特效的节点
    this.effectRoot = Util.GetGameObject(self.gameObject, "effectRoot")
    -- 场景特效
    this.sceneEffect = Util.GetGameObject(self.gameObject, "scenceEffect")

    this.Image_Mask = Util.GetGameObject(self.gameObject, "Image_Mask")   
end



--绑定事件（用于子类重写）
function StoryDialoguePanel:BindEvent()
    Util.AddClick(this.btnNext, function ()
        this.NextStep()
    end)

    Util.AddClick(this.btnJump, function ()
        if jumpId == 0 then
            self:ClosePanel()

            if static_callBack then 
                static_callBack()
                static_callBack = nil
            end
        else
            StoryManager.StoryJumpType(jumpId, self)
        end
    end)
end

--添加事件监听（用于子类重写）
function StoryDialoguePanel:AddListener()

end

--移除事件监听（用于子类重写）
function StoryDialoguePanel:RemoveListener()

end


--界面打开时调用（用于子类重写）
function StoryDialoguePanel:OnOpen(...)
    local data = {...}
    if data then
        local eventId = data[1]

        --- 新手第一次对话
        if eventId == 138018 then 
            SoundManager.PlayMusic(SoundConfig.BGM_Adventure)
        end

        --- 新手战斗结束之后的第一次对话
        if eventId == 100001 then 
            SoundManager.PlayMusic(SoundConfig.BGM_Story_1)
        end


        this.isWaiting = true
        this.isShowTextEnd = false
        this.waitResidueTime = 5

        this.timetext.gameObject:SetActive(false)

        isFirstOpen = data[2]
        this.RefreshPanel(eventId, isFirstOpen)

        if data[3] then 
            static_callBack = data[3]
        end

    else

    end
end

function this:Update()
    if this.isShowTextEnd and this.isWaiting then
        if this.waitResidueTime > 0 then
            this.waitResidueTime = this.waitResidueTime - Time.fixedDeltaTime
            this.timetext.gameObject:SetActive(true)
            this.timetext.text = string.format(GetLanguageStrById(50158),math.modf(this.waitResidueTime))
        else
            this.NextStep()
        end
    end
end

function this.NextStep()
    if this.isWaiting then
        this.isWaiting = false
        this.timetext.gameObject:SetActive(false)

        local isEnd = OpConfig[optionID].JumpType == 4
        if isEnd and static_callBack then 
            static_callBack()
            static_callBack = nil
        end

        -- 点击下一步关闭配音音效关闭
        SoundManager.StopSoundByChannel(10)
        StoryManager.StoryJumpType(optionID, this)
    end
end

function this:OnSortingOrderChange()
    self.gameObject:GetComponent("Canvas").sortingOrder = 6010
end

-- 打开面板的时候刷新一次数据
function  this.RefreshPanel(eventId, isFirstOpen)
    local showType = chapterEventPointData[eventId].ShowType
    local  isRightType=false
    if showType == 11 or showType== 16 then
         isRightType=true
    end    
    this.RoleName.gameObject:SetActive(isRightType)
    this.btnNext:SetActive(isRightType)

    -- 新手隐藏阶段必须隐藏，其他时候随着面板变化
    if GuideManager.IsInMainGuide() then
        this.jumpRoot:SetActive(false)
    else
        this.jumpRoot:SetActive(isRightType)
    end

    local showValues = GetLanguageStrById(chapterEventPointData[eventId].ShowValues)
    local options = chapterEventPointData[eventId].Option

    local dir = chapterEventPointData[eventId].ShowDir
    local live2dRoot = dir == 2 and this.left2dRoot or this.right2dRoot

    local showMask = chapterEventPointData[eventId].Isdark == 1
    this.mask:SetActive(showMask)
        
    -- 设置对话背景图
    this.Bg.sprite = Util.LoadSprite(chapterEventPointData[eventId].DialogueBg)     
    if(showType==16)then
        DoTween.To(
        DG.Tweening.Core.DOGetter_UnityEngine_Color( function () return Color.New(1,1,1,0.5) end),
        DG.Tweening.Core.DOSetter_UnityEngine_Color(function (t)
           this.Bg.color=t
        end), 
        Color.New(1,1,1,1)
        , 2):SetEase(Ease.Linear):OnComplete(function ()
           
        end )
    else
             this.Bg.color=Color.New(1,1,1,1)
    end 
   
    StoryDialoguePanel:SetScenceEffect(eventId)

    -- 跳转值
    optionID = options[1]
    jumpId = chapterEventPointData[eventId].NextOptPanelId
    if jumpId and jumpId ~= 0 then
       jumpId = chapterEventPointData[jumpId].Option[1]
    else
        jumpId = 0
    end



    -- 角色信息
    local contents = string.split(showValues, "|")
    local resId = contents[1]

    -- 文字内容
    local contexts =(contents[2])
   
    --contexts = string.gsub(contexts, "【此处为玩家名】", PlayerManager.nickName)
    local lang= GetLanguageStrById(11220)
    if lang == "" or lang==nil then
        LogError("对话内容中有未替换的字段，请检查配置表 ChapterEventPointConfig.lua 中的 ShowValues 字段"..11220)
        return
    end
    if contexts == "" or contents==nil then
        LogError("对话内容为空，请检查配置表 ChapterEventPointConfig.lua 中的 ShowValues 字段")
        return
    end

    contexts = string.gsub(contexts,lang , NameManager.roleName)

    
    -- 配音资源名
    -- local voice = chapterEventPointData[eventId].VoiceRes
    -- if voice then
    --     -- 使用相同通道播放，避免跳过剧情导致音效重复
    --     SoundManager.PlaySound(voice, nil, nil, 10)
    -- end

    --当前不是选择界面
    if isRightType then
        this.Image_Mask:SetActive(true)   
        ShowText(this.Context, contexts, 3,function()
            this.Image_Mask:SetActive(false)   
            this.isShowTextEnd = true
        end)
        PlayUIAnim(this.gameObject)
        this.btnRoot:SetActive(true)
    else
        this.btnRoot:SetActive(false)
        this.NameFrame:SetActive(false)
        this.ReSetLive2d()
        this.Context:GetComponent("Text").text = contexts
        this.isShowTextEnd = true
    end

    if showMask then this.ReSetLive2d() this.RoleName.text = "" end
    if not isRightType then return end

    -- 又配置数据使用新的加载方法，不然使用原有的
    local setId = chapterEventPointData[eventId].DialogueViewId
    

    -- 显示立绘
    if resId ~="0" or resId =="1" then
       

        -- 初始化特效
        StoryManager.InitEffect(this.effectRoot)
        -- 如果面板是第一次打开
        if isFirstOpen then
            lastLive2DId = 0
        end

        local roleSex = NameManager.roleSex
        -- local resPath 
        -- if resId == 1 then  --- 主角专用字段
        --     resPath = roleSex == ROLE_SEX.BOY and artResConfig[1712].Name or artResConfig[1713].Name
        if resId=="1" then
            resId = PlayerManager.nickName
        end
        -- else
        --     resPath = artResConfig[resId].Name
        -- end

        -- local data = artResConfig[resId]
        if resId=="" then
            this.RoleName.text=""
        else
            this.RoleName.text =string.gsub(resId, GetLanguageStrById(11225), NameManager.roleName)
        end
        for i = 1, #dir, 1 do
            this.LoadAnim(setId[i], setId, this.Rootlist[i], this.effectRoot, true, dir[i],i)
		--	     LogError("DialogueViewId:"..setId[i]) 
				 
        end
        -- if lastLive2DId ~= resId then
        --     -- 需要加载立绘的时候清除所有
        --     this.ReSetLive2d()

            
    
        --     if setId and setId ~= 0 then
        --         StoryManager.InitLive2dState2(setId, resPath, live2dRoot, this.effectRoot, true, this)
        --     else
        --         this.LoadLive2D(data, resPath, live2dRoot)
        --     end
        -- else
        --     if setId then
        --         StoryManager.InitLive2dState2(setId, resPath, live2dRoot, this.effectRoot, false, this)
        --     end
        -- end
        if resId=="" then
            this.NameFrame:SetActive(false)
        else
            this.NameFrame:SetActive(true)
        end
        this.showImg:SetActive(false)
    elseif resId == "0" then -- 显示图片
        -- StoryManager.InitEffect(this.effectRoot)
        this.showImg:SetActive(false)
        this.ReSetLive2d()
        this.RoleName.text = ""
        this.NameFrame:SetActive(false)
        -- if setId then
        --     StoryManager.InitImgState(setId, this.showImg, this.effectRoot, this)
        -- end

    else
        StoryManager.InitEffect(this.effectRoot)
        this.showImg:SetActive(false)
        this.ReSetLive2d()
        this.RoleName.text = ""
        this.NameFrame:SetActive(false)
    end
    lastLive2DId = resId
end
function this.LoadAnim(setId, resPath, live2dRoot, effectRoot, rootbo, mode,index)

    local roleSex = NameManager.roleSex
    local newResPath
    local scale = 1
    local localPosition = Vector3.New(0, 0, 0)
    if resPath[index] == 1 then  --- 主角专用字段
        newResPath = roleSex == ROLE_SEX.BOY and artResConfig[1710].Name or artResConfig[1715].Name
        scale = roleSex == ROLE_SEX.BOY and artResConfig[1710].Scale or artResConfig[1715].Scale
        if roleSex == ROLE_SEX.BOY then
            if artResConfig[1710].Position and #artResConfig[1710].Position > 0 then
                localPosition = Vector3.New(artResConfig[1710].Position[1], artResConfig[1710].Position[2])
            end
        else
            if artResConfig[1715].Position and #artResConfig[1715].Position > 0 then
                localPosition = Vector3.New(artResConfig[1715].Position[1], artResConfig[1715].Position[2])
            end
        end
    elseif resPath[index] == 2 then 
        newResPath = roleSex == ROLE_SEX.BOY and artResConfig[1711].Name or artResConfig[1716].Name
        scale = roleSex == ROLE_SEX.BOY and artResConfig[1711].Scale or artResConfig[1716].Scale
        if roleSex == ROLE_SEX.BOY then
            if artResConfig[1711].Position and #artResConfig[1711].Position > 0 then
                localPosition = Vector3.New(artResConfig[1711].Position[1], artResConfig[1711].Position[2])
            end
        else
            if artResConfig[1716].Position and #artResConfig[1716].Position > 0 then
                localPosition = Vector3.New(artResConfig[1716].Position[1], artResConfig[1716].Position[2])
            end
        end
    elseif resPath[index] == 3 then 
        newResPath = roleSex == ROLE_SEX.BOY and artResConfig[1712].Name or artResConfig[1717].Name
        scale = roleSex == ROLE_SEX.BOY and artResConfig[1712].Scale or artResConfig[1717].Scale
        if roleSex == ROLE_SEX.BOY then
            if artResConfig[1712].Position and #artResConfig[1712].Position > 0 then
                localPosition = Vector3.New(artResConfig[1712].Position[1], artResConfig[1712].Position[2])
            end
        else
            if artResConfig[1717].Position and #artResConfig[1717].Position > 0 then
                localPosition = Vector3.New(artResConfig[1717].Position[1], artResConfig[1717].Position[2])
            end
        end
    elseif resPath[index] == 4 then 
        newResPath = roleSex == ROLE_SEX.BOY and artResConfig[1713].Name or artResConfig[1718].Name
        scale = roleSex == ROLE_SEX.BOY and artResConfig[1713].Scale or artResConfig[1718].Scale
        if roleSex == ROLE_SEX.BOY then
            if artResConfig[1713].Position and #artResConfig[1713].Position > 0 then
                localPosition = Vector3.New(artResConfig[1713].Position[1], artResConfig[1713].Position[2])
            end
        else
            if artResConfig[1718].Position and #artResConfig[1718].Position > 0 then
                localPosition = Vector3.New(artResConfig[1718].Position[1], artResConfig[1718].Position[2])
            end
        end
    elseif resPath[index] == 5 then 
        newResPath = roleSex == ROLE_SEX.BOY and artResConfig[1714].Name or artResConfig[1719].Name
        scale = roleSex == ROLE_SEX.BOY and artResConfig[1714].Scale or artResConfig[1719].Scale
        if roleSex == ROLE_SEX.BOY then
            if artResConfig[1714].Position and #artResConfig[1714].Position > 0 then
                localPosition = Vector3.New(artResConfig[1714].Position[1], artResConfig[1714].Position[2])

		--	     LogError("资源名:"..artResConfig[1714]) 

            end
        else
            if artResConfig[1719].Position and #artResConfig[1719].Position > 0 then
                localPosition = Vector3.New(artResConfig[1719].Position[1], artResConfig[1719].Position[2])
			--		     LogError("资源名:"..artResConfig[1719]) 
            end
        end
    else
        if artResConfig[resPath[index]] then
            newResPath = artResConfig[resPath[index]].Name
            scale = artResConfig[resPath[index]].Scale
            if artResConfig[resPath[index]].Position and  #artResConfig[resPath[index]].Position > 0 then
                localPosition = Vector3.New(artResConfig[resPath[index]].Position[1], artResConfig[resPath[index]].Position[2])
            end
        else
            newResPath = 0
        end
    end

    local localScale = Vector3.New(scale, scale, 1)

    if mode==0 then
        this.ReSetLive2d(live2dRoot)
    elseif mode==11 then
        if newResPath==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTrother[index],this.rootlistTr[index],0.3,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==12 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTrup[index],this.rootlistTr[index],0.3,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==13 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this, this.rootlistTr[index],this.rootlistTr[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image").color=Color.New(255 / 255, 255 / 255, 255 / 255, 0.5)
            go:GetComponent("Image"):DOFade(1,0.5)
        end)
    elseif mode==21 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTrother[index],0.3,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
        end)
    elseif mode==22 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTrup[index],0.3,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==23 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTr[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image").color=Color.New(255 / 255, 255 / 255, 255 / 255, 1)
            go:GetComponent("Image"):DOFade(0,0.6)
        end)
    elseif mode==30 then
    elseif mode==31 then
        if resPath[index]==0 then
            return
        end
        live2dRoot.transform:SetSiblingIndex(1)
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true,this, this.rootlistTr[index],this.rootlistTr[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==32 then
        if resPath[index]==0 then
            return
        end
        
        live2dRoot.transform:SetSiblingIndex(0)
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true,this, this.rootlistTr[index],this.rootlistTrDev[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(120 / 255, 120 / 255, 120 / 255, 1),0.1)
        end)
    elseif mode==33 then
        if resPath[index]==0 then
            return
        end
        
        live2dRoot.transform:SetSiblingIndex(0)
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTrDev[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(120 / 255, 120 / 255, 120 / 255, 1),0.1)
        end)
    elseif mode==34 then
        if resPath[index]==0 then
            return
        end
        
        live2dRoot.transform:SetSiblingIndex(1)
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTr[index],0.1,true,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==35 then
        if resPath[index]==0 then
            return
        end
        
        live2dRoot.transform:SetSiblingIndex(1)
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTr[index],0.1,false,function(go)
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
            go:GetComponent("Image"):SetNativeSize()        
            go.transform.localPosition = localPosition
            go.transform.localScale = localScale
            live2dRoot.transform:DOScale(Vector3.New(1.2,1.2,1.2),0.2):SetEase(Ease.OutExpo):OnComplete(function()
                live2dRoot.transform:DOScale(Vector3.one,0.3):SetEase(Ease.OutExpo)
            end)
        end)
    elseif mode==41 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTr[index],0.1,true,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
        end)
    elseif mode==42 then
        if resPath[index]==0 then
            return
        end
        StoryManager.InitLive2dState2(setId, newResPath, live2dRoot, this.effectRoot, true, this,this.rootlistTr[index],this.rootlistTr[index],0.1,false,function(go)
            go:GetComponent("Image"):SetNativeSize()
            go.transform.localScale = localScale
            go.transform.localPosition = localPosition
            -- Util.SetGray(go,false)
            go:GetComponent("Image"):DOColor(Color.New(255 / 255, 255 / 255, 255 / 255, 1),0.1)
            live2dRoot.transform:DOScale(Vector3.New(1.2,1.2,1.2),0.2):SetEase(Ease.OutExpo):OnComplete(function()
                live2dRoot.transform:DOScale(Vector3.one,0.3):SetEase(Ease.OutExpo)
            end)
        end)
    end

end
-- 动态加载立绘
function this.LoadLive2D(data, resPath, live2dRoot)
    PlayUIAnim(live2dRoot)
    poolManager:LoadLive(resPath, live2dRoot.transform, Vector3.one * data.Scale, Vector3.New(data.Position[1], data.Position[2], 0))
end

-- 清除立绘
function this.ReSetLive2d(rootobject)
    if rootobject then
        Util.ClearChild(rootobject.transform)
    else
        Util.ClearChild(this.left2dRoot.transform)
        Util.ClearChild(this.right2dRoot.transform)
    end
end

function StoryDialoguePanel:SetScenceEffect(eventId)

    local effectStr = chapterEventPointData[eventId].scenceEffec
    if not effectStr then ClearChild(this.scenceEffect) return end
    local str = string.split(effectStr, "#")
    local isUse = tonumber(str[1]) == 1
    if not isUse then ClearChild(this.sceneEffect) preEffPar = "" return end
    if effectStr ~= preEffPar then ClearChild(this.sceneEffect) end
    local resPath = str[2]


    -- 下次需要打开同样的特效，不用重新加载
    if effectStr ~= preEffPar then
        local go = StoryManager.LoadEffect(this.sceneEffect, resPath)
        lastSceneEffect = go
        Util.AddParticleSortLayer(this.sceneEffect, self.sortingOrder + orginLayer)
        orginLayer = self.sortingOrder
    end

    preEffPar = effectStr
end

--界面关闭时调用（用于子类重写）
function StoryDialoguePanel:OnClose()
    -- 界面关闭，配音音效关闭
    SoundManager.StopSoundByChannel(10)
end

--界面销毁时调用（用于子类重写）
function StoryDialoguePanel:OnDestroy()

end

return StoryDialoguePanel