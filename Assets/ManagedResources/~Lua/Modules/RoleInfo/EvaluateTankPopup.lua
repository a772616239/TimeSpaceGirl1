require("Base/BasePanel")

EvaluateTankPopup = Inherit(BasePanel)
local this = EvaluateTankPopup
local artResourcesConfig =ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local listType=0
local tankBag=false
local listImage=
{
    [0] = "N1_btn_tanke_dianzaipaixu",
    [1] = "N1_btn_tanke_shijianpaixu",
}


function this:InitComponent()
    this.back=Util.GetGameObject(this.gameObject,"btnBack")
    this.itempre=Util.GetGameObject(this.gameObject,"grid/recordPer")
    this.rect=Util.GetGameObject(this.gameObject,"grid/rect")
    this.cardPre=Util.GetGameObject(this.gameObject,"grid/recordPer")
    this.tankImage=Util.GetGameObject(this.gameObject,"grid/comment/tankImage")
    this.notObtained=Util.GetGameObject(this.gameObject,"grid/comment/notObtained")
    this.tankName=Util.GetGameObject(this.gameObject,"grid/comment/name"):GetComponent("Text")
    this.commentNum=Util.GetGameObject(this.gameObject,"grid/comment/commentNum"):GetComponent("Text")
    this.loveDegree=Util.GetGameObject(this.gameObject,"grid/comment/loveDegree"):GetComponent("Text")
    this.inputField=Util.GetGameObject(this.gameObject,"grid/comment/InputField")
    this.mycomment=Util.GetGameObject(this.gameObject,"grid/comment/recordPer")
    this.noneImage=Util.GetGameObject(this.gameObject,"grid/NoneImage")
    this.tankButton=Util.GetGameObject(this.gameObject,"grid/comment/Button")
    this.SortBtn=Util.GetGameObject(this.gameObject,"grid/SortBtn")
    this.lock=Util.GetGameObject(this.gameObject,"grid/comment/lock")
    this.inputFieldButton=Util.GetGameObject(this.gameObject,"grid/comment/InputField/Button")
    local width=this.rect.transform.rect.width
    local height=this.rect.transform.rect.height
    this.scrollCycle=SubUIManager.Open(SubUIConfig.ScrollCycleView, this.rect.transform,
    this.cardPre, nil, Vector2.New(width, height), 1, 1, Vector2.New(0,0)) --n1
end

function this:BindEvent()
    Util.AddOnceClick(this.inputFieldButton, function()
        NetManager.RequestEvaluateTankText(this.heroConfig.Id,this.inputField:GetComponent("InputField").text,function ()
            NetManager.RequestEvaluateTank(this.heroConfig.Id,1,1,function (msg)
                this:InitScrollCycle(msg)
            end)
        end)
    end)
    Util.AddOnceClick(this.back, function()
        self:ClosePanel()
    end)
    Util.AddOnceClick(this.tankButton, function()
        NetManager.RequestEvaluateTankLike(this.heroConfig.Id,function ()
            NetManager.RequestEvaluateTank(this.heroConfig.Id,1,1,function (msg)
                this:InitScrollCycle(msg)
            end)
        end)
    end)
    Util.AddOnceClick(this.SortBtn, function()
        NetManager.RequestEvaluateTank(this.heroConfig.Id,1,1,function (msg)
            if listType==0 then
                listType=1
            else
                listType=0
            end
            this:InitScrollCycle(msg)
        end)
    end)
