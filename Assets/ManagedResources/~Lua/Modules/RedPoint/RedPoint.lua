RedPointLayer = {
    Root = "Root",

    Main_Hero = "Main_Hero",
    Main_Bag = "Main_Bag",
    Main_Mail = "Main_Mail",
    Main_DiffMonster = "Main_DiffMonster",

    Bag_Item = "Bag_Item",
}

RedPoint = {}
RedPoint.__index = RedPoint

function RedPoint.New(name, parent, state)
    local instance = {}
    setmetatable(instance, RedPoint)

    instance.name = name
    instance.parent= parent
    instance.state = state
    instance.num = 0
    instance.childList = nil

    return instance
end

function RedPoint:SetState(state)
    if self.state ~= state then
        self.state = state
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.StateChange, self)
    end
    if state and self.parent ~= nil then
        self.parent:SetState(state)
    end
end

function RedPoint:GetState()
    return self.state
end

function RedPoint:GetNum()
    return self.num
end

function RedPoint:SetNum(num)
    if num ~= self.num then
        local delta = num - self.num
        if self.parent then
            self.parent:SetNum(delta + self.parent.num)
        end
        self.num = num
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.NumChange, self)
    end
end

function RedPoint:GetChild(name)
    return self.childList[name]
end

function RedPoint:AddChild(child)
    if not self.childList then
        self.childList = {}
    end
    self.childList[child.name] = child
end

function RedPoint:RemoveChild(name)
    if not self.childList then return end
    local child = self.childList[name]
    if child then
        child:Dispose()
        self.childList[name] = nil
    end
end

function RedPoint:Dispose()
    if self.childList then
        for k,v in pairs(self.childList) do
            v:Dispose()
        end
        self.childList = nil
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.PointRemove, self.name)
end

RedPointManager2 = {}
local this = RedPointManager2
local rPList

function this.Initialize()
    rPList = {}
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.PointRemove, this.OnRemoveRedPoint)
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.NumChange, function (point)
       
    end)
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.StateChange, function (point)
       
    end)
   

   
    this.AddRedPoint(RedPointLayer.Main_Bag, RedPointLayer.Root, false, 0)

   
    this.AddRedPoint(RedPointLayer.Bag_Item.."1", RedPointLayer.Main_Bag, false, 1)
   
    this.AddRedPoint(RedPointLayer.Bag_Item.."2", RedPointLayer.Main_Bag, false, 2)
   
    this.AddRedPoint(RedPointLayer.Bag_Item.."3", RedPointLayer.Main_Bag, false, 3)

   
    this.SetRedPointNum(RedPointLayer.Bag_Item.."2", 4)
   
    this.SetRedPointState(RedPointLayer.Bag_Item.."1", true)

   
    this.RemoveRedPoint(RedPointLayer.Bag_Item.."3")

   
    this.RemoveRedPoint(RedPointLayer.Main_Bag)
end

function this.AddRedPoint(name, parentName, state, num)
    local parent = rPList[parentName]
    local rp = RedPoint.New(name, parent, state)
    rPList[name] = rp
    if parent then
        parent:AddChild(rp)
    end
    rp:SetNum(num)
end

function this.OnRemoveRedPoint(name)
   
    if rPList[name] then
        rPList[name] = nil
    end
end

function this.RemoveRedPoint(name)
    local rp = rPList[name]
    if rp then
        rp:SetNum(0)
        if rp.parent then
            rp.parent:RemoveChild(rp.name)
        else
            rp:Dispose()
        end
    end
end

function this.SetRedPointNum(name, num)
    if rPList[name] then
        rPList[name]:SetNum(num)
    end
end

function this.GetRedPointNum(name)
    if rPList[name] then
        return rPList[name]:GetNum()
    end
end

function this.SetRedPointState(name, state)
    if rPList[name] then
        rPList[name]:SetState(state)
    end
end

function this.GetRedPointState(name)
    if rPList[name] then
        return rPList[name]:GetState()
    end
end

return this