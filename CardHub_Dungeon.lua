--[[
	CardHub_Dungeon.lua : หน้า "ดันเจี้ยน" (ออโต้ Card Battle)

	ระบบนี้ทำงานผ่านหน้าต่างของเกมเอง (CardBattleGui) ไม่ยิง remote ที่ไม่รู้อาร์กิวเมนต์:
	  1) เข้าอารีนา  : แตะกล่อง CardBattleHitbox (ที่ Workspace.CardBattleArena) ให้หน้าต่างเปิด
	  2) เลือกทีม    : ถ้าช่องทีมว่าง จะกดการ์ดในลิสต์เข้าช่องให้ครบ 3 ใบ
	  3) เริ่มรอบ    : กดปุ่ม Start
	  4) ต่อสู้      : กดปุ่ม Fight ซ้ำทุกครั้งที่ปุ่มโผล่ (ไม่ต้องมานั่งกด)
	  5) Cash Out    : กดเก็บรางวัลเมื่อเลือดทีมต่ำ (กันแพ้แล้วรางวัลหาย) หรือทุกครั้ง ตามที่ตั้ง
	  แล้ววนกลับไปข้อ 2 เอง จนกว่าจะปิดสวิตช์

	ชื่อวัตถุที่ใช้อ่านจากไฟล์ dump ของแมพ:
	  CardBattleGui.MainFrame.SelectFrame.RightPanel.{SlotsFrame, StartButton}
	  CardBattleGui.MainFrame.BattleFrame.{FightButton, CashOutButton, AutoButton, SpeedButton,
	                                       PlayerRow, RewardsPanel.PendingList}
	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
]]
local H = ...
local Window = H.Window
local Workspace = H.Workspace
local PlayerGui = H.lp:WaitForChild("PlayerGui")

H.Stats.Battles = H.Stats.Battles or 0   -- จำนวนครั้งที่กด Fight
H.Stats.Runs = H.Stats.Runs or 0         -- จำนวนรอบที่เริ่ม
H.Stats.CashOuts = H.Stats.CashOuts or 0 -- จำนวนครั้งที่ Cash Out

local Page = Window:CreatePage({ Name = "ดันเจี้ยน" })
local SecMain = Page:CreateSection({ Name = "ออโต้ดันเจี้ยน", Side = 1, Collapsed = false })
local SecOpt  = Page:CreateSection({ Name = "ตัวเลือกการต่อสู้", Side = 2, Collapsed = false })
local SecTool = Page:CreateSection({ Name = "เครื่องมือ", Side = 1, Collapsed = false })

----------------------------------------------------------------------
-- ตัวช่วยอ่านหน้าต่างของเกม
----------------------------------------------------------------------
local function gui() return PlayerGui:FindFirstChild("CardBattleGui") end

-- node("MainFrame.BattleFrame.FightButton") → วัตถุตามเส้นทาง (หรือ nil)
local function node(path)
	local o = gui()
	for part in path:gmatch("[^%.]+") do
		o = o and o:FindFirstChild(part)
	end
	return o
end

-- ปุ่มที่มองเห็นอยู่จริง (ไม่ซ่อน/ไม่ถูกปิด) ถ้าไม่เห็นคืน nil
local function btn(path)
	local b = node(path)
	if b and b:IsA("GuiButton") and H.shown(b) then return b end
	return nil
end

local function selectVisible()
	local f = node("MainFrame.SelectFrame")
	return f ~= nil and H.shown(f)
end
local function battleVisible()
	local f = node("MainFrame.BattleFrame")
	return f ~= nil and H.shown(f)
end

-- ข้อความของปุ่ม (ปุ่มของเกมใช้ TextLabel ชื่อ Title ซ้อนอยู่ข้างใน)
local function btnText(b)
	if not b then return "" end
	local t = b:FindFirstChild("Title", true)
	if t and t:IsA("TextLabel") then return t.Text end
	if b:IsA("TextButton") then return b.Text end
	return ""
end

