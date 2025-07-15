local FightEffectAudioConfig = {}
local this = FightEffectAudioConfig

function FightEffectAudioConfig.Init()
    if not this.config then
        this.config = {}
        local audioConfig = ConfigManager.GetConfig(ConfigName.AudioConfig)
        for _, data in ConfigPairs(audioConfig) do
            if data.Type == 4 or data.Type == 5 or data.Type == 6 or data.Type == 7 then
                if not data.EffectName or data.EffectName == "" then
                    
                else
                    local effectNameList = string.split(data.EffectName, "#")
                    for _, effectName in ipairs(effectNameList) do
                        -- if this.config[effectName] then
                        
                        -- else
                        --     this.config[effectName] = {name = data.Name}
                        -- end

                        if not this.config[effectName] then
                            this.config[effectName] = {}
                        end
                        table.insert(this.config[effectName], {name = data.Name})
                    end
                end
            end
        end
    end
end

function FightEffectAudioConfig.GetAudioData(effectName)
    if not this.config then
        this.Init()
    end
    local data = this.config[effectName]
    if not data or #data == 0 then 
        if effectName ~= "FloatingText" and effectName ~= "BuffFloatingText" and effectName ~= "fx_Effect_enemy_birth" then
            
        end
        return 
    end
    return data[math.random(1, #data)]
end

return FightEffectAudioConfig