--[[
	CardHub_Auto.lua : หน้า "ออโต้" (เก็บแพ็ก / เงินการ์ด / รางวัล / กดปุ่ม GUI อัตโนมัติ)

	ไฟล์นี้ไม่ได้รันเอง แต่ถูกโหลดโดย CardHub.lua แล้วส่งตัวกลาง H เข้ามา
	(บรรทัด `local H = ...` คือการรับค่า H ที่ถูกส่งมาตอนเรียก fn(H))

	ตัวกลาง H (สร้างใน CardHub.lua) ที่ไฟล์นี้ใช้:
	  H.Window            หน้าต่างเมนูหลัก
	  H.lp                ผู้เล่นของเรา (LocalPlayer)
	  H.State[key]        ค่าปัจจุบันของสวิตช์/สไลเดอร์ทุกตัว (อ่านง่ายจากทุกไฟล์)
	  H.Stats             ตัวนับสถิติที่โชว์ในหน้า Info
	  H.toggle/slider/dropdown   ฟังก์ชันสร้างปุ่มสวิตช์/แถบเลื่อน/ดรอปดาวน์ พร้อมเก็บค่าลง H.State
	  H.loop(key, delay, fn)     วนเรียก fn ซ้ำ ๆ ตราบที่สวิตช์ key เปิดอยู่
	  H.fire(ชื่อ, ...)          ยิง Remote ไปยังเซิร์ฟเวอร์
	  H.press(prompt)            กดปุ่ม ProximityPrompt
	  H.clickGui(ปุ่ม)           คลิกปุ่มบนหน้าจอ (GUI)
	  H.notify(หัวข้อ, ข้อความ, วินาที)   แจ้งเตือนมุมจอ
]]

local H = ...
local Window = H.Window
local PlayerGui = H.lp:WaitForChild("PlayerGui") -- ที่เก็บ GUI ทั้งหมดของเรา ใช้ค้นหาปุ่มในเกม

-- สร้างหน้า "ออโต้" และแบ่งเป็น 2 กล่อง (Side 1 = ซ้าย, Side 2 = ขวา)
-- Collapsed = false คือเปิดกล่องค้างไว้ตั้งแต่แรก
local Page = Window:CreatePage({ Name = "ออโต้" })
local SecCollect = Page:CreateSection({ Name = "เก็บของ", Side = 1, Collapsed = false })
local SecReward  = Page:CreateSection({ Name = "รางวัล & ปุ่มหน้าจอ", Side = 2, Collapsed = false })

----------------------------------------------------------------------
-- 1) เก็บแพ็กอัตโนมัติ
--    หลักการ: แพ็กที่วางในแปลงเรามี ProximityPrompt (ปุ่มกด E) ที่เขียนว่า "Collect"
--    สคริปต์จะหา prompt เหล่านั้นแล้วกดให้ทีละอัน
----------------------------------------------------------------------

-- ตารางจำว่า "prompt ไหนกดล่าสุดเมื่อไหร่" เพื่อทำคูลดาวน์ต่อแพ็ก
-- __mode = "k" คือ weak key: ถ้า prompt ถูกลบจากเกม ข้อมูลนี้จะถูกเก็บกวาดเอง ไม่รั่วหน่วยความจำ
local lastFire = setmetatable({}, { __mode = "k" })