-- สัดส่วนเลือดเฉลี่ยของทีมเรา (0..1) อ่านจากความกว้างแถบ Fill ของแต่ละตัว
local function teamRatio()
	local row = node("MainFrame.BattleFrame.PlayerRow")
	if not row then return nil end
	local sum, n = 0, 0
	for i = 1, 3 do
		local f = row:FindFirstChild("Fighter" .. i)
		local fill = f and f:FindFirstChild("Fill", true)
		if fill and fill:IsA("GuiObject") then
			sum = sum + math.clamp(fill.Size.X.Scale, 0, 1)
			n = n + 1
		end
	end
	if n == 0 then return nil end
	return sum / n
end

-- มีรางวัลรอ (Pending) อยู่ไหม
local function hasPending()
	local l = node("MainFrame.BattleFrame.RewardsPanel.PendingList")
	if not (l and l:IsA("TextLabel")) then return true end -- อ่านไม่ได้ → ถือว่ามี (ปลอดภัยกว่า)
	local t = l.Text:gsub("%s+", "")
	if #t == 0 then return false end
	if t:find("^%-+$") then return false end
	local low = t:lower()
	if low:find("none") or low:find("empty") or t:find("ไม่มี") then return false end
	return true
end

----------------------------------------------------------------------
-- เข้าอารีนา (แตะกล่อง CardBattleHitbox)
----------------------------------------------------------------------
local hitbox
local function findHitbox()
	if hitbox and hitbox.Parent then return hitbox end
	local arena = Workspace:FindFirstChild("CardBattleArena", true)
	hitbox = arena and arena:FindFirstChild("CardBattleHitbox", true)
	return hitbox
end

local function isOpen()
	local g = gui()
	local m = g and g:FindFirstChild("MainFrame")
	return g ~= nil and g.Enabled and m ~= nil and m.Visible
end

local lastEnter = 0
local function enterArena()
	if os.clock() - lastEnter < 10 then return end
	lastEnter = os.clock()
	local hb, hrp = findHitbox(), H.hrp()
	if not (hb and hrp) then
		H.err("dungeon", "ไม่พบ CardBattleHitbox")
		return
	end
	-- วิธีที่ 1: ส่งสัญญาณแตะ (ไม่ต้องขยับตัว)
	if firetouchinterest then
		pcall(firetouchinterest, hrp, hb, 0)
		task.wait(0.1)
		pcall(firetouchinterest, hrp, hb, 1)
		task.wait(1)
	end
	if isOpen() then return end
	-- วิธีที่ 2: วาร์ปไปยืนบนกล่องแล้วกลับที่เดิม
	local home = hrp.CFrame
	hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0)
	task.wait(0.6)
	local h2 = H.hrp()
	if h2 and not isOpen() then task.wait(0.6) end
	if h2 then h2.CFrame = home end
end

----------------------------------------------------------------------
-- หน้าเลือกทีม
----------------------------------------------------------------------
local function slotFilled(i)
	local s = node("MainFrame.SelectFrame.RightPanel.SlotsFrame.Slot" .. i)
	local holder = s and s:FindFirstChild("CardHolder")
	if not holder then return false end
	for _, c in ipairs(holder:GetChildren()) do
		if c:IsA("GuiObject") then return true end
	end
	return false
end

local function filledCount()
	local n = 0
	for i = 1, 3 do if slotFilled(i) then n = n + 1 end end
	return n
end

