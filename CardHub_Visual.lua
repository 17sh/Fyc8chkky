--[[
	CardHub_Visual.lua : หน้า "ภาพ"
	  - ESP: ไฮไลต์แพ็ก / ผู้เล่น / ป้ายชื่อเจ้าของแปลง (มองทะลุสิ่งกีดขวางได้)
	  - มุมมอง: สว่างเต็มที่ (Fullbright) / ไม่มีหมอก / ปรับ FOV
	  - ประสิทธิภาพ: ลดเอฟเฟกต์ / ปิดภาพ 3D ประหยัดแบต / ซ่อนของตกแต่งแปลงคนอื่น

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
]]

local H = ...
local Window = H.Window
local RunService, Workspace = H.RunService, H.Workspace
local Lighting = game:GetService("Lighting") -- ระบบแสง/หมอก/เวลาของฉาก

local Page = Window:CreatePage({ Name = "ภาพ" })
local SecEsp = Page:CreateSection({ Name = "ESP (มองทะลุ)", Side = 1, Collapsed = false })
local SecView = Page:CreateSection({ Name = "มุมมอง", Side = 2, Collapsed = false })
local SecPerf = Page:CreateSection({ Name = "ประสิทธิภาพ", Side = 2, Collapsed = false })

-- โฟลเดอร์เก็บวัตถุ ESP ทั้งหมดที่เราสร้าง วางไว้ใน gethui() (ที่ซ่อนของ executor) หรือ CoreGui
-- เพื่อไม่ให้เกมเห็น และลบทีเดียวทั้งโฟลเดอร์ตอนปิดสคริปต์ได้
local host = (gethui and gethui()) or game:GetService("CoreGui")
local holder = Instance.new("Folder")
holder.Name = "CardHubESP"
pcall(function() holder.Parent = host end)
H.onStop(function() holder:Destroy() end)