-- คืนค่า 2 อย่าง: (รายการ prompt ที่กดได้, เจอแปลงหรือไม่)
local function getCollectPrompts()
	local plot = H.myPlot() -- แปลงของเรา = Workspace.Map.PlotModels[ชื่อเรา]
	if not plot then return {}, false end
	-- ถ้ามีโฟลเดอร์ Systems/PlacedPacks ให้ค้นเฉพาะในนั้น (เร็วกว่า) ไม่งั้นค้นทั้งแปลง
	local root = plot:FindFirstChild("Systems")
	root = root and root:FindFirstChild("PlacedPacks") or plot
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		-- เลือกเฉพาะ ProximityPrompt ที่เปิดอยู่และข้อความปุ่มตรงกับ "Collect" (ชื่อใน "เกม" ห้ามแปล)
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
			out[#out + 1] = d
		end
	end
	return out, true
end

local warnedNoPlot = false -- กันแจ้งเตือน "หาแปลงไม่เจอ" ซ้ำรัว ๆ ให้เตือนครั้งเดียว
local function collectAll()
	local prompts, found = getCollectPrompts()
	if not found then
		if not warnedNoPlot then
			warnedNoPlot = true
			H.notify("เก็บแพ็กอัตโนมัติ", "หาแปลงของคุณไม่เจอ (Map.PlotModels." .. H.lp.Name .. ")", 5)
		end
		return
	end
	warnedNoPlot = false
	local hrp = H.hrp() -- HumanoidRootPart = จุดกลางลำตัวตัวละคร ใช้อ้างตำแหน่ง
	if not hrp then return end

	local now = os.clock()
	local home, moved -- home = ตำแหน่งเดิมก่อนวาร์ป, moved = มีการวาร์ปไปหรือยัง
	for _, p in ipairs(prompts) do
		-- ถ้าตั้งคูลดาวน์ไว้ และแพ็กนี้เพิ่งถูกกดไปไม่นาน ให้ข้าม
		if H.State.CollectPerPrompt and lastFire[p] and now - lastFire[p] < H.State.CollectPerPrompt then
			-- ข้าม: เพิ่งกดไป
		else
			local pos = H.promptPos(p) -- พิกัดของแพ็กนั้น
			if pos then
				-- เซิร์ฟเวอร์มักเช็กระยะ จึงต้องอยู่ใกล้กว่า MaxActivationDistance (ลบ 1.5 เผื่อไว้)
				local far = (hrp.Position - pos).Magnitude > ((p.MaxActivationDistance or 10) - 1.5)
				if far and H.State.WalkNear then
					home = home or hrp.CFrame -- จำตำแหน่งเดิมไว้ครั้งแรกครั้งเดียว
					hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0)) -- วาร์ปไปเหนือแพ็กนิดหน่อย
					moved = true
					task.wait(0.12) -- รอให้ตำแหน่งซิงก์กับเซิร์ฟเวอร์
				end
				H.press(p)
				lastFire[p] = os.clock()
				H.Stats.Collected = H.Stats.Collected + 1
				task.wait(0.05)
			end
		end
	end
	-- กดครบแล้ว ถ้าเปิด "กลับที่เดิม" ให้วาร์ปกลับตำแหน่งเดิม
	if moved and home and H.State.ReturnBack then
		task.wait(0.05)
		local h2 = H.hrp() -- ดึงใหม่ เผื่อตัวละครเกิดใหม่ระหว่างทาง
		if h2 then h2.CFrame = home end
	end
end

-- พารามิเตอร์ของ H.toggle: (กล่อง, ชื่อที่โชว์, คีย์เก็บค่า, ค่าเริ่มต้น, callback, คำอธิบายตอนชี้เมาส์)
H.toggle(SecCollect, "เก็บแพ็กอัตโนมัติ", "AutoCollect", false, nil,
	"กด Collect ทุกแพ็กในแปลงของคุณ")
-- พารามิเตอร์ของ H.slider: (กล่อง, ชื่อ, คีย์, ต่ำสุด, สูงสุด, ค่าเริ่มต้น, หน่วยท้ายตัวเลข)
H.slider(SecCollect, "สแกนทุก", "CollectDelay", 1, 30, 3, " วิ")
H.slider(SecCollect, "คูลดาวน์ต่อแพ็ก", "CollectPerPrompt", 0, 30, 5, " วิ")
H.toggle(SecCollect, "เดินไปหาแพ็กถ้าไกล", "WalkNear", true, nil,
	"เซิร์ฟเวอร์มักเช็กระยะ จึงวาร์ปไปใกล้แพ็กก่อนกด")
H.toggle(SecCollect, "กลับที่เดิมหลังเก็บ", "ReturnBack", true)
-- เริ่มลูปเบื้องหลัง: ทำงานเฉพาะตอน H.State.AutoCollect เป็น true, รอตามค่า CollectDelay
H.loop("AutoCollect", function() return H.State.CollectDelay end, collectAll)