-- หาปุ่มที่กดได้ของการ์ดแต่ละใบในลิสต์
local function cardButtons()
	local scroll = node("MainFrame.SelectFrame.CardsScroll")
	local out = {}
	if not scroll then return out end
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIGridLayout") then
			local b = c:IsA("GuiButton") and c or c:FindFirstChildWhichIsA("GuiButton", true)
			if b then out[#out + 1] = b end
		end
	end
	return out
end

local function fillTeam()
	local need = 3 - filledCount()
	if need <= 0 then return end
	local list = cardButtons()
	if #list == 0 then return end
	local fromEnd = H.State.DgPick == "จากท้ายสุด"
	local idx = fromEnd and #list or 1
	local step = fromEnd and -1 or 1
	local tries = 0
	while need > 0 and idx >= 1 and idx <= #list and tries < 12 and H.Alive do
		local b = list[idx]
		if b and b.Parent then
			H.clickGui(b)
			task.wait(0.35)
			local now = 3 - filledCount()
			if now < need then need = now end
		end
		idx = idx + step
		tries = tries + 1
	end
end

----------------------------------------------------------------------
-- ลูปหลักของระบบออโต้
----------------------------------------------------------------------
local session = { auto = false, speed = false }
local lastStart, lastFight = 0, 0

local function tickSelect()
	-- เริ่มรอบใหม่ → ให้ตั้ง Auto/Speed ใหม่ได้อีกครั้ง
	session.auto, session.speed = false, false
	if H.State.DgTeam then fillTeam() end
	if H.State.DgStart and os.clock() - lastStart > 3 then
		local b = btn("MainFrame.SelectFrame.RightPanel.StartButton")
		if b and (not H.State.DgTeam or filledCount() >= 1) then
			H.clickGui(b)
			lastStart = os.clock()
			H.Stats.Runs = H.Stats.Runs + 1
		end
	end
end

local function tickBattle()
	-- 1) เปิดปุ่ม Auto / Speed ของเกมให้ (ครั้งเดียวต่อรอบ)
	if H.State.DgAutoBtn and not session.auto then
		local b = btn("MainFrame.BattleFrame.AutoButton")
		if b then
			-- อ่านสถานะจากข้อความปุ่ม (ภาษาอังกฤษเท่านั้น: มี "off" = ปิดอยู่, มี "on" = เปิดอยู่)
			local txt = btnText(b):lower()
			local isOff = txt:find("off") ~= nil
			local isOn = txt:find("on") ~= nil and not isOff
			if not isOn then H.clickGui(b) end
			session.auto = true
			task.wait(0.2)
		end
	end
	if H.State.DgSpeed and not session.speed then
		local b = btn("MainFrame.BattleFrame.SpeedButton")
		if b then
			H.clickGui(b)
			session.speed = true
			task.wait(0.2)
		end
	end

	-- 2) Cash Out
	local mode = H.State.DgCashMode
	local co = btn("MainFrame.BattleFrame.CashOutButton")
	if co and mode ~= "ไม่กดเอง" then
		local doIt = false
		if mode == "ทุกครั้งที่ปุ่มโผล่" then
			doIt = true
		else -- "เมื่อเลือดทีมต่ำ"
			local r = teamRatio()
			if r and r * 100 <= (H.State.DgHp or 35) and hasPending() then doIt = true end
		end
		if doIt then
			H.clickGui(co)
			H.Stats.CashOuts = H.Stats.CashOuts + 1
			task.wait(0.6)
			return
		end
	end

	-- 3) ต่อสู้ต่อ (Fight)
	if H.State.DgFight and os.clock() - lastFight >= (H.State.DgFightGap or 0.8) then
		local f = btn("MainFrame.BattleFrame.FightButton")
		if f then
			H.clickGui(f)
			lastFight = os.clock()
			H.Stats.Battles = H.Stats.Battles + 1
		end
	end
end

H.loop("DgAuto", function() return H.State.DgTick or 0.8 end, function()
	if battleVisible() then
		tickBattle()
	elseif selectVisible() and isOpen() then
		tickSelect()
	elseif not isOpen() then
		-- หน้าต่างไม่ได้เปิดอยู่
		local badge = PlayerGui:FindFirstChild("CardBattleBadgeGui")
		badge = badge and badge:FindFirstChild("BattleBadge")
		if badge and badge:IsA("GuiButton") and H.shown(badge) and H.State.DgBadge then
			H.clickGui(badge)
			task.wait(1)
		end
		if not isOpen() and H.State.DgEnter then enterArena() end
	end
end)

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
H.toggle(SecMain, "ออโต้ดันเจี้ยน (เปิดตัวนี้ตัวเดียวก็ทำงาน)", "DgAuto", false, nil,
	"เข้าอารีนา → เลือกทีม → เริ่ม → ต่อสู้ → เก็บรางวัล วนซ้ำเอง")
H.toggle(SecMain, "เข้าอารีนาเองเมื่อหน้าต่างปิด", "DgEnter", true)
H.toggle(SecMain, "เลือกการ์ดเข้าทีมเอง (ถ้าช่องว่าง)", "DgTeam", true, nil,
	"ถ้าเกมจำทีมเดิมไว้ให้อยู่แล้ว จะไม่เลือกซ้ำ")
