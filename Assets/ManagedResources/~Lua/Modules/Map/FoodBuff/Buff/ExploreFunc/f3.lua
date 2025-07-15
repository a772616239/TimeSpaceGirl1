---
--- 扎营次数buff
---
local ExploreFunc_StopCount = {}
local this = ExploreFunc_StopCount
this.fid = 3
this.config = ConfigManager.GetConfig(ConfigName.ExploreFunctionConfig)[this.fid]

-- buff开始回调
function this:Start(count)
    if count then
        MapManager.stopCount = MapManager.stopCount + count
    end
end

-- buff结束时回到默认
function this:End()

end

return this