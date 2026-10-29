--[[
	CardHub_Teleport.lua : หน้า "วาร์ป" (วาร์ปไปจุดต่าง ๆ ในแมพ / ไปหาผู้เล่น / ไปแปลงผู้เล่น / บันทึกจุดเอง)

	พิกัดทั้งหมดอ่านมาจากไฟล์ dump ของแมพ (Workspace.Systems.Teleports ฯลฯ)
	ชื่อจุดในดรอปดาวน์เป็นภาษาไทย (มีชื่อเดิมในเกมกำกับในวงเล็บ) และใช้เป็น key ของตาราง PLACES
	ดังนั้นห้ามแก้ชื่อใน PLACES โดยไม่แก้ที่ปุ่มลัดด้านล่างให้ตรงกัน

	ฟังก์ชันของ H ที่ใช้:
	  H.tp(เป้าหมาย, ใช้tween, ความเร็ว)   วาร์ป (Vector3 หรือ CFrame)
	  H.plotSpawn([แปลง])                  จุดเกิดของแปลง (ไม่ใส่ = แปลงของเรา)
	  H.plotOf(ชื่อผู้เล่น)                 แปลงของผู้เล่นคนนั้น
]]

local H = ...
local Window = H.Window
local Players = H.Players

local Page = Window:CreatePage({ Name = "วาร์ป" })
local SecPlaces = Page:CreateSection({ Name = "สถานที่", Side = 1, Collapsed = false })
local SecPlayers = Page:CreateSection({ Name = "ผู้เล่น & จุดที่บันทึก", Side = 2, Collapsed = false })

-- ชื่อรายการพิเศษ "แปลงของฉัน" (ไม่ได้อยู่ใน PLACES เพราะตำแหน่งต่างกันในแต่ละคน ต้องคำนวณตอนกด)
local MY_PLOT = "แปลงของฉัน"

-- ตารางพิกัด: ชื่อที่แสดง = Vector3(X, Y, Z)  (Y คือความสูง)
local PLACES = {
	["จุดเกิดฮับ (Hub Spawn)"]       = Vector3.new(38, 17, 46),
	["ร้านแพ็ก (Pack Shop)"]          = Vector3.new(36, 22, 51),
	["ตลาด (Market)"]                 = Vector3.new(192, 19, 55),
	["แคลน (Clans)"]                  = Vector3.new(36, 22, 233),
	["ร้านแคลน (Clan Shop)"]          = Vector3.new(-31, 22, 233),
	["อันดับ (Leaderboards)"]         = Vector3.new(36, 21, -228),
	["ทางเข้า Obby"]                  = Vector3.new(-70, 19, 54),
	["หลุมเงิน (Money Pit)"]          = Vector3.new(460, 10, 44),
	["อารีนาดันเจี้ยน (Card Battle)"] = Vector3.new(-1, 24, 234),
	["บอร์ดบอสโลก (World Boss)"]      = Vector3.new(79, 26, -18),
	["ร้านผู้เล่น A"]                 = Vector3.new(231, 17, 31),
	["ร้านผู้เล่น B"]                 = Vector3.new(279, 17, 78),
	["ร้านผู้เล่น C"]                 = Vector3.new(211, 17, 78),
	["ร้านผู้เล่น D"]                 = Vector3.new(245, 17, 78),
}

