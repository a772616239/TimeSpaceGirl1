HeroRadarChart = {}
local this = HeroRadarChart

local DIMENSIONS = { "hp", "attack", "pDef", "mDef", "speed", "warPower" }
local DIM_LABELS = { "生命", "攻击", "物防", "魔防", "速度", "战力" }

local GRID_COLOR = { r = 0.4, g = 0.4, b = 0.5, a = 0.3 }
local AXIS_COLOR = { r = 0.5, g = 0.5, b = 0.6, a = 0.5 }
local LABEL_COLOR = { r = 0.9, g = 0.9, b = 0.9, a = 1.0 }

function this:New(gameObject, sortingOrder)
    local instance = {}
    instance.gameObject = gameObject
    instance.transform = gameObject.transform
    instance.sortingOrder = sortingOrder or 0
    instance.meshFilter = nil
    instance.meshRenderer = nil
    instance.labelTexts = {}
    setmetatable(instance, { __index = HeroRadarChart })
    instance:Init()
    return instance
end

function this:Init()
    local meshGo = GameObject.New("RadarMesh")
    meshGo.transform:SetParent(self.transform, false)
    meshGo.transform.localPosition = Vector3.zero
    meshGo.transform.localScale = Vector3.one
    meshGo.transform.localRotation = Quaternion.identity

    self.meshFilter = meshGo:AddComponent(typeof(MeshFilter))
    self.meshRenderer = meshGo:AddComponent(typeof(MeshRenderer))

    local mesh = Mesh.New()
    self.meshFilter.mesh = mesh

    self.meshRenderer.material = Material(Shader.Find("UI/Default"))
    self.meshRenderer.sortingOrder = self.sortingOrder

    self:CreateLabels()
end

function this:CreateLabels()
    local dimCount = #DIMENSIONS
    for i = 0, dimCount - 1 do
        local angle = (math.pi * 2 / dimCount) * i - math.pi / 2
        local labelRadius = 155
        local x = math.cos(angle) * labelRadius
        local y = math.sin(angle) * labelRadius

        local labelGo = GameObject.New("label_" .. i)
        labelGo.transform:SetParent(self.transform, false)
        labelGo.transform.localPosition = Vector3.New(x, y, 0)
        labelGo.transform.localScale = Vector3.one

        local text = labelGo:AddComponent(typeof(Text))
        text.text = DIM_LABELS[i + 1]
        text.alignment = TextAnchor.MiddleCenter
        text.fontSize = 22
        text.color = Color.New(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, LABEL_COLOR.a)

        local rt = labelGo:GetComponent("RectTransform")
        rt.sizeDelta = Vector2.New(80, 30)

        table.insert(self.labelTexts, text)
    end
end

function this:Draw(leftValues, rightValues, leftColor, rightColor)
    if not self.meshFilter then return end
    local mesh = self.meshFilter.mesh
    mesh:Clear()

    local dimCount = #DIMENSIONS
    local center = Vector3.zero
    local radius = 120

    leftColor = leftColor or Color.New(0.30, 0.68, 1.00, 0.45)
    rightColor = rightColor or Color.New(1.00, 0.42, 0.34, 0.45)

    local vertices = {}
    local triangles = {}
    local colors = {}
    local uvs = {}
    local vIdx = 0

    local function getAxisPoint(index, scale)
        local angle = (math.pi * 2 / dimCount) * index - math.pi / 2
        return Vector3(math.cos(angle) * radius * scale, math.sin(angle) * radius * scale, 0)
    end

    local gridLevels = { 0.25, 0.5, 0.75, 1.0 }
    for _, level in ipairs(gridLevels) do
        local baseIdx = vIdx
        for i = 0, dimCount - 1 do
            vIdx = vIdx + 1
            table.insert(vertices, getAxisPoint(i, level))
            table.insert(colors, Color.New(GRID_COLOR.r, GRID_COLOR.g, GRID_COLOR.b, GRID_COLOR.a))
            table.insert(uvs, Vector2.zero)
        end
        for i = 0, dimCount - 1 do
            local next = (i + 1) % dimCount
            table.insert(triangles, baseIdx + i)
            table.insert(triangles, baseIdx + next)
        end
    end

    for i = 0, dimCount - 1 do
        local tip = getAxisPoint(i, 1.0)
        vIdx = vIdx + 1
        table.insert(vertices, center)
        table.insert(colors, Color.New(AXIS_COLOR.r, AXIS_COLOR.g, AXIS_COLOR.b, 0))
        table.insert(uvs, Vector2.zero)

        vIdx = vIdx + 1
        table.insert(vertices, tip)
        table.insert(colors, Color.New(AXIS_COLOR.r, AXIS_COLOR.g, AXIS_COLOR.b, AXIS_COLOR.a))
        table.insert(uvs, Vector2.zero)

        table.insert(triangles, vIdx - 2)
        table.insert(triangles, vIdx - 1)
    end

    local function drawFilledArea(values, color)
        if not values then return end
        local baseIdx = vIdx
        vIdx = vIdx + 1
        table.insert(vertices, center)
        table.insert(colors, Color.New(color.r, color.g, color.b, color.a * 0.15))
        table.insert(uvs, Vector2.zero)

        for i = 0, dimCount - 1 do
            vIdx = vIdx + 1
            local pt = getAxisPoint(i, values[i + 1] or 0)
            table.insert(vertices, pt)
            table.insert(colors, color)
            table.insert(uvs, Vector2.zero)
        end

        for i = 1, dimCount do
            local next = (i % dimCount) + 1
            table.insert(triangles, baseIdx)
            table.insert(triangles, baseIdx + i)
            table.insert(triangles, baseIdx + next)
        end

        local edgeBaseIdx = vIdx
        for i = 0, dimCount do
            vIdx = vIdx + 1
            local idx = i % dimCount
            local pt = getAxisPoint(idx, values[idx + 1] or 0)
            table.insert(vertices, pt)
            table.insert(colors, Color.New(color.r, color.g, color.b, 0.9))
            table.insert(uvs, Vector2.zero)
        end
        for i = 0, dimCount - 1 do
            local next = (i + 1) % (dimCount + 1)
            table.insert(triangles, edgeBaseIdx + i)
            table.insert(triangles, edgeBaseIdx + next)
        end
    end

    drawFilledArea(leftValues, leftColor)
    drawFilledArea(rightValues, rightColor)

    mesh.vertices = vertices
    mesh.triangles = triangles
    mesh.colors = colors
    mesh.uv = uvs
    mesh:RecalculateBounds()
end

function this:Clear()
    if self.meshFilter then
        self.meshFilter.mesh:Clear()
    end
end

function this:Destroy()
    self:Clear()
    self.meshFilter = nil
    self.meshRenderer = nil
    self.labelTexts = {}
end

function this:SetSortingOrder(sortingOrder)
    self.sortingOrder = sortingOrder
    if self.meshRenderer then
        self.meshRenderer.sortingOrder = sortingOrder
    end
end

return HeroRadarChart