H.toggle(SecMain, "กดเริ่มรอบเอง (Start)", "DgStart", true)
H.toggle(SecMain, "กดต่อสู้เอง (Fight) ทุกครั้ง", "DgFight", true, nil,
	"กดปุ่ม Fight ซ้ำทุกครั้งที่ปุ่มโผล่ ไม่ต้องมานั่งกด")
H.dropdown(SecMain, "ลำดับเลือกการ์ด", "DgPick", { "จากบนสุด", "จากท้ายสุด" }, "จากบนสุด", false)

H.toggle(SecOpt, "เปิดปุ่ม Auto ของเกมให้", "DgAutoBtn", true, nil,
	"กดปุ่ม Auto ในหน้าต่างต่อสู้ครั้งเดียวต่อรอบ (ถ้ายังไม่เปิด)")
H.toggle(SecOpt, "เร่งความเร็วการต่อสู้ (Speed)", "DgSpeed", false)
H.dropdown(SecOpt, "Cash Out (เก็บรางวัลที่รอ)", "DgCashMode",
	{ "ไม่กดเอง", "เมื่อเลือดทีมต่ำ", "ทุกครั้งที่ปุ่มโผล่" }, "เมื่อเลือดทีมต่ำ", false)
H.slider(SecOpt, "เลือดทีมต่ำกว่า", "DgHp", 5, 80, 35, "%")
H.slider(SecOpt, "ตรวจทุก", "DgTick", 0.3, 3, 0.8, " วิ")
H.slider(SecOpt, "เว้นช่วงระหว่าง Fight", "DgFightGap", 0.3, 4, 0.8, " วิ")
H.toggle(SecOpt, "กดปุ่ม BattleBadge ถ้ามี", "DgBadge", true, nil,
	"ปุ่มเปิดหน้าต่างต่อสู้ที่เกมโชว์บนจอ")

local L_run = SecTool:Label("รอบที่เริ่ม: 0")
local L_bat = SecTool:Label("Fight ที่กด: 0")
local L_co  = SecTool:Label("Cash Out: 0")
local L_st  = SecTool:Label("สถานะ: -")

task.spawn(function()
	while H.Alive do
		local st = "ปิดหน้าต่าง"
		if battleVisible() then
			local r = teamRatio()
			st = "กำลังต่อสู้" .. (r and (" (เลือดทีม " .. math.floor(r * 100) .. "%)") or "")
		elseif selectVisible() and isOpen() then
			st = "หน้าเลือกทีม " .. filledCount() .. "/3"
		end
		pcall(function()
			L_run:SetText("รอบที่เริ่ม: " .. H.Stats.Runs)
			L_bat:SetText("Fight ที่กด: " .. H.Stats.Battles)
			L_co:SetText("Cash Out: " .. H.Stats.CashOuts)
			L_st:SetText("สถานะ: " .. st)
		end)
		task.wait(1)
	end
end)

SecTool:Button():Add("เข้าอารีนาตอนนี้", function()
	lastEnter = 0
	task.spawn(enterArena)
end):Add("วาร์ปไปอารีนา", function()
	local hb = findHitbox()
	if hb then H.tp(hb.Position + Vector3.new(0, 4, 8)) else H.notify("ดันเจี้ยน", "ไม่พบอารีนาในแมพนี้", 3) end
end)

SecTool:Button():Add("รับรางวัลต่อสู้ (remote)", function()
	H.fire("ClaimBattleRewards")
	H.notify("ดันเจี้ยน", "ส่งคำขอรับรางวัลแล้ว", 2)
end):Add("ล้างตัวนับ", function()
	H.Stats.Runs, H.Stats.Battles, H.Stats.CashOuts = 0, 0, 0
end)

SecTool:Label({
	Name = "วิธีใช้",
	Description = "เปิด ออโต้ดันเจี้ยน แล้วปล่อยได้เลย ถ้าเกมไม่เลือกทีมให้ ให้เลือกการ์ด 3 ใบเองครั้งแรก 1 ครั้ง ระบบจะกด Start/Fight ต่อให้ทุกรอบ",
})
