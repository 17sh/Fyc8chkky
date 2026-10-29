--[[
	CardHub.lua  (ไฟล์หลัก)  —  ฉบับภาษาไทย + คำอธิบายละเอียด

	ไฟล์นี้ทำหน้าที่ "ตัวคุมหลัก" 4 อย่าง:
	  1) โหลดไลบรารีเมนู UILIB.lua
	  2) สร้างตัวกลาง H (ชุดฟังก์ชันช่วยเหลือ) ที่ทุกโมดูลใช้ร่วมกัน
	  3) สร้างหน้าต่างเมนูและหน้า "ข้อมูล" (สถิติ)
	  4) โหลดโมดูลอื่น ๆ ทีละไฟล์ (ออโต้/คลิก/ผู้เล่น/วาร์ป/ภาพ/เบ็ดเตล็ด)

	วิธีรันจาก GitHub (บรรทัดเดียว) โดยแก้ USERNAME/REPO ให้เป็นของคุณ:
	getgenv().CardHubBase="https://raw.githubusercontent.com/USERNAME/REPO/main/";loadstring(game:HttpGet(getgenv().CardHubBase.."CardHub.lua"))()

	วิธีรันจากไฟล์ในเครื่อง (ถ้าไม่ตั้ง CardHubBase):
	loadstring(readfile("CardHub.lua"))()

	ไฟล์ที่ต้องมีใน repo (หรือโฟลเดอร์ workspace ของ executor) "ชื่อไฟล์ต้องตรงตามนี้เป๊ะ":
	  UILIB.lua  CardHub.lua
	  CardHub_Auto.lua  CardHub_Click.lua  CardHub_Player.lua
	  CardHub_Teleport.lua  CardHub_Visual.lua  CardHub_Misc.lua
	  CardHub_Cash.lua  CardHub_Dungeon.lua  CardHub_UI.lua   (ใหม่: เก็บเงิน / ดันเจี้ยน / หน้าจอ)

	หมายเหตุ: ไฟล์ชุดนี้แปลเฉพาะข้อความที่แสดงบนเมนู ส่วน UILIB.lua ยังเป็นต้นฉบับเดิม
]]

-- ถ้าเคยรันสคริปต์นี้ค้างอยู่ (รันซ้ำ) ให้สั่งหยุดตัวเก่าก่อน กันเมนูซ้อนสองชุด
-- getgenv() = ตัวแปรโกลบอลของ executor ที่คงอยู่ข้ามการรันสคริปต์
if getgenv().CardHub and getgenv().CardHub.Stop then
	pcall(getgenv().CardHub.Stop)
end

----------------------------------------------------------------------
-- Services (บริการของ Roblox ที่ใช้บ่อย)
----------------------------------------------------------------------
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")      -- ที่เก็บ Remote ที่เกมใช้คุยกับเซิร์ฟเวอร์
local RunService = game:GetService("RunService")     -- event รายเฟรม (Heartbeat ฯลฯ)
local UIS = game:GetService("UserInputService")      -- รับ input ของผู้เล่น
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

-- ฟังก์ชันดึงไฟล์โค้ด: ถ้ามี CardHubBase ให้โหลดจาก GitHub ก่อน ไม่สำเร็จค่อยใช้ไฟล์ในเครื่อง
-- คืนข้อความโค้ดของไฟล์ หรือ nil ถ้าหาไม่เจอทั้งสองทาง
local BASE = getgenv().CardHubBase
local function fetch(name)
	if type(BASE) == "string" and BASE ~= "" then
		local ok, body = pcall(function() return game:HttpGet(BASE .. name) end)
		-- เช็กว่าเนื้อหายาวพอ และไม่ใช่หน้า "404: Not Found" ของ GitHub
		if ok and type(body) == "string" and #body > 20 and body:sub(1, 3) ~= "404" then
			return body
		end
	end
	-- isfile/readfile เป็นฟังก์ชันของ executor ใช้อ่านไฟล์ในโฟลเดอร์ workspace
	if isfile and isfile(name) then return readfile(name) end
	return nil
end

----------------------------------------------------------------------
-- โหลดไลบรารีเมนู (UILIB.lua)
----------------------------------------------------------------------
local uiSrc = fetch("UILIB.lua")
if not uiSrc then
	warn("[CardHub] โหลด UILIB.lua ไม่ได้ (เช็กลิงก์ GitHub หรือไฟล์ในเครื่อง)")
	return
