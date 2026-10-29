--[[
	CardHub_Player.lua : หน้า "ผู้เล่น" (ความเร็ว / กระโดด / กระโดดไม่จำกัด / ทะลุกำแพง / บิน / กัน AFK)

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
	ฟังก์ชันของ H ที่ใช้ในไฟล์นี้:
	  H.hum() / H.hrp() / H.char()   Humanoid / HumanoidRootPart / ตัวละคร ของเรา (อาจเป็น nil ถ้ากำลังเกิดใหม่)
	  H.conn(สัญญาณ, ฟังก์ชัน)        ต่อ event และจะถูกตัดอัตโนมัติเมื่อกด "ปิดสคริปต์"
	  H.onStop(ฟังก์ชัน)              ลงทะเบียนโค้ดคืนค่า/เก็บกวาด ตอนปิดสคริปต์
	  H.Alive                         true ตราบที่สคริปต์ยังทำงาน (ลูปใช้เช็กเพื่อหยุดตัวเอง)
]]

local H = ...
local Window = H.Window
local UIS, RunService, Workspace = H.UIS, H.RunService, H.Workspace

local Page = Window:CreatePage({ Name = "ผู้เล่น" })
local SecMove = Page:CreateSection({ Name = "การเคลื่อนที่", Side = 1, Collapsed = false })
local SecSafe = Page:CreateSection({ Name = "ยูทิลิตี้", Side = 2, Collapsed = false })

----------------------------------------------------------------------
-- ความเร็วเดิน / แรงกระโดด
-- หลักการ: เกมมักรีเซ็ตค่ากลับเป็นปกติ จึงเขียนทับซ้ำทุกเฟรม (Heartbeat) ตอนสวิตช์เปิดอยู่
-- ตอนปิดสวิตช์ จะคืนค่ามาตรฐานของ Roblox (เดิน 16 / กระโดด 50)
----------------------------------------------------------------------
H.toggle(SecMove, "ความเร็วเดิน (WalkSpeed)", "SpeedOn", false, function(v)
	if not v then
		local hum = H.hum()
		if hum then hum.WalkSpeed = 16 end
	end
end)
H.slider(SecMove, "ค่าความเร็ว", "SpeedVal", 16, 150, 40, "")

H.toggle(SecMove, "แรงกระโดด (JumpPower)", "JumpOn", false, function(v)
	if not v then
		local hum = H.hum()
		if hum then hum.JumpPower = 50 end
	end
end)
H.slider(SecMove, "ค่าแรงกระโดด", "JumpVal", 50, 250, 90, "")

-- ทุกเฟรมที่ Heartbeat: ถ้าเปิดสวิตช์ ก็ใส่ค่าที่ตั้งไว้ให้ Humanoid
H.conn(RunService.Heartbeat, function()
	local hum = H.hum()
	if not hum then return end
	if H.State.SpeedOn then hum.WalkSpeed = H.State.SpeedVal or 40 end
	if H.State.JumpOn then
		hum.UseJumpPower = true -- บางเกมใช้ JumpHeight แทน ต้องบังคับให้ใช้ JumpPower
		hum.JumpPower = H.State.JumpVal or 90
	end
end)

----------------------------------------------------------------------
-- กระโดดไม่จำกัด (Infinite Jump)
-- ทุกครั้งที่กดกระโดด (JumpRequest) สั่งให้เข้าสถานะ Jumping ทันที แม้ลอยกลางอากาศ
----------------------------------------------------------------------
H.toggle(SecMove, "กระโดดไม่จำกัด", "InfJump", false)
H.conn(UIS.JumpRequest, function()
	if H.State.InfJump then
		local hum = H.hum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

----------------------------------------------------------------------
-- ทะลุกำแพง (Noclip)
-- ปิด CanCollide ของทุกชิ้นส่วนตัวละครทุกเฟรมที่ Stepped (ก่อนฟิสิกส์คำนวณ)
-- ต้องทำซ้ำทุกเฟรมเพราะ Roblox จะเปิดการชนกลับเองให้
----------------------------------------------------------------------
H.toggle(SecMove, "ทะลุกำแพง (Noclip)", "Noclip", false)
H.conn(RunService.Stepped, function()
	if not H.State.Noclip then return end
	local c = H.char()
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end)

----------------------------------------------------------------------
-- บิน (Fly)
-- หลักการ: สร้าง BodyVelocity (ดันตัวละครด้วยความเร็วที่กำหนด) และ BodyGyro (หันตัวตามกล้อง)
-- ติดที่ HumanoidRootPart แล้วปรับความเร็วทุกเฟรมตามทิศที่จอยสติ๊ก/ปุ่ม WASD กด + ทิศที่กล้องมอง
-- PlatformStand = true ทำให้ตัวละครไม่พยายามยืน/เดินเอง
----------------------------------------------------------------------
local flyBV, flyBG -- BodyVelocity และ BodyGyro ที่สร้างไว้ (nil = ยังไม่บิน)

-- หยุดบิน: ลบ body ทั้งสอง แล้วคืนให้ตัวละครยืนได้ปกติ
local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local hum = H.hum()
	if hum then hum.PlatformStand = false end
end

H.toggle(SecMove, "บิน", "Fly", false, function(v)
	if v then
		local hrp, hum = H.hrp(), H.hum()
		if not (hrp and hum) then return end
		stopFly() -- เคลียร์ของเก่าก่อน กันซ้อน
		flyBV = Instance.new("BodyVelocity")
		flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9) -- แรงสูงมาก เพื่อชนะแรงโน้มถ่วง
		flyBV.Velocity = Vector3.zero
		flyBV.Parent = hrp
		flyBG = Instance.new("BodyGyro")
		flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		flyBG.P = 9e4 -- ความไวในการหมุนตามกล้อง
		flyBG.CFrame = hrp.CFrame
		flyBG.Parent = hrp
		hum.PlatformStand = true
	else
		stopFly()
	end
end, "ดันจอยไปข้างหน้าเพื่อบินไปทางที่กล้องมอง")
H.slider(SecMove, "ความเร็วบิน", "FlySpeed", 20, 200, 70, "")