-- ลบวัตถุใน holder ที่ชื่อขึ้นต้นด้วย prefix (แบ่งหมวดด้วยชื่อ: pack_ / plr_ / plot_)
-- ใช้ก่อนสร้างใหม่ทุกรอบ เพื่อไม่ให้ของเก่าค้างซ้อนกัน
local function clearHolder(prefix)
	for _, c in ipairs(holder:GetChildren()) do
		if c.Name:sub(1, #prefix) == prefix then c:Destroy() end
	end
end

----------------------------------------------------------------------
-- ESP: แพ็กที่เก็บได้ในแปลงของเรา
-- วาง Highlight (เรืองแสงสีเขียว) บนชิ้นส่วนที่มี ProximityPrompt "Collect"
----------------------------------------------------------------------
local function refreshPackEsp()
	clearHolder("pack_")
	if not H.State.EspPacks then return end
	local plot = H.myPlot()
	local root = plot and plot:FindFirstChild("Systems")
	root = root and root:FindFirstChild("PlacedPacks")
	if not root then return end
	for i, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
			local part = d.Parent -- prompt ติดอยู่กับชิ้นส่วนของแพ็ก
			if part and part:IsA("BasePart") then
				local hl = Instance.new("Highlight")
				hl.Name = "pack_" .. i
				hl.Adornee = part                         -- ไฮไลต์ชิ้นไหน
				hl.FillColor = Color3.fromRGB(80, 255, 140) -- สีเขียว
				hl.FillTransparency = 0.6                 -- โปร่งใสบางส่วน
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- มองทะลุกำแพง
				hl.Parent = holder
			end
		end
	end
end
-- callback = refreshPackEsp : สลับสวิตช์แล้วรีเฟรชทันที (ปิด = ล้างของเก่า)
H.toggle(SecEsp, "ESP แพ็ก (แปลงของฉัน)", "EspPacks", false, refreshPackEsp, "ไฮไลต์แพ็กที่กด Collect ได้")
H.loop("EspPacks", function() return 3 end, refreshPackEsp) -- รีเฟรชทุก 3 วิ ให้ตามแพ็กใหม่

----------------------------------------------------------------------
-- ESP: ผู้เล่นคนอื่น (เรืองแสงสีแดง + ป้ายชื่อและระยะห่าง)
----------------------------------------------------------------------
local function refreshPlayerEsp()
	clearHolder("plr_")
	if not H.State.EspPlayers then return end
	local myHrp = H.hrp()
	for _, p in ipairs(H.Players:GetPlayers()) do
		if p ~= H.lp and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- เรืองแสงทั้งตัวละคร
				local hl = Instance.new("Highlight")
				hl.Name = "plr_hl_" .. p.Name
				hl.Adornee = p.Character
				hl.FillColor = Color3.fromRGB(255, 90, 90)
				hl.FillTransparency = 0.7
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = holder

				-- ป้ายลอยเหนือหัว (BillboardGui หันหน้าหากล้องเสมอ)
				local bb = Instance.new("BillboardGui")
				bb.Name = "plr_bb_" .. p.Name
				bb.Adornee = hrp
				bb.Size = UDim2.new(0, 150, 0, 30)
				bb.StudsOffset = Vector3.new(0, 3, 0) -- ยกขึ้น 3 หน่วยเหนือตัว
				bb.AlwaysOnTop = true
				local tl = Instance.new("TextLabel", bb)
				tl.Size = UDim2.new(1, 0, 1, 0)
				tl.BackgroundTransparency = 1
				tl.TextColor3 = Color3.new(1, 1, 1)
				tl.TextStrokeTransparency = 0.3
				tl.Font = Enum.Font.GothamBold
				tl.TextSize = 13
				-- ระยะห่างจากเรา (หน่วย stud) ปัดเป็นจำนวนเต็ม
				local dist = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
				tl.Text = p.Name .. " [" .. dist .. "]"
				bb.Parent = holder
			end
		end
	end
end
H.toggle(SecEsp, "ESP ผู้เล่น", "EspPlayers", false, refreshPlayerEsp)
H.loop("EspPlayers", function() return 1.5 end, refreshPlayerEsp) -- รีเฟรชทุก 1.5 วิ ให้ระยะอัปเดต

-- ป้ายชื่อเจ้าของแปลงทุกแปลง (ชื่อโมเดลแปลง = ชื่อผู้เล่นเจ้าของ) ทำครั้งเดียวตอนเปิดสวิตช์
H.toggle(SecEsp, "แสดงชื่อเจ้าของแปลงอื่น", "EspPlots", false, function(v)
	clearHolder("plot_")
	if not v then return end
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return end
	for _, m in ipairs(pm:GetChildren()) do
		-- หาชิ้นส่วนฐานของแปลงไว้ยึดป้าย ("Base"/"SpawnPart" คือชื่อวัตถุในเกม ห้ามแปล)
		local base = m:FindFirstChild("Base", true) or m:FindFirstChild("SpawnPart", true)
		if base and base:IsA("BasePart") then
			local bb = Instance.new("BillboardGui")
			bb.Name = "plot_" .. m.Name
			bb.Adornee = base
			bb.Size = UDim2.new(0, 160, 0, 26)
			bb.StudsOffset = Vector3.new(0, 14, 0)
			bb.AlwaysOnTop = true
			local tl = Instance.new("TextLabel", bb)
			tl.Size = UDim2.new(1, 0, 1, 0)
			tl.BackgroundTransparency = 1
			tl.TextColor3 = Color3.fromRGB(255, 220, 90) -- สีเหลือง
			tl.TextStrokeTransparency = 0.3
			tl.Font = Enum.Font.GothamBold
			tl.TextSize = 14
			tl.Text = m.Name
			bb.Parent = holder
		end
	end
end)

----------------------------------------------------------------------
-- มุมมอง: สว่างเต็มที่ / ไม่มีหมอก / ปรับ FOV
-- เก็บค่าแสงเดิมไว้ใน orig ก่อน เพื่อคืนค่าตอนปิดสวิตช์หรือปิดสคริปต์
----------------------------------------------------------------------
local orig = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
	FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

-- สว่างเต็มที่: เพิ่มความสว่าง ตั้งเวลากลางวัน ปิดเงา และเพิ่มแสงแวดล้อม
H.toggle(SecView, "สว่างเต็มที่ (Fullbright)", "Fullbright", false, function(v)
	if v then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14 -- 14:00 น. = กลางวัน
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(170, 170, 170)
	else
		Lighting.Brightness = orig.Brightness
		Lighting.ClockTime = orig.ClockTime
		Lighting.GlobalShadows = orig.GlobalShadows
		Lighting.Ambient = orig.Ambient
	end
end)

-- ไม่มีหมอก: ดันระยะเริ่ม/จบของหมอกให้ไกลมาก (1,000,000 หน่วย) จนมองไม่เห็นหมอก
H.toggle(SecView, "ไม่มีหมอก", "NoFog", false, function(v)
	if v then
		Lighting.FogEnd = 1e6
		Lighting.FogStart = 1e6
	else
		Lighting.FogEnd = orig.FogEnd
		Lighting.FogStart = orig.FogStart
	end
end)

-- FOV (มุมมองกล้อง): ค่ามากเห็นกว้างขึ้น ค่าน้อยซูมเข้า
-- เกมมักรีเซ็ตเอง จึงเขียนทับทุกเฟรมตอนเปิดสวิตช์
local origFov
H.toggle(SecView, "ปรับ FOV", "FovOn", false, function(v)
	local cam = Workspace.CurrentCamera
	if cam then
		if v then origFov = origFov or cam.FieldOfView else cam.FieldOfView = origFov or 70 end
	end
end)
H.slider(SecView, "FOV", "FovVal", 40, 120, 90, "°")
H.conn(RunService.RenderStepped, function()
	if H.State.FovOn then
		local cam = Workspace.CurrentCamera
		if cam then cam.FieldOfView = H.State.FovVal or 90 end
	end
end)

-- ปิดสคริปต์: คืนค่าแสง/หมอก/FOV ทั้งหมด
H.onStop(function()
	pcall(function()
		Lighting.Brightness = orig.Brightness
		Lighting.ClockTime = orig.ClockTime
		Lighting.GlobalShadows = orig.GlobalShadows
		Lighting.Ambient = orig.Ambient
		Lighting.FogEnd = orig.FogEnd
		Lighting.FogStart = orig.FogStart
		if origFov and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = origFov end
	end)
end)

----------------------------------------------------------------------
-- ประสิทธิภาพ
----------------------------------------------------------------------
-- ลดแลค: ปิดเอฟเฟกต์ (พาร์ติเคิล/เส้นลาก/ควัน/ไฟ ฯลฯ) ทั้งฉาก ลดคุณภาพภาพต่ำสุด ปิดเงา
-- ทำครั้งเดียวตอนกดปุ่ม (ไม่คืนค่าอัตโนมัติ ต้อง Rejoin ถ้าอยากได้เอฟเฟกต์กลับมา)
SecPerf:Button():Add("ลดแลค (FPS Booster)", function()
	local n = 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
			or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
			d.Enabled = false
			n = n + 1
		end
	end
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		Lighting.GlobalShadows = false
	end)
	H.notify("ลดแลค", "ปิดเอฟเฟกต์ " .. n .. " ชิ้น + ลดคุณภาพภาพ", 4)
end)

