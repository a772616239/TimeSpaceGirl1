----- 编队推荐阵容 -----
require("Base/BasePanel")
FormationExamplePopup = Inherit(BasePanel)
local this = FormationExamplePopup
local recommendConfig=ConfigManager.GetConfig(ConfigName.RecommendTeam)
local heroConfig=ConfigManager.GetConfig(ConfigName.HeroConfig)

local tabs = {}--筛选按钮
local proId=1
function FormationExamplePopup:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn = Util.GetGameObject(this.panel, "BackBtn")
    this.BackMask = Util.GetGameObject(this.gameObject, "BackMask")

    --筛选按钮
    for i = 1, 4 do
        tabs[i] = Util.GetGameObject(this.panel, "Tabs/Grid/Btn" .. i)
    end
    this.selectBtn = Util.GetGameObject(this.panel, "Tabs/SelectBtn")

    this.scroll=Util.GetGameObject(this.panel,"Scroll")
    this.scrollPre=Util.GetGameObject(this.panel,"Scroll/Pre")
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollFitterView, this.scroll.transform,
            this.scrollPre, Vector2.New(912.5, 1090.6), 1, 10)
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function FormationExamplePopup:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    --筛选按钮
    for i = 1, 4 do
        Util.AddClick(tabs[i], function()
            proId=i
            this.OnClickTabBtn(i)
        end)
    end
end

function FormationExamplePopup:AddListener()
end

function FormationExamplePopup:RemoveListener()
end

function FormationExamplePopup:OnOpen()

end

function FormationExamplePopup:OnShow()
    proId=1
    this.OnClickTabBtn(proId)
end

function FormationExamplePopup:OnClose()
end

function FormationExamplePopup:OnDestroy()
    this.scrollView=nil
end



function this.OnClickTabBtn(_proId)
    this.selectBtn:SetActive(proId ==_proId)
    this.selectBtn.transform:SetParent(tabs[_proId].transform)
    this.selectBtn.transform:DOAnchorPos(Vector3.zero,0)
    this.selectBtn.transform:DOScale(Vector3.one,0)

    local curData=ConfigManager.GetAllConfigsDataByKey(ConfigName.RecommendTeam,"Type",proId)
    local _curData={}
    for key, value in pairs(curData) do --只显示在编队中的数据
        if value.IsShowInTeam==1 then
            table.insert(_curData,value)
        end
    end
    table.sort(_curData,function(a,b) return a.Sort<b.Sort end)
    this.scrollView:SetData(_curData, function(index,root)
        this.SetShow(root,_curData[index])
    end)
end

--设置每条显示
function this.SetShow(root,data,index)
    local title=Util.GetGameObject(root,"Title/Text"):GetComponent("Text")
    local desc=Util.GetGameObject(root,"Desc"):GetComponent("Text")
    local heroList=Util.GetGameObject(root,"HeroList")
    local heroDesc=Util.GetGameObject(root,"HeroDesc"):GetComponent("Text")

    title.text=data.Name
    desc.text=data.Desc
    local nh={} --未拥有英雄位置数据
    for i = 1, 6 do
        local o=Util.GetGameObject(heroList,"Item"..i)
        local heroId=data.HeroList[i]
        Util.GetGameObject(o,"Mask"):SetActive(not HeroManager.GetCurHeroIsHaveBySid(heroId))
        if HeroManager.GetCurHeroIsHaveBySid(heroId)==false then table.insert(nh,i) end --未拥有Hero的位置 存储位置信息
        Util.GetGameObject(o,"Frame"):GetComponent("Image").sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[heroId].Quality))
        Util.GetGameObject(o,"Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(heroConfig[heroId].Icon))
        Util.GetGameObject(o,"ProIcon"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(heroConfig[heroId].PropertyName))
        Util.GetGameObject(o,"Lv/Text"):GetComponent("Text").text=1
        SetHeroStars(Util.GetGameObject(o,"Star"),heroConfig[heroId].Star)
    end

    local _strs=string.split(data.HeroDesc,"#")
    for i = 1, #nh do
        _strs[nh[i]]="<color=#7A6849>".._strs[nh[i]].."</color>"
    end
    for n = 1, #_strs do
        _strs[n]=_strs[n].."\n"
    end
    heroDesc.text=string.sub(table.concat(_strs),1,-2)--将表里字符串拼接 去除最后\n
end

return FormationExamplePopup