-- อัปเดตการบินทุกเฟรมภาพ (RenderStepped ลื่นกว่า เพราะตรงกับการเรนเดอร์)
H.conn(RunService.RenderStepped, function()
	if not (H.State.Fly and flyBV and flyBV.Parent) then return end
	local hum, cam = H.hum(), Workspace.CurrentCamera
	if not (hum and cam) then return end
	local md = hum.MoveDirection -- ทิศที่ผู้เล่นกดเดิน (ตามพื้นราบ) ขนาด 0-1
	if md.Magnitude < 0.05 then
		flyBV.Velocity = Vector3.zero -- ไม่ได้กดอะไร = หยุดลอยนิ่ง
	else
		local look = cam.CFrame.LookVector -- ทิศที่กล้องมอง (รวมเงยก้ม)
		local flat = Vector3.new(look.X, 0, look.Z)
		local rightV = cam.CFrame.RightVector
		local flatR = Vector3.new(rightV.X, 0, rightV.Z)
		-- f = ไปข้างหน้า/ถอยหลังเท่าไร, r = ไปขวา/ซ้ายเท่าไร (เทียบกับทิศกล้องแนวราบ)
		local f = flat.Magnitude > 0 and md:Dot(flat.Unit) or 0
		local r = flatR.Magnitude > 0 and md:Dot(flatR.Unit) or 0
		-- ใช้ look แบบ 3 มิติ จึงบินขึ้น/ลงตามที่กล้องเงยก้มได้
		flyBV.Velocity = (look * f + rightV * r) * (H.State.FlySpeed or 70)
	end
	if flyBG then flyBG.CFrame = cam.CFrame end -- หันตัวตามกล้อง
end)

-- ตอนปิดสคริปต์: เลิกบิน และคืนความเร็ว/แรงกระโดดเป็นค่าปกติ
H.onStop(function()
	stopFly()
	local hum = H.hum()
	if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
end)

-- ตัวละครเกิดใหม่ body เก่าจะหายไปกับตัวละครเดิม จึงล้างตัวแปรอ้างอิงทิ้ง กันค้าง
H.conn(H.lp.CharacterAdded, function()
	flyBV, flyBG = nil, nil
end)

----------------------------------------------------------------------
-- กัน AFK (เปิดไว้ตั้งแต่แรก)
-- Roblox จะเตะเมื่อไม่มีการกดอะไรประมาณ 20 นาที เหตุการณ์ Idled ยิงก่อนถูกเตะ
-- เราจึงแกล้งคลิกเมาส์ขวา 1 ครั้ง ให้ระบบเข้าใจว่ามีการใช้งาน
----------------------------------------------------------------------
local VU
pcall(function() VU = game:GetService("VirtualUser") end) -- executor บางตัวไม่มี จึงห่อ pcall

H.toggle(SecSafe, "กัน AFK", "AntiAFK", true, nil, "กันถูกเตะเมื่อไม่ขยับ 20 นาที")
H.conn(H.lp.Idled, function()
	if not H.State.AntiAFK then return end
	pcall(function()
		if VU then
			VU:CaptureController()
			VU:ClickButton2(Vector2.new())
		elseif H.VIM then
			-- ทางสำรอง: ส่งคลิกเมาส์เสมือนผ่าน VirtualInputManager
			H.VIM:SendMouseButtonEvent(0, 0, 1, true, game, 1)
			task.wait(0.05)
			H.VIM:SendMouseButtonEvent(0, 0, 1, false, game, 1)
		end
	end)
end)

-- ตัวช่วยเสริม: ขยับตัวละครเล็กน้อยทุก 60 วินาที (ปิดไว้เป็นค่าเริ่มต้น)
H.toggle(SecSafe, "ขยับตัวเล็กน้อยทุก 60 วิ", "AFKMove", false)
task.spawn(function()
	while H.Alive do
		task.wait(60)
		if H.State.AFKMove then
			local hum = H.hum()
			-- เดินถอยไปข้างหน้า(แกน -Z) 0.25 วินาที แล้วหยุด
			if hum then hum:Move(Vector3.new(0, 0, -1), true) task.wait(0.25) hum:Move(Vector3.zero, true) end
		end
	end
end)

-- ปุ่ม 2 อัน แถวเดียวกัน: รีเซ็ตตัวละคร (ตาย-เกิดใหม่) / สลับนั่ง-ยืน
SecSafe:Button():Add("รีเซ็ตตัวละคร", function()
	local hum = H.hum()
	if hum then hum.Health = 0 end
end):Add("นั่ง/ยืน", function()
	local hum = H.hum()
	if hum then hum.Sit = not hum.Sit end
end)

SecSafe:Label({
	Name = "เคล็ดลับ",
	Description = "ค่าความเร็ว/กระโดดที่สูงมากอาจถูกระบบตรวจจับของเกม แนะนำไม่เกิน 40-60",
})
