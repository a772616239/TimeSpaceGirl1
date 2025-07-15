local JumpConfig = ConfigManager.GetConfig(ConfigName.JumpConfig)
JumpView = {}
function JumpView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b,{ __index = JumpView })
    return b
end
--初始化组件（用于子类重写）
function JumpView:InitComponent()
    self.icon = Util.GetGameObject(self.gameObject, "Image_Icon"):GetComponent("Image")
    self.info = Util.GetGameObject(self.gameObject, "info"):GetComponent("Text")
    self.btnSure = Util.GetGameObject(self.gameObject, "btnSure")
    -- self.btnSureText = Util.GetGameObject(self.gameObject, "btnSure/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function JumpView:BindEvent()
end

--添加事件监听（用于子类重写）
function JumpView:AddListener()
end

--移除事件监听（用于子类重写）
function JumpView:RemoveListener()
end

--界面打开时调用（用于子类重写）
function JumpView:OnOpen(jumpId, isRewardItemPop, isHeroJump)
    self.jumpId, self.isRewardItemPop, self.isHeroJump = jumpId, isRewardItemPop, isHeroJump
    if self.isHeroJump then
        if type(self.jumpId) == "number" then
            self.jumpSData = JumpConfig[self.jumpId]
            if self.jumpSData then
                self.icon.sprite = Util.LoadSprite(self.jumpSData.IconName)
                self.info.text = GetLanguageStrById(self.jumpSData.Title)
                Util.AddOnceClick(self.btnSure, function()
                    if UIManager.IsOpen(UIName.JumpSelectPopup) then
                        UIManager.ClosePanel(UIName.JumpSelectPopup)
                    end
                    JumpManager.GoJump(self.jumpSData.Id)
                end)
            end
        else
            self.jumpSData = JumpConfig[99998]
            self.icon.sprite = Util.LoadSprite(self.jumpSData.IconName)
            self.info.text = GetLanguageStrById(self.jumpSData.Title)
            Util.AddOnceClick(self.btnSure, function()
                if UIManager.IsOpen(UIName.JumpSelectPopup) then
                    UIManager.ClosePanel(UIName.JumpSelectPopup)
                end
                if self.jumpId == nil then
                    UIManager.OpenPanel(UIName.AssemblePanel)
                else
                    UIManager.OpenPanel(UIName.AssemblePanel, self.jumpId)
                end
            end)
        end
    else
        if self.jumpId == 36006 then
            if not ShopManager.SetMainRechargeJump() then
                self.jumpId = 36008
            end
        end
        self.jumpSData = JumpConfig[self.jumpId]
        if self.jumpSData then
            self.icon.sprite = Util.LoadSprite(self.jumpSData.IconName)
            self.info.text = GetLanguageStrById(self.jumpSData.Title)
            -- self.btnSureText.text = GetLanguageStrById(10509)
            Util.AddOnceClick(self.btnSure, function()
                if UIManager.IsOpen(UIName.RewardItemPopup) then
                    UIManager.ClosePanel(UIName.RewardItemPopup)
                end
                JumpManager.GoJump(self.jumpSData.Id)
            end)
        end
        --if MapManager.isInMap or UIManager.IsOpen(UIName.BattlePanel) or isRewardItemPop == false then-- or BagManager.isBagPanel
        if UIManager.IsOpen(UIName.BattlePanel) or self.isRewardItemPop == false then-- or BagManager.isBagPanel
            self.btnSure:SetActive(false)
        else
            self.btnSure:SetActive(true)
        end
    end
end

--界面关闭时调用（用于子类重写）
function JumpView:OnClose()
end

--界面销毁时调用（用于子类重写）
function JumpView:OnDestroy()
end

return JumpView