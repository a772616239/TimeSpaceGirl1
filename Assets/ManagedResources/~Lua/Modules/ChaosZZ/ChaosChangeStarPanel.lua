require("Base/BasePanel")
ChaosChangeStarPanel = Inherit(BasePanel)
local this = ChaosChangeStarPanel
local tipItemPosition = -105
--初始化组件（用于子类重写）
function ChaosChangeStarPanel:InitComponent()
    this.hedaParent = Util.GetGameObject(this.gameObject, "Content/info/TopImg/TopInfo/Head")
    this.playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.hedaParent.transform)
    this.playerHead:Reset()
    this.name = Util.GetGameObject(this.gameObject, "Content/info/TopImg/TopInfo/nameText"):GetComponent("Text")
    this.zhanliValue = Util.GetGameObject(this.gameObject, "Content/info/TopImg/TopInfo/ZhanLiImage/ZhanLiValueText"):GetComponent("Text")
    this.zhipeiValue = Util.GetGameObject(this.gameObject, "Content/info/TopImg/TopInfo/ZhiPeiLi_1/ZhiPeiValueText"):GetComponent("Text")
    this.campName = Util.GetGameObject(this.gameObject, "Content/info/TopImg/Image/SingBG/CampText"):GetComponent("Text")
    this.signImg = Util.GetGameObject(this.gameObject, "Content/info/TopImg/Image/SignImg"):GetComponent("Image")
    this.starsParent = Util.GetGameObject(this.gameObject, "Content/ChanllgeContent")
    --btns
    this.starbtn1 = Util.GetGameObject(this.starsParent, "Item1/Btn")
    this.starbtn2 = Util.GetGameObject(this.starsParent, "Item2/Btn")
    this.starbtn3 = Util.GetGameObject(this.starsParent, "Item3/Btn")

    this.closeBtn = Util.GetGameObject(this.gameObject, "closeBtn")
   
    this.Demons = {}
    for i = 1, 6 do
        table.insert(this.Demons, Util.GetGameObject(self.gameObject, "Content/info/BottomImg/Demons/heroPro (" .. i .. ")"))
    end
end

--绑定事件（用于子类重写）
function ChaosChangeStarPanel:BindEvent()
    
        Util.AddClick(this.starbtn1, function()
           -- UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.STORY, FightPointPassManager.curOpenFight)
           ChaosManager:SetChallegeStar(1) 
           UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CHAOS_BATTLE_ACK)
            this:ClosePanel()
        end)
        Util.AddClick(this.starbtn2, function()
            ChaosManager:SetChallegeStar(2)
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CHAOS_BATTLE_ACK)
            this:ClosePanel()
        end)
        Util.AddClick(this.starbtn3, function()
            ChaosManager:SetChallegeStar(3) 
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.CHAOS_BATTLE_ACK)
            this:ClosePanel()
        end)
        Util.AddClick(this.closeBtn, function()
            PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
                this:ClosePanel()
        end)
end

--添加事件监听（用于子类重写）
function ChaosChangeStarPanel:AddListener()
  
end

--移除事件监听（用于子类重写）
function ChaosChangeStarPanel:RemoveListener()
   
end

-- --界面打开时调用（用于子类重写）
function ChaosChangeStarPanel:OnOpen()
   
end

function ChaosChangeStarPanel:SetInfo()
    local challengeStarData = ChaosManager:GetSelectData()
        this.playerHead:SetScale(Vector3.one*0.7)
              this.playerHead:SetHead(challengeStarData.userSimpleInfo.headIcon)
              this.playerHead:SetFrame(challengeStarData.userSimpleInfo.headFrame)
              this.playerHead:SetLevel(challengeStarData.userSimpleInfo.level)
              this.playerHead:SetClickedTypeId(PlayerInfoType.CSArena)
              this.playerHead:SetViewType(PLAYER_INFO_VIEW_TYPE.ChaosZZ)
              this.playerHead:SetUID(challengeStarData.userSimpleInfo.userId)
              for _index, _value in ipairs(challengeStarData.userSimpleInfo.fightMap) do
                if _value.teamId == ChaosManager.zhanliTeamId then
                    this.zhanliValue.text = _value.fight
                    break
                end
              end  
        this.name.text = challengeStarData.userSimpleInfo.nickName
        this.zhipeiValue.text = challengeStarData.score
        --this.campName.text = challengeStarData.userSimpleInfo.camp
        this:SetName(challengeStarData.userSimpleInfo.camp,this.campName)
        this.signImg.sprite =   Util.LoadSprite("cn2-X1_hunluanzhizhi_biaozhi_0"..challengeStarData.userSimpleInfo.camp)
        this:SetItems()
