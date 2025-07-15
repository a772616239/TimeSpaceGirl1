require("Base/BasePanel")
local BattleStartPopup = Inherit(BasePanel)
local this = BattleStartPopup

local fightStartAssetName = "FightStart"
local fightStart = nil

--更换多语言资源
local material
local newName

function this:InitComponent()
end
--绑定事件（用于子类重写）
function BattleStartPopup:BindEvent()
end

function this:OnOpen(func)
    --战斗开始动画
    fightStart = poolManager:LoadAsset(fightStartAssetName, PoolManager.AssetType.GameObject)
    fightStart.transform:SetParent(this.gameObject.transform)
    fightStart.transform.localScale = Vector3.New(1, 1, 1)
    fightStart.transform.localPosition = Vector3.New(0, 0, 0)
    fightStart:SetActive(true)

    local logo = Util.GetGameObject(fightStart.gameObject, "logo"):GetComponent("MeshRenderer").materials[0]
    local name = logo:GetTexture("_TextureSample0").name
    newName = GetPictureFont(string.sub(name, 1, #(name)-3))
    material = poolManager:LoadAsset(newName, PoolManager.AssetType.Other)
    logo:SetTexture("_TextureSample0", material)

    Timer.New(function ()
        --动画结束,关闭本窗口
        UIManager.ClosePanel(UIName.BattleStartPopup, true)
    end, 1.42)
    :Start()

    --全合上的时候执行方法
    Timer.New(func, 0.66666):Start()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if fightStart ~= nil then
        poolManager:UnLoadAsset(fightStartAssetName, fightStart, PoolManager.AssetType.GameObject)
        fightStart = nil
    end

    if material ~= nil then
        poolManager:UnLoadAsset(newName, material, PoolManager.AssetType.Other)
        material = nil
    end
end

return this