end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnOpen(msg,heroConfig)
    this.heroConfig=heroConfig
    -- this.tankImage.sprite=Util.LoadSprite(artResourcesConfig[heroConfig.RoleImage].Name)
    -- Util.GetGameObject(this.tankImage, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfig.Quality,heroConfig.star))
    Util.GetGameObject(this.tankImage, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(heroConfig.Icon))
    Util.GetGameObject(this.tankImage, "proIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfig.PropertyName))
    this.tankName.text=GetLanguageStrById(heroConfig.ReadingName)
    tankBag=PlayerManager.GetHeroDataByStar(this.heroConfig.Star,this.heroConfig.Id)
    listType=0
    this:InitScrollCycle(msg)
end

function this:OnShow()
end

function this:Init()
   
end
function this:myComment(msg)
    if tankBag then
        this.notObtained:SetActive(false)
        if msg.myComment.content=="" then
            this:SetComment()
        else
            this:LookMyComment(msg.myComment)
        end
    else
        this.notObtained:SetActive(true)
        this.mycomment:SetActive(false)
        this.inputField:SetActive(false)
    end
end
function this:InitScrollCycle(msg)
    this.trankEvaluateData=msg
    this.commentNum.text=msg.commentNum
    this.loveDegree.text=msg.loveDegree
    this.highLikesList={}
    if msg.isLikedHero then
        this.lock:SetActive(true)
        this.tankButton:SetActive(false)
    else
        this.lock:SetActive(false)
        this.tankButton:SetActive(true)
    end
    for index, value in ipairs(this.trankEvaluateData.heroCommentList) do
        table.insert(this.highLikesList, value)
    end
    if listType==0 then
        this.highLikesList=this.SortData(this.highLikesList)
    else
        this.highLikesList=this.SortDataLike(this.highLikesList)
    end
    if #this.highLikesList==0  then
        this.noneImage:SetActive(true)
    else
        this.noneImage:SetActive(false)
    end
    this.SortBtn:GetComponent("Image").sprite= Util.LoadSprite(listImage[listType])
    this.scrollCycle:SetData(this.highLikesList,function(index,go)
        this.SingleCommentShow(go, this.highLikesList[index])
    end)
    NetManager.HeroMyCommentRequest(this.heroConfig.Id,function (msg)
        this:myComment(msg)
    end)
end
function this.SortData(allData)
    if allData==nil then
        return
    end
    table.sort(allData, function(a,b)
        if a.time == b.time then
            return a.likes < b.likes
        else
            return a.time < b.time
        end
    end)
    return allData
end
function this.SortDataLike(allData)
    if allData==nil then
        return
    end
    table.sort(allData, function(a,b)
        if a.likes == b.likes then
            return a.time < b.time
        else
            return a.likes < b. likes
        end
    end)
    return allData
end
--点击装备按钮
function this:OnClickTabBtn(_index)
end
--显示点赞内容
function this:LookMyComment(myComment)
    this.mycomment:SetActive(true)
    this.inputField:SetActive(false)
    Util.GetGameObject(this.mycomment,"name/text"):GetComponent("Text").text=myComment.uName
    Util.GetGameObject(this.mycomment,"Mask/proPre1/pro1/proName"):GetComponent("Text").text=myComment.content
    Util.GetGameObject(this.mycomment,"name/num"):GetComponent("Text").text=myComment.likes
    Util.AddOnceClick(Util.GetGameObject(this.mycomment,"Button"), function()
        NetManager.RequestEvaluateTankDelText(this.heroConfig.Id,myComment.id,function ()
            NetManager.RequestEvaluateTank(this.heroConfig.Id,1,1,function (msg)
                this:InitScrollCycle(msg)
            end)
        end)
    end)
end
function this:SetComment()
    this.mycomment:SetActive(false)
    this.inputField:SetActive(true)
end

function this.SingleCommentShow(_go, _itemData)
    Util.GetGameObject(_go,"name/text"):GetComponent("Text").text=_itemData.uName
    Util.GetGameObject(_go,"Mask/proPre1/pro1/proName"):GetComponent("Text").text=_itemData.content
    Util.GetGameObject(_go,"name/num"):GetComponent("Text").text=_itemData.likes
    if _itemData.isLikedIt then
        Util.GetGameObject(_go,"lock"):SetActive(true)
        Util.GetGameObject(_go,"Button"):SetActive(false)
    else
        Util.GetGameObject(_go,"lock"):SetActive(false)
        Util.GetGameObject(_go,"Button"):SetActive(true)
    end
    Util.AddOnceClick(Util.GetGameObject(_go,"Button"), function()
        NetManager.RequestEvaluateTankId(_itemData.id,function ()
            NetManager.RequestEvaluateTank(this.heroConfig.Id,1,1,function (msg)
                this:InitScrollCycle(msg)
            end)
        end)
    end)
end

function this:SortEquipDatas(_equipDatas)

end

function this:OnSortingOrderChange(orginLayer)

end

function this:OnClose()
end

function this:Dispose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
end

return this