end
function this:SetName(id,Text)
    if id == 1 then
        Text.text = "秩序阵营"
    elseif id==2 then
        Text.text = "混沌阵营"
    elseif id==3 then
        Text.text = "腐化阵营"
    end
end
this.tipItemlist = {}
--阵容设置各个星级描述
function ChaosChangeStarPanel:SetStarTips()
    if not this.tipItemlist then
        this.tipItemlist = {}
    end
    for i = 1, 3 do
        if not this.tipItemlist[i] then
            this.tipItemlist[i]={}
        end
        
      local item =  Util.GetGameObject(this.starsParent, "Item"..i)
       if i==1 then
          local tips =  Util.GetGameObject(item, "AddTips/Tips"):GetComponent("Text")
          tips.text = "一星对手无额外加成"
       else
        local config = ChaosManager:GetFoodsConfig()
        local tipsData = config[53]
         if i==2 then
             tipsData= config[52]
         end  
          local tipsDesData =  GetLanguageStrById(tipsData.Desc+0)
          local splitTipsDes = string.split(tipsDesData,"、")
          for k = 1, #splitTipsDes do
                local value = string.split(splitTipsDes[k],"+") 
               -- for j = 1, #value do
               local tipItem =  Util.GetGameObject(item, "AddTips/tipItem")
              
               if not this.tipItemlist[i][k] then
                 this.tipItemlist[i][k]  = newObject(tipItem)
               end
               
               this.tipItemlist[i][k].transform:SetParent(Util.GetGameObject(item, "AddTips").transform)
               this.tipItemlist[i][k].transform.localScale = Vector3.one
                 if k~=1 then
                    this.tipItemlist[i][k].transform.localPosition = Vector2.New(0, tipItemPosition-40*(k-1)) 
                    -- body
                 else
                    this.tipItemlist[i][k].transform.localPosition = tipItem.transform.localPosition
                 end
                 
              local tips = Util.GetGameObject(this.tipItemlist[i][k], "Tip"):GetComponent("Text")
              local tipsValue = Util.GetGameObject(this.tipItemlist[i][k], "Tipvalue"):GetComponent("Text")
                tipsValue.gameObject:SetActive(true)
                tips.text =  "  "..value[1]
                tipsValue.text = "   +"..value[2]
               -- end
          end
       end
    end