end
-- loadstring แปลงข้อความโค้ดเป็นฟังก์ชัน ("=UILIB.lua" คือชื่อที่จะโผล่ในข้อความ error)
local uiFn, uiErr = loadstring(uiSrc, "=UILIB.lua")
if not uiFn then warn("[CardHub] UILIB.lua syntax error: " .. tostring(uiErr)) return end
local Library = uiFn() -- รันแล้วได้ตารางไลบรารีกลับมา

-- ไม่ดึงโลโก้จากเว็บนอก (ตั้งว่างไว้)
Library.LogoUrl = ""
Library.LogoFallback = ""
-- สคริปต์ที่ถูกบันทึกให้รันอัตโนมัติเมื่อย้าย/เข้าเกมใหม่ (ฟีเจอร์ Auto Execute ในหน้า Settings)
if type(BASE) == "string" and BASE ~= "" then
	Library.AutoExecuteScript = 'getgenv().CardHubBase="' .. BASE .. '";loadstring(game:HttpGet("' .. BASE .. 'CardHub.lua"))()'
else
	Library.AutoExecuteScript = 'loadstring(readfile("CardHub.lua"))()'
end

----------------------------------------------------------------------
-- ตัวกลาง H ที่ทุกโมดูลใช้ร่วมกัน
-- (โมดูลแต่ละไฟล์รับ H ผ่าน `local H = ...`)
----------------------------------------------------------------------
local H = {
	Alive = true,     -- true = สคริปต์ยังทำงาน; ตั้งเป็น false ตอนปิด ทุกลูปจะเห็นแล้วหยุดเอง
	State = {},       -- ค่าสวิตช์/สไลเดอร์ทั้งหมด เก็บตาม key (อ่านง่ายจากทุกไฟล์)
	Stats = { Collected = 0, Cash = 0, Clicks = 0, Claims = 0, Errors = 0, Start = os.clock() }, -- ตัวนับสถิติ
	Conns = {},       -- event connection ทั้งหมด (ไว้ตัดตอนปิดสคริปต์)
	Toggles = {},     -- ตัวสวิตช์ทั้งหมดตาม key (แถบควบคุมด่วนใช้สั่งเปิด/ปิดแทนเมนู)
	Cleanups = {},    -- ฟังก์ชันเก็บกวาดจากแต่ละโมดูล (ไว้เรียกตอนปิดสคริปต์)
	Library = Library,
	IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled, -- มีจอสัมผัสและไม่มีคีย์บอร์ด = มือถือ
	LastError = "-",  -- ข้อความ error ล่าสุด (โชว์ในหน้าข้อมูล)
}
getgenv().CardHub = H -- เก็บไว้ในโกลเดอร์ เพื่อให้รันซ้ำแล้วหาตัวเก่ามาปิดได้ (ดูต้นไฟล์)

H.lp = Players.LocalPlayer -- ตัวเราเอง
H.Players, H.RS, H.RunService, H.UIS, H.GuiService, H.Workspace =
	Players, RS, RunService, UIS, GuiService, Workspace

-- ตัวละคร / Humanoid (ควบคุมเดิน กระโดด เลือด) / HumanoidRootPart (จุดกลางลำตัว ใช้อ้างตำแหน่ง)
-- อาจคืน nil ได้ถ้าตัวละครกำลังเกิดใหม่ ผู้เรียกต้องเช็ก nil เสมอ
function H.char() return H.lp.Character end
function H.hum()
	local c = H.lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
function H.hrp()
	local c = H.lp.Character
	return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

-- แจ้งเตือนที่มุมจอ (ห่อ pcall กันไลบรารีพังแล้วลามไปทำสคริปต์ล้ม)
function H.notify(title, desc, dur)
	pcall(function()
		Library:Notification({ Title = title or "Card Hub", Description = desc or "", Duration = dur or 3 })
	end)
end

-- บันทึก error: นับจำนวน และเก็บข้อความ 60 ตัวอักษรแรกไว้โชว์ในหน้าข้อมูล
function H.err(where, e)
	H.Stats.Errors = H.Stats.Errors + 1
	H.LastError = tostring(where) .. ": " .. tostring(e):sub(1, 60)
end