-- รายชื่อสำหรับดรอปดาวน์: "แปลงของฉัน" อยู่บนสุด ตามด้วยจุดอื่นเรียงตามตัวอักษร
local names = { MY_PLOT }
do
	local tmp = {}
	for k in pairs(PLACES) do tmp[#tmp + 1] = k end
	table.sort(tmp)
	for _, k in ipairs(tmp) do names[#names + 1] = k end
end

-- ค่าเริ่มต้นของตัวเลือกวาร์ป
H.State.TpPlace = MY_PLOT
H.State.TpTween = false
H.State.TpSpeed = 120

-- วาร์ปไปที่ target (Vector3/CFrame) โดย label ใช้แสดงในแจ้งเตือน
local function gotoPos(target, label)
	if not target then
		H.notify("วาร์ป", "ไม่พบตำแหน่ง: " .. tostring(label), 3)
		return
	end
	if not H.hrp() then return end -- ตัวละครยังไม่พร้อม
	-- ถ้า TpTween เปิด จะค่อย ๆ เคลื่อนด้วยความเร็ว TpSpeed (หน่วย stud/วินาที) แทนการวาร์ปทันที
	local r = H.tp(target, H.State.TpTween, H.State.TpSpeed)
	if r then H.notify("วาร์ป", "ไปที่ " .. tostring(label), 2) end
end

H.dropdown(SecPlaces, "ปลายทาง", "TpPlace", names, MY_PLOT, false)
H.toggle(SecPlaces, "เคลื่อนที่นุ่มนวล (tween)", "TpTween", false, nil,
	"เคลื่อนไปแบบต่อเนื่อง ลดโอกาสโดนตรวจจับ")
H.slider(SecPlaces, "ความเร็ว tween", "TpSpeed", 40, 300, 120, " st/วิ")

SecPlaces:Button():Add("วาร์ป", function()
	local p = H.State.TpPlace
	if p == MY_PLOT then
		gotoPos(H.plotSpawn(), MY_PLOT)
	else
		gotoPos(PLACES[p], p)
	end
end):Add("ไปแปลงฉัน", function()
	gotoPos(H.plotSpawn(), MY_PLOT)
end)

-- ปุ่มลัดรายตำแหน่ง (key ต้องตรงกับชื่อใน PLACES เป๊ะ ๆ)
for _, key in ipairs({ "จุดเกิดฮับ (Hub Spawn)", "ร้านแพ็ก (Pack Shop)", "ตลาด (Market)", "หลุมเงิน (Money Pit)", "อารีนาดันเจี้ยน (Card Battle)" }) do
	SecPlaces:Button({ Name = "ไป: " .. key, Callback = function() gotoPos(PLACES[key], key) end })
end

----------------------------------------------------------------------
-- วาร์ปหาผู้เล่น
----------------------------------------------------------------------
-- รายชื่อผู้เล่นอื่นในเซิร์ฟเวอร์ (ไม่รวมตัวเอง) ใช้ "ชื่อ Roblox จริง" เพราะต้องใช้ค้นหาผู้เล่น
local function playerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= H.lp then t[#t + 1] = p.Name end
	end
	table.sort(t)
	if #t == 0 then t[1] = "(ไม่มี)" end -- ไม่มีใครเลย ใส่ placeholder (หาไม่เจอก็แค่ไม่ทำอะไร)
	return t
end

local pd = H.dropdown(SecPlayers, "ผู้เล่น", "TpPlayer", playerNames(), nil, false)

local function refreshPlayers()
	pcall(function() pd:Refresh(playerNames()) end)
end
-- มีคนเข้า/ออก ให้รีเฟรชรายชื่ออัตโนมัติ (ตอนออกรอ 0.2 วิ ให้รายชื่อในเกมอัปเดตก่อน)
H.conn(Players.PlayerAdded, refreshPlayers)
H.conn(Players.PlayerRemoving, function() task.delay(0.2, refreshPlayers) end)

SecPlayers:Button():Add("รีเฟรช", refreshPlayers):Add("ไปหาผู้เล่น", function()
	local n = H.State.TpPlayer
	local pl = n and Players:FindFirstChild(n)
	local hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
	-- CFrame.new(0,0,4) = ถอยไปด้านหลังเขา 4 หน่วย จะได้ไม่ซ้อนทับตัวกัน
	gotoPos(hrp and (hrp.CFrame * CFrame.new(0, 0, 4)), n)
end)

SecPlayers:Button({ Name = "ไปแปลงของผู้เล่น", Callback = function()
	local n = H.State.TpPlayer
	gotoPos(n and H.plotSpawn(H.plotOf(n)), (n or "?") .. " (แปลง)")
end })

----------------------------------------------------------------------
-- จุดที่บันทึกเอง
----------------------------------------------------------------------
local saved -- CFrame ที่บันทึกไว้ (nil = ยังไม่บันทึก)
SecPlayers:Button():Add("บันทึกจุด", function()
	local hrp = H.hrp()
	if hrp then
		saved = hrp.CFrame
		H.notify("วาร์ป", "บันทึกตำแหน่งปัจจุบันแล้ว", 2)
	end
end):Add("กลับไปจุดที่บันทึก", function()
	if saved then gotoPos(saved, "จุดที่บันทึก") else H.notify("วาร์ป", "ยังไม่ได้บันทึกตำแหน่ง", 2) end
end)

SecPlayers:Label({
	Name = "หมายเหตุ",
	Description = "เกมอาจเช็กระยะวาร์ป ถ้าถูกดึงกลับให้เปิด เคลื่อนที่นุ่มนวล (tween)",
})
