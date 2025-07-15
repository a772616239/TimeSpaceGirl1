
local FoodDataConfig = ConfigManager.GetConfig(ConfigName.FoodsConfig)
local FoodBuff = {}
FoodBuff.ID = nil
FoodBuff.leftStep = nil
FoodBuff.totalStep = nil
FoodBuff.type = nil
FoodBuff.target = nil
FoodBuff.effectPara = nil
FoodBuff.desc = nil
FoodBuff.functionType = nil

-- 判断是否销毁的标志位
FoodBuff.isDestroy = false

function FoodBuff:ctor()
    -- 初始化基础数据
    self:Init()
end

function FoodBuff:Init()
    if not self.ID then

        return
    end
    -- 初始化buff步数
    local buffTblData = FoodDataConfig[self.ID]
    if not buffTblData then

        return
    end
    -- 初始化基础数据
    self.totalStep = buffTblData.Contiue
    self.leftStep = self.totalStep
    self.type = buffTblData.Type
    self.target = buffTblData.Target
    self.effectPara = buffTblData.EffectPara
    self.desc = buffTblData.Desc
    self.functionType = buffTblData.FunctionType
    self.initTime = GetTimeStamp()

    -- 调用子类创建方法
    if self.onCreate then
        self:onCreate()
    end

    -- 一次性buff
    if self.leftStep == 0 then
        -- 一次性buff 触发事件
        if self.onOnceBuff then
            self:onOnceBuff()
        end
        self.leftStep = -1
        return
    end


    -- 调用buff开始方法
    if self.onStart then
        self:onStart()
    end
end

-- 人物每走一步执行，由外部掉用
function FoodBuff:MoveStep()
    if self.leftStep <= 0 then return end
    self.leftStep = self.leftStep - 1
    -- 调用子类移动方法
    if self.onMoveStep then
        self:onMoveStep()
    end

    -- 判断buff是否结束
    if self.leftStep <= 0 then
        -- 调用buff结束方法
        if self.onEnd then
            self:onEnd()
        end
        -- 销毁buff
        self:Destroy()
    end
end

-- 强制设置剩余步数
function FoodBuff:SetLeftStep(step)
    if self.totalStep <= 0 then return end
    self.leftStep = step
end

--
-- 重置剩余步数
function FoodBuff:ResetLeftStep()
    self.leftStep = self.totalStep
    -- 永久buff
    if self.totalStep == 0 then
        self.leftStep = -1
    end
    -- 重置时间
    self.initTime = GetTimeStamp()
end



-- 销毁buff
function FoodBuff:Destroy()
    -- 调用子类销毁方法
    if self.onDestroy then
        self:onDestroy()
    end
    self.isDestroy = true
end


return FoodBuff