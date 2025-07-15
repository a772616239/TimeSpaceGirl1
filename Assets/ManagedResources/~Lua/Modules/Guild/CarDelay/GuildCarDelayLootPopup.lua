require("Base/BasePanel")
GuildCarDelayLootPopup = Inherit(BasePanel)
local this = GuildCarDelayLootPopup
local CarChallenegList--抢夺后端信息
local origilayer = 0
--初始化组件（用于子类重写）
function GuildCarDelayLootPopup:InitComponent()
    this.ItemPre = Util.GetGameObject(self.gameObject, "ItemPre")
    local v2 = Util.GetGameObject(self.gameObject, "ScrollParentView"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "ScrollParentView").transform,
            this.ItemPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,-3))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.BackBtn = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.myScore = Util.GetGameObject(self.gameObject, "Record/Rank1"):GetComponent("Text")
    this.myGuildName = Util.GetGameObject(self.gameObject, "Record/Rank0"):GetComponent("Text")
    this.titleText = Util.GetGameObject(self.gameObject, "bg/titleText"):GetComponent("Text")
    this.mySortNum = Util.GetGameObject(self.gameObject, "Record/SortNum")
    this.Record = Util.GetGameObject(self.gameObject, "Record")
    this.emptyObj = Util.GetGameObject(self.gameObject, "emptyObj")
end

--绑定事件（用于子类重写）
function GuildCarDelayLootPopup:BindEvent()
    Util.AddClick(this.BackBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildCarDelayLootPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildCarDelayLootPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildCarDelayLootPopup:OnOpen(_msg)
    --CarChallenegList = _msg
end

function GuildCarDelayLootPopup:OnSortingOrderChange()
    for i = 1, this.ScrollView.transform.childCount do 
        Util.AddParticleSortLayer(this.ScrollView.transform:GetChild(i - 1).gameObject, self.sortingOrder - origilayer)
    end
    origilayer = self.sortingOrder
end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildCarDelayLootPopup:OnShow()
    NetManager.GetCarChallenegListResponse(function (msg)
        --for i = 1, #msg.carChallengeItem do
        
        --end
        CarChallenegList = msg
        this.titleText.text = GetLanguageStrById(11028)..ConfigManager.GetConfigData(ConfigName.WorldBossSetting,1).GrabPercent/100 ..GetLanguageStrById(11029)
        if CarChallenegList then
            if CarChallenegList.myRank and  CarChallenegList.myRank > 0 then
                this.mySortNum:SetActive(true)
                local sortNumTabs = {}
                for i = 1, 4 do
                    sortNumTabs[i] =  Util.GetGameObject(this.mySortNum, "SortNum ("..i..")")
                    sortNumTabs[i]:SetActive(false)
                end
                if CarChallenegList.myRank < 4 then
                    sortNumTabs[CarChallenegList.myRank]:SetActive(true)
                else
                    sortNumTabs[4]:SetActive(true)
                    Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = CarChallenegList.myRank
                end
            else
                this.mySortNum:SetActive(false)
            end
            this.myGuildName.text = MyGuildManager.MyGuildInfo.name
            this.myScore.text = CarChallenegList.myScore > 0 and CarChallenegList.myScore or GetLanguageStrById(10148)
        end
        this.emptyObj:SetActive(not CarChallenegList.carChallengeItem or #CarChallenegList.carChallengeItem <= 0)
        this.ScrollView:SetData(CarChallenegList.carChallengeItem, function (index, go)
            this.SingleInfoDataShow(go, CarChallenegList.carChallengeItem[index])
        end)
    end)
end
--optional int32 uid = 1;
--optional string userName =2;
--optional int32 force =3;
--optional string guildName = 4;
--optional int32 score = 5;
--optional int32 hadChallenge =6; // 是否已挑战过，1：表示挑战过，2：未挑战过。
--optional int32 rank = 7;
--optional TeamOneInfo teamInfo = 8;
function  this.SingleInfoDataShow(go,data)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(go, "SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if data.rank < 4 then
        sortNumTabs[data.rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = data.rank
    end
    Util.GetGameObject(go, "infoText/playerName"):GetComponent("Text").text = data.userName
    Util.GetGameObject(go, "infoText/warPower"):GetComponent("Text").text = data.force
    Util.GetGameObject(go, "infoText/guildName"):GetComponent("Text").text = data.guildName
    Util.GetGameObject(go, "infoText/soreText"):GetComponent("Text").text = data.score
    
    --hadChallenge =6; // 是否已挑战过，1：表示挑战过，2：未挑战过。
    local curHeroGoList = {}
    for i = 1,6 do
        curHeroGoList[i] = Util.GetGameObject(go, "Demons/heroPro ("..i..")")
        Util.GetGameObject(curHeroGoList[i], "hero"):SetActive(false)
        Util.GetGameObject(curHeroGoList[i], "frame"):GetComponent("Image").sprite = Util.LoadSprite("r_characterbg_gray")
    end
    for i = 1, #data.teamInfo do
        local heroGo = Util.GetGameObject(curHeroGoList[data.teamInfo[i].position], "hero")
        heroGo:SetActive(true)
        local curHeroConfig = ConfigManager.GetConfigData(ConfigName.HeroConfig,data.teamInfo[i].heroTid)
        Util.GetGameObject(heroGo, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(curHeroConfig.Icon))
        Util.GetGameObject(curHeroGoList[data.teamInfo[i].position], "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(nil,data.teamInfo[i].star))
        SetHeroStars(Util.GetGameObject(heroGo, "starGrid"), data.teamInfo[i].star)
        Util.GetGameObject(heroGo, "lvbg/levelText"):GetComponent("Text").text=data.teamInfo[i].level
        local heroData = {}
        Util.AddOnceClick(Util.GetGameObject(Util.GetGameObject(curHeroGoList[data.teamInfo[i].position], "frame"), "frame"), function()
            NetManager.ViewHeroInfoRequest(data.uid,data.teamInfo[i].heroid,function(msg)
                heroData= GoodFriendManager.GetHeroDatas(msg.hero,msg.force,msg.SpecialEffects)
                GoodFriendManager.InitEquipData(msg.equip,heroData)
                GoodFriendManager.InitModelData(msg, heroData)
                UIManager.OpenPanel(UIName.RoleInfoPopup, heroData,true)
            end)
        end)
    end
    --抢夺点击事件
    Util.AddOnceClick(Util.GetGameObject(go, "lootBtn"), function()
        GuildCarDelayManager.SetheroDid(data.uid)
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_CAR_DELEAY)
        this:ClosePanel()
    end)
end
--界面关闭时调用（用于子类重写）
function GuildCarDelayLootPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuildCarDelayLootPopup:OnDestroy()
end

return GuildCarDelayLootPopup