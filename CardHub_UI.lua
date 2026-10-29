--[[
	CardHub_UI.lua : หน้า "หน้าจอ" (ทำให้ใช้งานง่ายทั้งจอเล็กและจอใหญ่)

	  1) ขนาดเมนู      : ปรับ % ได้ + ปุ่มลัด เล็ก/กลาง/ใหญ่/ใหญ่มาก
	  2) แถบควบคุมด่วน : แถบเล็กลอยบนจอ ลากย้ายได้ มีปุ่มเปิด/ปิดออโต้ที่ใช้บ่อย
	                    กดได้เลยโดยไม่ต้องเปิดเมนูใหญ่ (ย่อเป็นปุ่มเดียวได้)
	  3) ปุ่มช่วย      : ย่อเมนู / รีเซ็ตตำแหน่ง / หยุดออโต้ทั้งหมด / ซ่อนเมนูอัตโนมัติ

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
]]
local H = ...
local Window = H.Window
local UIS = H.UIS
local Library = H.Library

local Page = Window:CreatePage({ Name = "หน้าจอ" })
local SecSize = Page:CreateSection({ Name = "ขนาดเมนู", Side = 1, Collapsed = false })
local SecBar  = Page:CreateSection({ Name = "แถบควบคุมด่วน", Side = 2, Collapsed = false })
local SecTool = Page:CreateSection({ Name = "ปุ่มช่วย", Side = 1, Collapsed = false })

----------------------------------------------------------------------
-- 1) ขนาดเมนู (ใช้ฟังก์ชันของไลบรารี: ค่ายิ่งน้อยเมนูยิ่งใหญ่)
----------------------------------------------------------------------
local function applyScale(pct)
	local v = math.clamp(math.floor(100000 / math.max(40, pct)), 300, 1400)
	pcall(function() Library:SetScaleNumeric(v) end)
end

local sizeSlider = H.slider(SecSize, "ขนาดเมนู", "MenuPct", 60, 220, 100, "%", applyScale)

local function preset(pct)
	pcall(function() sizeSlider:SetValue(pct) end)
	H.State.MenuPct = pct
	applyScale(pct)
end

SecSize:Button():Add("เล็ก", function() preset(80) end):Add("กลาง", function() preset(100) end)
SecSize:Button():Add("ใหญ่", function() preset(140) end):Add("ใหญ่มาก", function() preset(190) end)

SecSize:Label({
	Name = "คำแนะนำ",
	Description = "จอมือถือเล็กแล้วตัวหนังสือเล็กเกินไป ให้กด ใหญ่ ส่วนจอใหญ่/แท็บเล็ตให้กด กลาง หรือ เล็ก",
})

----------------------------------------------------------------------
-- 2) แถบควบคุมด่วน
----------------------------------------------------------------------
local ITEMS = {
	{ "AutoCollect", "เก็บแพ็ก" },
	{ "CashPro",     "เก็บเงิน" },
	{ "DgAuto",      "ดันเจี้ยน" },
	{ "AutoClick",   "ออโต้คลิก" },
	{ "AutoGui",     "กดปุ่มเกม" },
}

local host = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
	local old = host:FindFirstChild("CardHubQuick")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CardHubQuick"
gui.ResetOnSpawn = false
gui.DisplayOrder = 998
gui.Parent = host

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(1, 0)
root.Position = UDim2.new(1, -8, 0.28, 0)
root.Size = UDim2.new(0, 104, 0, 0)
root.AutomaticSize = Enum.AutomaticSize.Y
root.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
root.BackgroundTransparency = 0.12
root.BorderSizePixel = 0
root.Parent = gui
Instance.new("UICorner", root).CornerRadius = UDim.new(0, 8)

local scale = Instance.new("UIScale", root)
scale.Scale = 1

local rl = Instance.new("UIListLayout", root)
rl.Padding = UDim.new(0, 3)
rl.SortOrder = Enum.SortOrder.LayoutOrder
local rp = Instance.new("UIPadding", root)
rp.PaddingTop, rp.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
rp.PaddingLeft, rp.PaddingRight = UDim.new(0, 4), UDim.new(0, 4)

-- หัวแถบ (ลากตรงนี้เพื่อย้ายตำแหน่ง)
local head = Instance.new("Frame")
head.Size = UDim2.new(1, 0, 0, 30)
head.BackgroundTransparency = 1
head.LayoutOrder = 0
head.Active = true
head.Parent = root

local grip = Instance.new("TextLabel")
grip.Size = UDim2.new(1, -62, 1, 0)
grip.BackgroundTransparency = 1
grip.Font = Enum.Font.GothamBold
grip.TextSize = 12
grip.TextColor3 = Color3.fromRGB(160, 170, 200)
grip.Text = "ลากย้าย"
grip.Parent = head

local function mini(text, xOff, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 28, 0, 28)
	b.Position = UDim2.new(1, xOff, 0, 1)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = head
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end
local bMenu = mini("☰", -58, Color3.fromRGB(50, 90, 160))
local bFold = mini("−", -28, Color3.fromRGB(70, 70, 90))