-- ปุ่มกดครั้งเดียว: ทำงานทันทีโดยไม่ต้องเปิดสวิตช์
-- task.spawn = รันแยกเธรด กันเมนูค้างระหว่างรอ, pcall = กัน error ทำให้สคริปต์ล้ม
SecCollect:Button():Add("เก็บเลย", function()
	task.spawn(function()
		local ok, e = pcall(collectAll)
		if not ok then H.err("collect", e) end
	end)
end)

----------------------------------------------------------------------
-- 2) เก็บเงินการ์ดอัตโนมัติ
--    ยิง Remote "CollectAllCardCash" แบบไม่ส่งอาร์กิวเมนต์ ตามช่วงเวลา
----------------------------------------------------------------------
H.toggle(SecCollect, "เก็บเงินการ์ดอัตโนมัติ", "AutoCash", false, nil,
	"ยิง CollectAllCardCash (ไม่ใส่ค่า) ตามช่วงเวลา")
H.slider(SecCollect, "เก็บเงินทุก", "CashDelay", 2, 120, 8, " วิ")
H.loop("AutoCash", function() return H.State.CashDelay end, function()
	-- H.fire คืน true ถ้าหา Remote เจอและส่งแล้ว ค่อยบวกสถิติ
	if H.fire("CollectAllCardCash") then H.Stats.Cash = H.Stats.Cash + 1 end
end)

SecCollect:Button():Add("เปิดเก็บฟรีอัตโนมัติ", function()
	H.fire("ActivateFreeAutoCollectRemote")
	H.notify("ออโต้", "ส่งคำขอเปิด Free Auto-Collect แล้ว", 3)
end)

----------------------------------------------------------------------
-- 3) สุ่มแพ็กใหม่อัตโนมัติ (Reroll)  *** เสียเงินในเกม ***
--    หา ProximityPrompt ที่เขียนว่า "Reroll Packs" ในแปลง แล้วกด
----------------------------------------------------------------------
H.toggle(SecCollect, "สุ่มแพ็กใหม่อัตโนมัติ (เสียเงิน)", "AutoReroll", false, nil,
	"กด prompt Reroll Packs ในแปลง ใช้เงินในเกม ระวังเงินหมด")
H.slider(SecCollect, "สุ่มใหม่ทุก", "RerollDelay", 3, 120, 15, " วิ")
H.loop("AutoReroll", function() return H.State.RerollDelay end, function()
	local plot = H.myPlot()
	if not plot then return end
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Reroll Packs" then
			local pos, hrp = H.promptPos(d), H.hrp()
			if pos and hrp then
				local home
				-- ถ้าอยู่ไกลเกินระยะกด ให้วาร์ปไปก่อน แล้วค่อยกลับ
				if (hrp.Position - pos).Magnitude > (d.MaxActivationDistance or 10) - 1.5 then
					home = hrp.CFrame
					hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
					task.wait(0.15)
				end
				H.press(d)
				if home then task.wait(0.1) hrp.CFrame = home end
			end
			break -- เจออันแรกก็พอ (มีปุ่มเดียวต่อแปลง) ออกจากลูป
		end
	end
end)

----------------------------------------------------------------------
-- 4) รางวัลรายวัน / รางวัลกลับมาเล่น
--    ยิง Remote สองตัวทุก 60 วินาที (ฟังก์ชัน delay คืน 60 ตายตัว)
----------------------------------------------------------------------
H.toggle(SecReward, "รับรางวัลรายวัน/กลับมาเล่น", "AutoDaily", false, nil,
	"ยิง ClaimDailyReward และ ClaimWelcomeBackReward ทุก 60 วินาที")
H.loop("AutoDaily", function() return 60 end, function()
	H.fire("ClaimDailyReward")
	H.fire("ClaimWelcomeBackReward")
	H.Stats.Claims = H.Stats.Claims + 1
end)

SecReward:Button():Add("รับรางวัลเลย", function()
	H.fire("ClaimDailyReward")
	H.fire("ClaimWelcomeBackReward")
	H.notify("ออโต้", "ส่งคำขอรับรางวัลแล้ว", 3)
end)

