local NumberViewItem = {}
function NumberViewItem:New(obj, item, imagePrefix, num, v2)
    local o = {}
    setmetatable(o, {__index = NumberViewItem})
    o.gameObject = obj
    o.imagePrefix = imagePrefix

    o.moveRT = Util.GetGameObject(o.gameObject,"move"):GetComponent("RectTransform")
    o.item = item

    o.goRT = o.gameObject:GetComponent("RectTransform")
    o.goRT.sizeDelta = v2

    local n = 2
    o.moveGOList = {}
    o.num = num
    for i=1,n do
        local go = newObject(o.item)
        go.transform:SetParent(o.moveRT.transform)
        go.transform.localScale = Vector3.one
        go:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, v2.y * (i-1))
        go:GetComponent("Image").sprite = Util.LoadSprite(o.imagePrefix..tostring((num+i-1)%10))
        go:SetActive(true)
        o.moveGOList[i] = {tran = go:GetComponent("RectTransform"), image = go:GetComponent("Image")}
    end
    return o
end
function NumberViewItem:SetNum(num)
    self.moveRT.anchoredPosition = Vector2.New(0, 0)
    local h = self.goRT.sizeDelta.y
    for i=1, #self.moveGOList do
        self.moveGOList[i].tran.anchoredPosition = Vector2.New(0, h * (i-1))
    end
    self.num = num
end

function NumberViewItem:Move(num, duration, isUp, exOrder)
    local h = self.goRT.sizeDelta.y
    if not isUp then
        h = -h
    end
    exOrder = (exOrder or 0) * 10
    local t = exOrder > 0 and duration / exOrder or 0
    local tempI = 1
    local count = #self.moveGOList
    local d = num - self.num
    if d < 0 then
        d = d + 10
    end

    self.moveGOList[1].image.sprite = Util.LoadSprite(self.imagePrefix..tostring(self.num))
    for i=1, #self.moveGOList do
        self.moveGOList[i].tran.anchoredPosition = Vector2.New(0, -h * (i-1))
    end
    DoTween.To(DG.Tweening.Core.DOGetter_float(function () return 0 end),
            DG.Tweening.Core.DOSetter_float(function (f)
                self.moveRT.anchoredPosition = Vector2.New(0, f)
                local index = math.floor(f / h) + 1
                local ci = (index - 1) % count + 1
                if tempI ~= ci then
                    tempI = ci
                    local c = math.floor(index / count)
                    local x = ci % count + c * count
                    self.moveGOList[ci % count + 1].image.sprite = Util.LoadSprite(self.imagePrefix..tostring(x % 10))
                    self.moveGOList[ci % count + 1].tran.anchoredPosition = Vector2.New(0, x * -h)
                end
            end),
            (exOrder+d)*h, duration + t*d):SetEase(Ease.InOutQuad)
    self.num = num
end

NumberView = {}
function NumberView:New(gameObject)
    local u={}
    u.gameObject = gameObject
    u.transform = gameObject.transform
    u.layout = Util.GetGameObject(u.gameObject,"Grid"):GetComponent("GridLayoutGroup")
    setmetatable(u, {__index = NumberView})
    return u
end

--初始化组件（用于子类重写）
function NumberView:InitComponent()
    self.itemGO = Util.GetGameObject(self.gameObject, "col")
    self.item = Util.GetGameObject(self.gameObject, "item")
    self.Grid = Util.GetGameObject(self.gameObject, "Grid")
end

--界面打开时调用（用于子类重写）
function NumberView:OnOpen(imagePrefix, sizeV2, spacingV2, num, maxNum)
    self.curNum = num
    self.nums = {}
    self.item:GetComponent("RectTransform").sizeDelta = sizeV2
    local count = math.floor(math.log10(maxNum)) + 1
    for i = 1, count do
        local go = newObject(self.itemGO)
        self.nums[i] = NumberViewItem:New(go, self.item, imagePrefix, num % 10, Vector2.New(sizeV2.x, sizeV2.y + spacingV2.y))
        num = math.floor(num / 10)
        go.transform:SetParent(self.Grid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero
        go.transform:SetAsFirstSibling()
        go:SetActive(true)
    end
    self.layout.cellSize = Vector2.New(sizeV2.x, sizeV2.y + spacingV2.y)
    self.layout.spacing = Vector2.New(spacingV2.x, 0)
end

function NumberView:SetNum(num)
    self.curNum = num
    local n1 = num
    for i = 1, #self.nums do
        local i1= n1 % 10
        self.nums[i]:SetNum(tostring(i1))
        n1 = math.floor(n1 / 10)
    end
end

function NumberView:DONum(num, duration, isUp)
    local n1 = num
    for i = 1, #self.nums do
        local i1 = n1 % 10
        self.nums[i]:Move(tostring(i1), duration, isUp, 3)
        n1 = math.floor(n1 / 10)
    end
    self.curNum = num
end

function NumberView:DOItemNum(num, itemFunc)
    local n1 = num
    for i = 1, #self.nums do
        local i1= n1 % 10
        if itemFunc then
            itemFunc(i, i1, self.nums[i])
        end
        n1 = math.floor(n1 / 10)
    end
    self.curNum = num
end

return NumberView