local list = Instance.new("Frame")
list.Size = UDim2.new(1, 0, 0, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundTransparency = 1
list.LayoutOrder = 1
list.Parent = root
local ll = Instance.new("UIListLayout", list)
ll.Padding = UDim.new(0, 3)

local ON  = Color3.fromRGB(40, 150, 80)
local OFF = Color3.fromRGB(55, 58, 75)

local buttons = {}
local function setKey(key, v)
	local t = H.Toggles and H.Toggles[key]
	if t then
		local ok = pcall(function() t:SetValue(v) end)
		if ok then return end
	end
	H.State[key] = v
end

for i, it in ipairs(ITEMS) do
	local key, label = it[1], it[2]
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 32)
	b.BackgroundColor3 = OFF
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = label
	b.LayoutOrder = i
	b.Parent = list
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.Activated:Connect(function() setKey(key, not H.State[key]) end)
	buttons[key] = b
end

local bStop = Instance.new("TextButton")
bStop.Size = UDim2.new(1, 0, 0, 30)
bStop.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
bStop.TextColor3 = Color3.new(1, 1, 1)
bStop.Font = Enum.Font.GothamBold
bStop.TextSize = 12
bStop.Text = "หยุดทั้งหมด"
bStop.LayoutOrder = 99
bStop.Parent = list
Instance.new("UICorner", bStop).CornerRadius = UDim.new(0, 6)

local function stopAll()
	for _, it in ipairs(ITEMS) do
		if H.State[it[1]] then setKey(it[1], false) end
	end
	H.notify("Card Hub", "หยุดออโต้ทั้งหมดแล้ว", 2)
end
bStop.Activated:Connect(stopAll)

-- เปิด/ปิดเมนูหลัก
local function toggleMenu()
	pcall(function() Window:SetOpen(not Window.IsOpen) end)
end
bMenu.Activated:Connect(toggleMenu)
bFold.Activated:Connect(function()
	list.Visible = not list.Visible
	bFold.Text = list.Visible and "−" or "+"
end)

-- ลากย้ายที่หัวแถบ (รองรับทั้งนิ้วและเมาส์)
local dragging, dragStart, startPos
head.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPos = true, i.Position, root.Position
		i.Changed:Connect(function()
			if i.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
H.conn(UIS.InputChanged, function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = i.Position - dragStart
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

H.onStop(function() pcall(function() gui:Destroy() end) end)

-- อัปเดตสีปุ่มตามสถานะจริง (ซิงก์กับสวิตช์ในเมนูตลอด) + ซ่อนเมนูอัตโนมัติ
local prev = {}
task.spawn(function()
	while H.Alive do
		local turnedOn = false
		for key, b in pairs(buttons) do
			local on = H.State[key] == true
			b.BackgroundColor3 = on and ON or OFF
			if on and not prev[key] then turnedOn = true end
			prev[key] = on
		end
		if turnedOn and H.State.AutoHide then
			pcall(function() if Window.IsOpen then Window:SetOpen(false) end end)
		end
		task.wait(0.4)
	end
end)

----------------------------------------------------------------------
-- ตั้งค่าแถบด่วนในเมนู
----------------------------------------------------------------------
H.toggle(SecBar, "แสดงแถบควบคุมด่วน", "QuickShow", true, function(v) gui.Enabled = v end)
H.slider(SecBar, "ขนาดแถบ", "QuickScale", 70, 170, 100, "%", function(v) scale.Scale = v / 100 end)
H.toggle(SecBar, "ซ่อนเมนูอัตโนมัติเมื่อเปิดออโต้", "AutoHide", false, nil,
	"พอกดเปิดออโต้ตัวไหน เมนูใหญ่จะหุบเอง เหลือแต่แถบด่วน")
SecBar:Button():Add("รีเซ็ตตำแหน่งแถบ", function()
	root.Position = UDim2.new(1, -8, 0.28, 0)
end)

----------------------------------------------------------------------
-- ปุ่มช่วย
----------------------------------------------------------------------
H.toggle(SecTool, "ซ่อนปุ่มลอยเดิมของเมนู", "HideFloat", false, function(v)
	pcall(function()
		local fb = Library.FloatingButton
		if fb then fb.Visible = not v end
	end)
end, "ใช้ปุ่ม ☰ บนแถบด่วนแทน (เล็กกว่า ไม่บังจอ)")

SecTool:Button():Add("ย่อเมนู", function()
	pcall(function() Window:SetOpen(false) end)
end):Add("รีเซ็ตตำแหน่งเมนู", function()
	pcall(function() Library:ResetPositions() end)
end)
SecTool:Button():Add("หยุดออโต้ทั้งหมด", stopAll)

SecTool:Label({
	Name = "ลืมวิธีเปิดเมนู?",
	Description = "กดปุ่ม ☰ บนแถบด่วน หรือปุ่มลอยของเมนู ถ้าแถบหาย ให้เปิดเมนูแล้วเปิด แสดงแถบควบคุมด่วน ที่หน้านี้",
})

H.onStop(function()
	pcall(function()
		local fb = Library.FloatingButton
		if fb then fb.Visible = true end
	end)
end)