end
--阵容设置
function ChaosChangeStarPanel:SetItems()
   
    local challengeStarData = ChaosManager:GetSelectData()
    local teamInfos = ChaosManager:GetChaosTeams()
    local  teamInfo = {}  
   -- Log("________________选择挑战id       "..)
    for _i, _v in ipairs(teamInfos) do

         if _v.uid == challengeStarData.userSimpleInfo.userId then
             teamInfo = _v
             break
         end
    end
        local allteaminfo = teamInfo
        if allteaminfo.team.substitute ~="" and allteaminfo.team.substitute~=nil then
            local hero = {
                heroid = allteaminfo.substitute ,
                heroTid = allteaminfo.substituteTid ,
                star = allteaminfo.substituteStar,
                level = allteaminfo.substituteLevel
            }
            local tibuPos = 6 -- 对应预制体位置
            local heroGo = Util.GetGameObject(this.Demons[tibuPos], "hero")
            heroGo:SetActive(true)
            Util.GetGameObject(this.Demons[tibuPos], "proIconBg"):SetActive(true)
            Util.GetGameObject(this.Demons[tibuPos], "proIcon"):SetActive(true)
            Util.GetGameObject(this.Demons[tibuPos], "Lvbg"):SetActive(true)
            Util.GetGameObject(this.Demons[tibuPos], "levelText"):SetActive(true)
            Util.GetGameObject(this.Demons[tibuPos], "starGrid"):SetActive(true)
            SetHeroStars(Util.GetGameObject(this.Demons[tibuPos], "starGrid"), hero.star)
            local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, hero.heroTid)
            Util.GetGameObject(this.Demons[tibuPos], "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
            Util.GetGameObject(heroGo, "frameBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroConfig.Quality))
            Util.GetGameObject(this.Demons[tibuPos], "levelText"):GetComponent("Text").text = hero.level
            Util.GetGameObject(this.Demons[tibuPos], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, hero.star))
            Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
            Util.GetGameObject(this.Demons[tibuPos], "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality, hero.star))
           
            local frameBtn = Util.GetGameObject(this.Demons[tibuPos], "frame")
            local heroData = {}
            Util.AddOnceClick(frameBtn, function()
                    NetManager.WorldViewHeroInfoRequest(challengeStarData.userSimpleInfo.userId,hero.heroid, function(msg)
                        heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                        GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                        GoodFriendManager.InitModelData(msg, heroData)
                        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                    end)
            end)
       end
      
     
        for i, demon in ipairs(this.Demons) do
            Util.GetGameObject(demon, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(1))
            Util.GetGameObject(demon, "hero"):SetActive(false)
            Util.GetGameObject(demon, "proIconBg"):SetActive(false)
            Util.GetGameObject(demon, "proIcon"):SetActive(false)
            Util.GetGameObject(demon, "Lvbg"):SetActive(false)
            Util.GetGameObject(demon, "levelText"):SetActive(false)
            Util.GetGameObject(demon, "starGrid"):SetActive(false)
        end
        if teamInfo.team == nil then
            Log("___________阵容数据为空")
            return
        end
        for i, hero in ipairs(teamInfo.team.team) do
            local demonId = teamInfo.team.team[i].heroTid
            if demonId then
                local heroGo = Util.GetGameObject(this.Demons[i], "hero")
                heroGo:SetActive(true)
                Util.GetGameObject(this.Demons[i], "proIconBg"):SetActive(true)
                Util.GetGameObject(this.Demons[i], "proIcon"):SetActive(true)
                Util.GetGameObject(this.Demons[i], "Lvbg"):SetActive(true)
                Util.GetGameObject(this.Demons[i], "levelText"):SetActive(true)
                Util.GetGameObject(this.Demons[i], "starGrid"):SetActive(true)
                SetHeroStars(Util.GetGameObject(this.Demons[i], "starGrid"), hero.star)
                local heroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig, demonId)
                Util.GetGameObject(this.Demons[i], "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
                Util.GetGameObject(heroGo, "frameBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityBgImageByquality(heroConfig.Quality))
                Util.GetGameObject(this.Demons[i], "levelText"):GetComponent("Text").text = hero.level
                Util.GetGameObject(this.Demons[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(heroConfig.Quality, hero.star))
                Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
                Util.GetGameObject(this.Demons[i], "proIconBg"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfig.Quality, hero.star))
                --
                local frameBtn = Util.GetGameObject(this.Demons[i], "frame")
                local heroData = {}
                Util.AddOnceClick(frameBtn, function()
                        NetManager.WorldViewHeroInfoRequest(challengeStarData.userSimpleInfo.userId,hero.heroid,function(msg)
                        heroData = GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects,msg.guildSkill)
                        GoodFriendManager.InitEquipData(msg.equip,heroData)--HeroManager.GetSingleHeroData(heroData.dynamicId)
                        GoodFriendManager.InitModelData(msg, heroData)
                        UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
                    end)
                end)
            end
        end   
end


function ChaosChangeStarPanel:RefreshView()
    this:SetInfo()
    this:SetStarTips()
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ChaosChangeStarPanel:OnShow()
    this:RefreshView()
end

--界面关闭时调用（用于子类重写）
function ChaosChangeStarPanel:OnClose()
   
end

--界面销毁时调用（用于子类重写）
function ChaosChangeStarPanel:OnDestroy()
   this.tipItemlist = {}
end

return ChaosChangeStarPanel