----------------------------------------------------------------------
-- 5) กดปุ่มหน้าจอให้เอง (GUI Clicker) เช่น Claim / Skip / OK
--    หลักการ: ค้นหาปุ่มใน PlayerGui ที่ "ชื่อวัตถุ" ตรงกับรายการที่เลือก
--    แล้วกดเมื่อปุ่มนั้นมองเห็นอยู่จริงบนจอ
--    หมายเหตุ: ชื่อด้านล่างคือชื่อ Instance ในเกม ห้ามแปลเป็นไทย ไม่งั้นหาไม่เจอ
----------------------------------------------------------------------
local BUTTON_ITEMS = {
	"ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton", "JoinButton", "StartButton",
}
-- ค่าเริ่มต้นที่ติ๊กไว้ (ไม่รวม JoinButton/StartButton เพราะอาจพาเข้าโหมดที่ไม่ต้องการ)
H.State.GuiNames = { "ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton" }

-- GUI ที่ห้ามกดเด็ดขาด: หน้าร้านค้า/หน้ายืนยัน/ใช้โทเคน กันกดซื้อหรือใช้ของโดยไม่ตั้งใจ
local BLOCKED_GUI = { ShopGui = true, PackRotationShopGui = true, ConfirmGui = true, UseTokenGui = true }

-- แคชรายการปุ่ม เพราะ GetDescendants ของ PlayerGui ช้า ไม่ควรค้นทุกรอบ
local cache, cacheT = {}, 0 -- cacheT = เวลาที่สแกนล่าสุด
local function refreshCache()
	cache = {}
	local want = {} -- แปลงรายการที่เลือกเป็นตารางค้นหาเร็ว want["ชื่อ"] = true
	local sel = H.State.GuiNames
	if type(sel) == "table" then
		for _, n in pairs(sel) do want[tostring(n)] = true end
	end
	for _, d in ipairs(PlayerGui:GetDescendants()) do
		if d:IsA("GuiButton") and want[d.Name] then
			local sg = d:FindFirstAncestorOfClass("ScreenGui") -- ปุ่มนี้อยู่ใน ScreenGui ตัวไหน
			if not (sg and BLOCKED_GUI[sg.Name]) then cache[#cache + 1] = d end
		end
	end
	cacheT = os.clock()
end

-- callback `function() cacheT = 0 end` = บังคับให้สแกนใหม่ทันทีเมื่อผู้ใช้เปลี่ยนค่า
H.toggle(SecReward, "กดปุ่มหน้าจออัตโนมัติ", "AutoGui", false, function() cacheT = 0 end,
	"กดปุ่มที่เลือกเมื่อมันขึ้นบนจอ (เช่น Claim, Skip)")
H.slider(SecReward, "ตรวจทุก", "GuiDelay", 0.5, 10, 2, " วิ")
-- พารามิเตอร์ตัวที่ 6 = true คือเลือกได้หลายอัน (Multi)
H.dropdown(SecReward, "ปุ่มที่จะกด", "GuiNames", BUTTON_ITEMS,
	{ "ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton" }, true,
	function() cacheT = 0 end)

H.loop("AutoGui", function() return H.State.GuiDelay end, function()
	-- สแกนใหม่ถ้าแคชเก่าเกิน 8 วินาที
	if os.clock() - cacheT > 8 then refreshCache() end
	for _, b in ipairs(cache) do
		-- b.Parent เช็กว่าปุ่มยังไม่ถูกลบ, H.shown เช็กว่ามองเห็นจริง (ไม่ถูกซ่อน)
		if b.Parent and H.shown(b) then
			H.clickGui(b)
			H.Stats.Claims = H.Stats.Claims + 1
			task.wait(0.15)
		end
	end
end)

SecReward:Button():Add("สแกนปุ่มใหม่", function()
	refreshCache()
	H.notify("กดปุ่มหน้าจอ", "พบปุ่มที่ตรงชื่อ " .. #cache .. " ปุ่ม", 3)
end)

SecReward:Label({
	Name = "เคล็ดลับ",
	Description = "ถ้า remote ไม่ตอบสนอง ให้เปิดหน้าต่างรางวัลในเกม แล้วใช้ตัวกดปุ่มหน้าจอกดแทน",
})