-- ประหยัดแบต: ปิดการเรนเดอร์ภาพ 3D (จอดำ) และจำกัด FPS ต่ำ ๆ เหมาะกับปล่อยฟาร์มนาน ๆ
-- สคริปต์ยังทำงานปกติเพราะตรรกะเกมไม่ขึ้นกับการวาดภาพ
H.toggle(SecPerf, "ปิดภาพ 3D (ประหยัดแบต)", "Render3D", false, function(v)
	pcall(function() RunService:Set3dRenderingEnabled(not v) end)
	-- setfpscap เป็นฟังก์ชันของ executor: เปิดโหมดนี้ใช้ค่าที่ตั้ง (ค่าเริ่ม 15) ปิดโหมดนี้กลับเป็น 60
	if v and setfpscap then pcall(setfpscap, H.State.FpsCap or 15) end
	if not v and setfpscap then pcall(setfpscap, 60) end
end, "จอ 3D จะดำ แต่เมนูยังใช้ได้ สคริปยังทำงานปกติ")
-- ตัวที่ 7 ของ slider = callback: ปรับสไลเดอร์ระหว่างปิดภาพ 3D อยู่ ให้เปลี่ยน FPS cap ทันที
H.slider(SecPerf, "จำกัด FPS (ตอนปิด 3D)", "FpsCap", 5, 60, 15, " fps", function(v)
	if H.State.Render3D and setfpscap then pcall(setfpscap, v) end
end)

-- ปิดสคริปต์: เปิดภาพ 3D กลับและคืน FPS เป็น 60
H.onStop(function()
	pcall(function() RunService:Set3dRenderingEnabled(true) end)
	if setfpscap then pcall(setfpscap, 60) end
end)

-- ซ่อนของตกแต่ง (Decor) ของแปลงคนอื่น ด้วย LocalTransparencyModifier = 1 (โปร่งใสเฉพาะฝั่งเรา)
-- แปลงของเราไม่ถูกซ่อน (m ~= mine)
H.toggle(SecPerf, "ซ่อนของตกแต่งแปลงคนอื่น", "HideDecor", false, function(v)
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return end
	local mine = H.myPlot()
	for _, m in ipairs(pm:GetChildren()) do
		if m ~= mine then
			local decor = m:FindFirstChild("Decor") -- "Decor" คือชื่อวัตถุในเกม ห้ามแปล
			if decor then
				for _, d in ipairs(decor:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = v and 1 or 0 end
				end
			end
		end
	end
end, "ซ่อนของตกแต่งแปลงคนอื่น ลดภาระเครื่อง")
