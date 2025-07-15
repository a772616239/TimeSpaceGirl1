----- 绑定 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local func

local btnInfos = {
    [1] = {
        name = "Naver Login",type = "naver",platformShow = UnityEngine.Application.platform == UnityEngine.RuntimePlatform.Android,
    },
    [2] = {
        name = "Apple Login",type = "apple",platformShow = UnityEngine.Application.platform == UnityEngine.RuntimePlatform.IPhonePlayer or UnityEngine.Application.platform == UnityEngine.RuntimePlatform.OSXEditor,
    },
    [3] = {
        name = "google Login",type = "google",platformShow = true,
    },
}

local btns = {}
function this:InitComponent(gameObject)
    this.content = Util.GetGameObject(gameObject, "Scroll View/Viewport/Content")
    this.prefab = Util.GetGameObject(gameObject, "Scroll View/Viewport/Content/pre")
end

function this:BindEvent()
end

function this.Hide()
    parent:ClosePanel()
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent, ...)
    parent = _parent
    local args = {...}

    for i = 1, #btns do
        btns[i]:SetActive(false)
    end
    for i, v in ipairs(btnInfos) do
        if not btns[i] then
            btns[i] = newObjToParent(this.prefab, this.content.transform)
        end
        Util.GetGameObject(btns[i].gameObject, "name"):GetComponent("Text").text = v.name
        btns[i]:SetActive(v.platformShow)

        Util.AddOnceClick(btns[i], function ()
            if AppConst.isSDKLogin then
                SDKMgr:Relation(v.type)
            end
        end)
    end
end

function this:OnClose()
end

function this:OnDestroy()
    btns= {}
end

return this