-- ต่อ event แล้วจำ connection ไว้ เพื่อให้ตัดได้ครบตอนปิดสคริปต์ (กัน event ค้างทำงานต่อ)
function H.conn(signal, fn)
	local c = signal:Connect(fn)
	H.Conns[#H.Conns + 1] = c
	return c
end

-- ลงทะเบียนฟังก์ชันที่จะถูกเรียกตอนปิดสคริปต์ (ใช้คืนค่าที่เราแก้ไว้ เช่น ความเร็ว แสง)
function H.onStop(fn) H.Cleanups[#H.Cleanups + 1] = fn end

-- ลูปเบื้องหลัง: ทำ fn ซ้ำ ๆ ตราบที่สวิตช์ H.State[key] เป็น true
--   delay = ฟังก์ชันคืนจำนวนวินาทีที่จะรอระหว่างรอบ (เป็นฟังก์ชันเพื่อให้อ่านค่าสไลเดอร์ล่าสุดทุกรอบ)
--   ถ้าสวิตช์ปิดอยู่ จะรอ 0.3 วิแล้วเช็กใหม่ (ไม่กินเครื่อง)
--   fn ที่ error จะไม่ทำให้ลูปตาย (ห่อ pcall แล้วบันทึกลง H.err)
function H.loop(key, delay, fn)
	task.spawn(function()
		while H.Alive do
			if H.State[key] then
				local ok, e = pcall(fn)
				if not ok then H.err(key, e) end
				task.wait(math.max(0.05, delay and delay() or 1))
			else
				task.wait(0.3)
			end
		end
	end)
end

-- สร้างปุ่มสวิตช์ (Toggle) และเก็บค่าลง H.State[key] อัตโนมัติ
--   section = กล่อง, name = ข้อความที่แสดง (แปลได้), key = ชื่อคีย์ภายใน (ห้ามแปล/ห้ามเปลี่ยน
--   เพราะใช้เป็น Flag ในระบบบันทึกคอนฟิก และโมดูลอื่นอ่านผ่าน H.State[key])
--   default = ค่าเริ่มต้น, cb = ฟังก์ชันที่เรียกเมื่อค่าเปลี่ยน (รับค่า v), tip = คำอธิบายตอนชี้เมาส์
function H.toggle(section, name, key, default, cb, tip)
	H.State[key] = default and true or false
	local tg = section:Toggle({
		Name = name, Flag = key, Default = default and true or false, Tooltip = tip,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
	H.Toggles[key] = tg
	return tg
end

-- สร้างแถบเลื่อนตัวเลข (Slider) : min/max = ช่วงค่า, suffix = หน่วยท้ายตัวเลข เช่น " วิ"
function H.slider(section, name, key, min, max, default, suffix, cb)
	H.State[key] = default
	return section:Slider({
		Name = name, Flag = key, Min = min, Max = max, Default = default,
		Suffix = suffix or "", Compact = false,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
end

-- สร้างดรอปดาวน์เลือกรายการ : items = รายการตัวเลือก, multi = true เลือกได้หลายอัน
-- (ค่าที่เลือกคือข้อความของตัวเลือกนั้นเอง จึงต้องให้โค้ดที่เทียบค่าใช้ข้อความเดียวกัน)
function H.dropdown(section, name, key, items, default, multi, cb)
	H.State[key] = default
	return section:Dropdown({
		Name = name, Flag = key, Items = items, Default = default, Multi = multi or false,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
end

----------------------------------------------------------------------
-- ตัวช่วยเกี่ยวกับ Remote / แปลง / Prompt / GUI
----------------------------------------------------------------------

-- โฟลเดอร์ Remote ของเกม: ReplicatedStorage.Remotes
function H.remotes()
	return RS:FindFirstChild("Remotes")
end

-- ยิง Remote ตามชื่อ (รองรับทั้ง RemoteEvent และ RemoteFunction) โดยไม่ทำให้สคริปต์ค้าง
--   คืน true เมื่อหา Remote เจอและสั่งส่งแล้ว / คืน false, เหตุผล ถ้าหาไม่เจอ
--   ส่งเป็นงานแยก (task.spawn) เพราะ InvokeServer จะรอเซิร์ฟเวอร์ตอบ ถ้าไม่ตอบจะค้างตลอด
function H.fire(name, ...)
	local folder = H.remotes()
	local r = folder and folder:FindFirstChild(name)
	if not r then return false, "no remote: " .. name end
	local args = table.pack(...) -- เก็บอาร์กิวเมนต์ทั้งหมด (รวมค่า nil) ไว้ใช้ในงานแยก
	task.spawn(function()
		local ok, e
		if r:IsA("RemoteFunction") then
			ok, e = pcall(r.InvokeServer, r, table.unpack(args, 1, args.n))
		else
			ok, e = pcall(r.FireServer, r, table.unpack(args, 1, args.n))
		end
		if not ok then H.err(name, e) end
	end)
	return true
end

-- แปลงของผู้เล่น: Workspace.Map.PlotModels[ชื่อผู้เล่น] (ลองชื่อบัญชีก่อน ไม่เจอลองชื่อที่แสดง)
function H.myPlot()
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return nil end
	return pm:FindFirstChild(H.lp.Name) or pm:FindFirstChild(H.lp.DisplayName)
end

-- แปลงของผู้เล่นคนอื่น (ระบุด้วยชื่อบัญชี)
function H.plotOf(playerName)
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	return pm and pm:FindFirstChild(playerName)
end

-- พิกัดจุดเกิดของแปลง (ไม่ใส่ plot = แปลงของเรา) คืน Vector3 หรือ nil
function H.plotSpawn(plot)
	plot = plot or H.myPlot()
	if not plot then return nil end
	local sp = plot:FindFirstChild("SpawnPart", true) or plot:FindFirstChild("Base", true) -- true = ค้นลึกทุกชั้น
	return sp and sp.Position
end

-- กดปุ่ม ProximityPrompt (ปุ่ม "กด E" ที่โผล่เมื่อเดินเข้าใกล้ของในเกม)
--   ใช้ fireproximityprompt ของ executor ถ้ามี (กดได้ทันทีโดยไม่ต้องอยู่ใกล้)
--   ถ้าไม่มี จะจำลองการกดค้างตามเวลา HoldDuration ของ prompt นั้น
function H.press(prompt)
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait((prompt.HoldDuration or 0) + 0.08)
			prompt:InputHoldEnd()
		end)
	end
end

-- หาพิกัดของวัตถุที่ prompt ติดอยู่ (Part / Attachment / Model) คืน Vector3 หรือ nil
function H.promptPos(p)
	local par = p.Parent
	if par and par:IsA("BasePart") then return par.Position end
	if par and par:IsA("Attachment") then return par.WorldPosition end
	if par and par:IsA("Model") then
		local ok, cf = pcall(par.GetPivot, par)
		if ok then return cf.Position end
	end
	return nil
end

-- เช็กว่าปุ่ม GUI "มองเห็นอยู่จริง" ไหม โดยไล่ขึ้นไปหาพ่อทีละชั้นจนถึง PlayerGui
-- ถ้ามีชั้นไหนซ่อน (Visible=false) หรือ ScreenGui ปิดอยู่ (Enabled=false) ถือว่ามองไม่เห็น
function H.shown(o)
	local pg = H.lp:FindFirstChild("PlayerGui")
	while o and o ~= pg and o.Parent do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end

-- แตะที่พิกัดหน้าจอ (x, y เป็นพิกเซลบน viewport) ด้วย VirtualInputManager (ตัวจำลอง input)
--   mode = "Touch" (จำลองนิ้วแตะ) หรือ "Mouse" (จำลองคลิกเมาส์ซ้าย); ไม่ใส่ = เลือกตามอุปกรณ์
--   สองค่านี้เป็นค่าภายในโค้ด ไม่ใช่ข้อความที่แสดง จึงต้องเป็นภาษาอังกฤษตามนี้
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)
H.VIM = VIM

function H.tapAt(x, y, mode)
	if not VIM then return false end
	mode = mode or (H.IsMobile and "Touch" or "Mouse")
	pcall(function()
		if mode == "Touch" then
			VIM:SendTouchEvent(1, 0, x, y) -- 0 = นิ้วแตะลง
			task.wait(0.02)
			VIM:SendTouchEvent(1, 2, x, y) -- 2 = ยกนิ้วขึ้น
		else
			VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)  -- กดเมาส์ลง
			task.wait(0.02)
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 1) -- ปล่อยเมาส์
		end
	end)
	return true
end

-- คลิกปุ่ม GUI ให้เอง ลองตามลำดับความน่าเชื่อถือ:
--   1) firesignal  สั่งให้ event คลิกของปุ่มทำงานตรง ๆ (ไม่ต้องแตะจอ)
--   2) getconnections  ดึงฟังก์ชันที่ผูกกับปุ่มมาเรียกเอง
--   3) แตะหน้าจอจริงที่กลางปุ่ม (ต้องบวก GuiInset.Y เพราะพิกัด GUI ไม่รวมแถบบนสุดของ Roblox)
function H.clickGui(b)
	if firesignal then
		pcall(firesignal, b.MouseButton1Click)
		pcall(firesignal, b.Activated)
		return true
	end
	if getconnections then
		local n = 0
		for _, sig in ipairs({ b.MouseButton1Click, b.Activated }) do
			local ok, cons = pcall(getconnections, sig)
			if ok and cons then
				for _, c in ipairs(cons) do
					if c.Function then pcall(c.Function) n = n + 1 end
				end
			end
		end
		if n > 0 then return true end
	end
	local inset = GuiService:GetGuiInset()
	local p, s = b.AbsolutePosition, b.AbsoluteSize
	return H.tapAt(p.X + s.X / 2, p.Y + s.Y / 2 + inset.Y)
end

-- วาร์ป (target เป็น CFrame หรือ Vector3)
--   tween = true : ค่อย ๆ เลื่อนไปด้วยความเร็ว speed (stud/วินาที) คืนตัว Tween
--   tween = false: วาร์ปทันที คืน true
--   ถ้า target เป็น Vector3 จะยกสูงขึ้น 4 หน่วย กันจมพื้น
function H.tp(target, tween, speed)
	local hrp = H.hrp()
	if not hrp then return false end
	local cf = typeof(target) == "Vector3" and CFrame.new(target + Vector3.new(0, 4, 0)) or target
	if tween then
		local dist = (hrp.Position - cf.Position).Magnitude
		-- เวลา = ระยะ / ความเร็ว (จำกัด 0.1-12 วินาที)
		local t = math.clamp(dist / math.max(10, speed or 120), 0.1, 12)
		local tw = game:GetService("TweenService"):Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
		tw:Play()
		return tw
	end
	hrp.CFrame = cf
	return true
end

----------------------------------------------------------------------
-- หน้าต่างเมนูหลัก
----------------------------------------------------------------------
local Window = Library:Window({ Name = "Card Hub | Anime Waifu Card Collection", Game = "Anime Waifu Card Collection" })
H.Window = Window

----------------------------------------------------------------------
-- หน้า "ข้อมูล" (สถิติรอบนี้ + วิธีใช้)
----------------------------------------------------------------------
local InfoPage = Window:CreatePage({ Name = "ข้อมูล" })
local StatSec = InfoPage:CreateSection({ Name = "สถิติรอบนี้", Side = 1, Collapsed = false })
local HelpSec = InfoPage:CreateSection({ Name = "วิธีใช้", Side = 2, Collapsed = false })

-- ป้ายสถิติ (อัปเดตข้อความทุกวินาทีด้วยลูปด้านล่าง)
local L_time = StatSec:Label("เวลา: 0:00")
local L_col  = StatSec:Label("แพ็กที่เก็บแล้ว: 0")
local L_cash = StatSec:Label("จำนวนครั้งเก็บเงิน: 0")
local L_clk  = StatSec:Label("จำนวนคลิก: 0")
local L_clm  = StatSec:Label("จำนวนครั้งรับรางวัล/กดปุ่ม: 0")
local L_err  = StatSec:Label("Error ล่าสุด: -")

HelpSec:Label({
	Name = "เริ่มต้นใช้งาน",
	Description = "1) หน้า ออโต้: เปิด เก็บแพ็กอัตโนมัติ  2) หน้า คลิก: ตั้งค่า ออโต้คลิก  3) หน้า เบ็ดเตล็ด: เปิด Rejoin อัตโนมัติ / หน้า ภาพ: เปิด ปิดภาพ 3D ถ้าจะทิ้งเครื่องไว้  ปุ่มลอยบนจอใช้เปิด/ปิดเมนู",
})
HelpSec:Label({
	Name = "หมายเหตุ",
	Description = "remote บางตัวไม่ทราบอาร์กิวเมนต์จริง ถ้ากดแล้วไม่เกิดผล แปลว่าเซิร์ฟเวอร์ไม่รับค่าว่าง ให้ใช้ระบบ กดปุ่มหน้าจออัตโนมัติ แทน",
})

-- ลูปอัปเดตสถิติทุก 1 วินาที (SetText ห่อ pcall เผื่อป้ายถูกลบไปแล้วตอนปิดเมนู)
task.spawn(function()
	while H.Alive do
		local t = math.floor(os.clock() - H.Stats.Start) -- วินาทีที่ผ่านไปนับจากเริ่มสคริปต์
		pcall(function()
			-- t // 3600 = ชั่วโมง, (t % 3600) // 60 = นาที, t % 60 = วินาที
			L_time:SetText(("เวลา: %d:%02d:%02d"):format(t // 3600, (t % 3600) // 60, t % 60))
			L_col:SetText("แพ็กที่เก็บแล้ว: " .. H.Stats.Collected)
			L_cash:SetText("จำนวนครั้งเก็บเงิน: " .. H.Stats.Cash)
			L_clk:SetText("จำนวนคลิก: " .. H.Stats.Clicks)
			L_clm:SetText("จำนวนครั้งรับรางวัล/กดปุ่ม: " .. H.Stats.Claims)
			L_err:SetText("Error ล่าสุด: " .. H.LastError)
		end)
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- โหลดโมดูลที่เหลือ
-- แต่ละไฟล์ห่อ pcall แยกกัน: ไฟล์ไหนพังจะไม่ทำให้ไฟล์อื่นพังตาม และจะรายงานตอนท้าย
-- ชื่อไฟล์ในรายการนี้ต้องตรงกับชื่อไฟล์จริงเสมอ (จึงไม่เปลี่ยนชื่อไฟล์ฉบับไทย)
----------------------------------------------------------------------
local modules = {
	"CardHub_Auto.lua", "CardHub_Cash.lua", "CardHub_Dungeon.lua", "CardHub_Click.lua",
	"CardHub_Player.lua", "CardHub_Teleport.lua", "CardHub_Visual.lua", "CardHub_Misc.lua",
	"CardHub_UI.lua",
}
local failed = {}
for _, name in ipairs(modules) do
	local src = fetch(name)
	if src then
		local fn, perr = loadstring(src, "=" .. name)
		if fn then
			local ok, e = pcall(fn, H) -- เรียกโมดูลโดยส่ง H เข้าไปเป็น `...`
			if not ok then failed[#failed + 1] = name .. ": " .. tostring(e):sub(1, 80) end
		else
			failed[#failed + 1] = name .. " (syntax): " .. tostring(perr):sub(1, 80)
		end
	else
		failed[#failed + 1] = name .. " (ไม่พบไฟล์)"
	end
end

----------------------------------------------------------------------
-- หน้า Settings (ธีม/คอนฟิก) + ฟังก์ชันหยุดทั้งหมด
----------------------------------------------------------------------
-- Watermark = ป้ายเล็กมุมจอโชว์ fps/ping/เวลา, KeybindList = รายการปุ่มลัดที่เปิดใช้
local Watermark = Library:Watermark({ Name = "Card Hub", Options = { "fps", "ping", "time" } })
local KeyList = Library:KeybindList("ปุ่มลัดที่ใช้งานอยู่")
Library:CreateSettingsPage(Window, Watermark, KeyList)

-- หยุดสคริปต์ทั้งหมด (เรียกจากปุ่ม "ปิดสคริปต์" หรือเมื่อรันซ้ำ):
--   1) Alive = false  → ทุกลูปเห็นแล้วเลิกทำงาน
--   2) ปิดทุกสวิตช์ใน State
--   3) ตัด event ทั้งหมด
--   4) เรียกฟังก์ชันคืนค่าของแต่ละโมดูล (ความเร็ว แสง FOV ภาพ 3D ฯลฯ)
--   5) ลบเมนู แล้วล้างตัวอ้างอิงใน getgenv
function H.Stop()
	H.Alive = false
	for k in pairs(H.State) do H.State[k] = false end
	for _, c in ipairs(H.Conns) do pcall(function() c:Disconnect() end) end
	for _, fn in ipairs(H.Cleanups) do pcall(fn) end
	pcall(function() Library:Unload() end)
	if getgenv().CardHub == H then getgenv().CardHub = nil end
end

Window:SetOpen(true) -- เปิดเมนูทันที

-- สรุปผลการโหลด
if #failed > 0 then
	H.notify("Card Hub", "โหลดไม่ครบ: " .. table.concat(failed, " | "), 8)
	H.LastError = failed[1]
else
	H.notify("Card Hub", "โหลดสำเร็จ " .. #modules .. " โมดูล", 4)
end
