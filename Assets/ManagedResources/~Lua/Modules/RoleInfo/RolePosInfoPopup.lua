----- 角色定位弹窗 -----
require("Base/BasePanel")
local RolePosInfoPopup = Inherit(BasePanel)
local this=RolePosInfoPopup
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)

local curHeroData
--属性容器
local preList = {}


function RolePosInfoPopup:InitComponent()
    this.panel=Util.GetGameObject(this.gameObject,"Panel")
    this.backBtn=Util.GetGameObject(this.panel,"BackBtn")
    this.content=Util.GetGameObject(this.panel,"Scroll/Panel/Content")

    this.posInfo=Util.GetGameObject(this.content,"Title/PosInfo"):GetComponent("Text") --定位描述
    this.posText=Util.GetGameObject(this.content,"Title/PosText"):GetComponent("Text") --定位文字

    this.grid=Util.GetGameObject(this.content,"Grid") --预设父节点
    this.pre=Util.GetGameObject(this.content,"Grid/Pre") --预设
end

function RolePosInfoPopup:BindEvent()
    --返回按钮
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

function RolePosInfoPopup:AddListener()

end

function RolePosInfoPopup:RemoveListener()

end

function RolePosInfoPopup:OnSortingOrderChange()

end

function RolePosInfoPopup:OnOpen(_curHeroData)
    curHeroData=_curHeroData-- 传递表数据
end

function RolePosInfoPopup:OnShow()
    this.RefreshPanel()
end
function RolePosInfoPopup:OnClose()

end

function RolePosInfoPopup:OnDestroy()
    preList={}
end


--刷新面板
function this.RefreshPanel()
    this.content.transform:DOAnchorPosY(0,0)
    --设置顶部表现
    this.posInfo.text=curHeroData.HeroLocationDesc1
    local hDesc=curHeroData.HeroLocationDesc2
    this.posText.text=string.gsub(hDesc,"|","\n")

    for j = 1,this.grid.transform.childCount do
        this.grid.transform:GetChild(j-1).gameObject:SetActive(false)
    end
    local _curData={}
    for k,v in pairs(curHeroData.RecommendTeamId) do
        local _data=ConfigManager.GetConfigData(ConfigName.RecommendTeam,v)
        if _data.IsShowInTeam==1 then
            table.insert(_curData,_data)
        end
    end
    --设置滚动区表现
    for i = 1, LengthOfTable(_curData) do
        local item= preList[i]
        if not item then --生成预设
            item= newObjToParent(this.pre,this.grid)
            item.name="ProPre"..i
            preList[i]=item
        end
        preList[i].gameObject:SetActive(true)
        --获取组件
        local teamTitle=Util.GetGameObject(preList[i],"TeamTitle/Text"):GetComponent("Text")
        local desc=Util.GetGameObject(preList[i],"Desc"):GetComponent("Text")
        local heroList=Util.GetGameObject(preList[i],"HeroList")
        local heroDesc=Util.GetGameObject(preList[i],"HeroDesc"):GetComponent("Text")

        teamTitle.text=_curData[i].Name
        desc.text=_curData[i].Desc
        local nh={} --未拥有英雄位置数据
        for j = 1, 6 do --设置6个英雄
            local o=Util.GetGameObject(heroList,"Item"..j)
            local heroId=_curData[i].HeroList[j]
            Util.GetGameObject(o,"Mask"):SetActive(not HeroManager.GetCurHeroIsHaveBySid(heroId))
            if HeroManager.GetCurHeroIsHaveBySid(heroId)==false then table.insert(nh,j) end --未拥有Hero的位置 存储位置信息
            Util.GetGameObject(o,"Frame"):GetComponent("Image").sprite=Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig[heroId].Quality,heroConfig[heroId].Star))
            Util.GetGameObject(o,"Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(heroConfig[heroId].Icon))
            Util.GetGameObject(o,"ProIcon"):GetComponent("Image").sprite=Util.LoadSprite(GetProStrImageByProNum(heroConfig[heroId].PropertyName))
            Util.GetGameObject(o,"Lv/Text"):GetComponent("Text").text=1
            SetHeroStars(Util.GetGameObject(o,"Star"),heroConfig[heroId].Star)
        end
        --每位英雄的描述信息 字符串组合到一个text组件中
        local _strs=string.split(_curData[i].HeroDesc,"#") --切割成多个
        for i = 1, #nh do --设置未激活表现
            _strs[nh[i]]="<color=#7A6849>".._strs[nh[i]].."</color>"
        end
        for n = 1, #_strs do --添加回车符
            _strs[n]=_strs[n].."\n"
        end
        heroDesc.text=string.sub(table.concat(_strs),1,-2)--将表里字符串拼接 去除最后\n
    end
end

return RolePosInfoPopup