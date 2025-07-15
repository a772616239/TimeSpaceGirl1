local MsgParser = require("BadWords/MsgParser")
print("---------------------------------------------------------------")
local s = MsgParser:getString("刘少奇cc毛泽东xxaab 江泽民  bcfuck")
logWarn(s)