NoteView = {};
function NoteView:new()
    local o={}
    setmetatable(o,NoteView)
    NoteView.__index = NoteView
    return o
end


--启动事件--
function NoteView:Awake(obj)
	self.gameObject = obj;
	self.transform = obj.transform;

	self:InitPanel();	
	logWarn("Awake lua--->>".. self.gameObject.name);
end

function NoteView:Destroy()
	logWarn("OnDestroy---->>>");
	GameObject.DestroyImmediate(self.gameObject);
	self.gameObject = nil;
	self.transform = nil;

	for i,v in pairs(self) do
		self[i] = nil;
	end

	self = nil;
end

--初始化面板--
function NoteView:InitPanel()
	self.Img_Note = self.gameObject:GetComponent("Image");
	self.Txt_Number = Util.GetGameObject(self.transform,"Number"):GetComponent("Text");
end


function NoteView:RefreshNote(rank, number)

	local spriteName = "ChouMa_" .. tostring(rank);
	local sprite = Util.LoadSprite(spriteName);
	
	self.Img_Note.sprite = sprite;
	self.Txt_Number.text = number;
end