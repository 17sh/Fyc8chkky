--[[
	CardHub_Cash.lua : หน้า "เงิน" (เก็บเงินการ์ดอัตโนมัติ ไม่ต้องกดทีละหน้า)

	มี 2 วิธี เปิดพร้อมกันได้:
	  A) รีโมต : ยิง CollectAllCardCash (เก็บทุกใบในครั้งเดียว) ไม่ต้องเปิดสมุดเลย
	  B) สมุดการ์ด : กดการ์ดที่มีเงินในสมุดทีละใบ แล้วพลิกหน้าไปเรื่อย ๆ ตามจำนวนหน้าที่ตั้ง
	     (การ์ดอยู่ใน Workspace.Map.PlotModels.<ชื่อเรา>.**.Binder → SurfaceGui → ImageButton
	      พลิกหน้าด้วย ClickDetector ใน NextPageModel)

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
]]
local H = ...
local Window = H.Window
local PlayerGui = H.lp:WaitForChild("PlayerGui")

local Page = Window:CreatePage({ Name = "เงิน" })
local SecAuto = Page:CreateSection({ Name = "เก็บเงินอัตโนมัติ", Side = 1, Collapsed = false })
local SecInfo = Page:CreateSection({ Name = "สถานะ / เครื่องมือ", Side = 2, Collapsed = false })

local M_REMOTE = "รีโมตเก็บทั้งหมด (CollectAllCardCash)"
local M_BINDER = "กดการ์ดในสมุดทุกหน้า"

----------------------------------------------------------------------
-- วิธี B: สมุดการ์ด
----------------------------------------------------------------------
local binders, bTime = {}, 0
local function getBinders()
	if #binders > 0 and os.clock() - bTime < 20 then return binders end
	binders = {}
	local plot = H.myPlot()
	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d.Name == "Binder" and d:IsA("Model") then binders[#binders + 1] = d end
		end
	end
	bTime = os.clock()
	return binders
end

-- สั่งปุ่มที่อยู่ใน SurfaceGui (ใช้ได้แค่ firesignal/getconnections ห้ามใช้แตะหน้าจอ เพราะพิกัดไม่ตรง)
local function fireBtn(b)
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
		return n > 0
	end
	return false
end

local warnedNoFire = false
local function clickCards()
	local n = 0
	for _, bd in ipairs(getBinders()) do
		for _, d in ipairs(bd:GetDescendants()) do
			if d:IsA("ImageButton") then
				local cl = d:FindFirstChild("CashLabel")
				-- กดเฉพาะใบที่มีเงิน (ข้อความมีตัวเลขที่ไม่ใช่ 0 ล้วน)
				if cl and cl:IsA("TextLabel") then
					local digits = cl.Text:gsub("[^%d]", "")
					if #digits > 0 and tonumber(digits) ~= 0 then
						if fireBtn(d) then
							n = n + 1
						elseif not warnedNoFire then
							warnedNoFire = true
							H.notify("เก็บเงิน", "executor นี้ไม่มี firesignal จึงกดการ์ดไม่ได้ ให้ใช้วิธีรีโมตแทน", 6)
						end
						task.wait(0.03)
					end
				end
			end
		end
	end
	return n
end

local function flipNext()
	if not fireclickdetector then return false end
	local did = false
	for _, bd in ipairs(getBinders()) do
		local np = bd:FindFirstChild("NextPageModel", true)
		local cd = np and np:FindFirstChildWhichIsA("ClickDetector", true)
		if cd then
			pcall(fireclickdetector, cd)
			did = true
		end
	end
	return did
end

local function binderPos()
	local bd = getBinders()[1]
	if not bd then return nil end
	local ok, cf = pcall(bd.GetPivot, bd)
	return ok and cf.Position or nil
end

local busy = false
local function collectBinder()
	if busy then return end
	busy = true
	local hrp = H.hrp()
	local home, moved
	local pos = binderPos()
	-- ClickDetector ต้องอยู่ใกล้พอ (เซิร์ฟเวอร์เช็กระยะ) จึงวาร์ปไปใกล้สมุดก่อนแล้วกลับ
	if hrp and pos and H.State.CashNear and (hrp.Position - pos).Magnitude > 24 then
		home = hrp.CFrame
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 9))
		moved = true
		task.wait(0.25)
	end
	local pages = math.max(1, math.floor(H.State.CashPages or 6))
	local total = 0
	for i = 1, pages do
		if not H.Alive then break end
		total = total + clickCards()
		if i < pages then
			if not flipNext() then break end
			task.wait(0.4)
		end
	end
	H.Stats.Cash = H.Stats.Cash + (total > 0 and 1 or 0)
	if moved and home then
		local h2 = H.hrp()
		if h2 then h2.CFrame = home end
	end
	busy = false
	return total
end

----------------------------------------------------------------------
-- ตัวรวม: ทำตามวิธีที่เลือก
----------------------------------------------------------------------
local function hasMethod(name)
	local sel = H.State.CashMethods
	if type(sel) ~= "table" then return sel == name end
	for _, v in pairs(sel) do
		if v == name then return true end
	end
	return false
end

local function collectCash()
	if hasMethod(M_REMOTE) then
		if H.fire("CollectAllCardCash") then H.Stats.Cash = H.Stats.Cash + 1 end
	end
	if hasMethod(M_BINDER) then
		collectBinder()
	end
end

H.State.CashMethods = { M_REMOTE }

H.toggle(SecAuto, "ออโต้เก็บเงินการ์ด (ไม่ต้องกดทีละหน้า)", "CashPro", false, nil,
	"เก็บเงินตามวิธีที่เลือกด้านล่างซ้ำทุกช่วงเวลา")
H.slider(SecAuto, "เก็บทุก", "CashProDelay", 2, 120, 10, " วิ")
H.dropdown(SecAuto, "วิธีเก็บ", "CashMethods", { M_REMOTE, M_BINDER }, { M_REMOTE }, true)
H.slider(SecAuto, "จำนวนหน้าสมุดที่ไล่เก็บ", "CashPages", 1, 40, 6, " หน้า")
H.toggle(SecAuto, "วาร์ปไปใกล้สมุดก่อน (แล้วกลับที่เดิม)", "CashNear", true, nil,
	"จำเป็นสำหรับการพลิกหน้า เพราะเซิร์ฟเวอร์เช็กระยะ")

H.loop("CashPro", function() return H.State.CashProDelay or 10 end, collectCash)

----------------------------------------------------------------------
-- สถานะ / เครื่องมือ
----------------------------------------------------------------------
local L_cash = SecInfo:Label("เงินตอนนี้: -")
local L_cnt  = SecInfo:Label("เก็บแล้ว: 0 ครั้ง")

local function cashText()
	local g = PlayerGui:FindFirstChild("CashGui")
	local l = g and g:FindFirstChild("CashLabel", true)
	return l and l:IsA("TextLabel") and l.Text or "-"
end

task.spawn(function()
	while H.Alive do
		pcall(function()
			L_cash:SetText("เงินตอนนี้: " .. cashText())
			L_cnt:SetText("เก็บแล้ว: " .. H.Stats.Cash .. " ครั้ง")
		end)
		task.wait(1)
	end
end)

SecInfo:Button():Add("เก็บเดี๋ยวนี้", function()
	task.spawn(function()
		local ok, e = pcall(collectCash)
		if not ok then H.err("cash", e) end
		H.notify("เก็บเงิน", "สั่งเก็บแล้ว", 2)
	end)
end):Add("พลิกหน้าถัดไป", function()
	local ok = flipNext()
	H.notify("สมุดการ์ด", ok and "พลิกหน้าแล้ว" or "พลิกไม่ได้ (ไม่มี fireclickdetector หรือไม่พบสมุด)", 3)
end)

SecInfo:Button():Add("ทดสอบกดการ์ดหน้านี้", function()
	task.spawn(function()
		local n = clickCards()
		H.notify("สมุดการ์ด", "กดการ์ดที่มีเงิน " .. tostring(n) .. " ใบ", 3)
	end)
end):Add("สแกนสมุดใหม่", function()
	bTime = 0
	H.notify("สมุดการ์ด", "พบสมุด " .. #getBinders() .. " เล่ม", 3)
end)

SecInfo:Label({
	Name = "คำแนะนำ",
	Description = "เริ่มจากวิธีรีโมตก่อน ถ้าเงินไม่เข้า ให้เปิดวิธี กดการ์ดในสมุด ด้วย (ทดสอบด้วยปุ่ม ทดสอบกดการ์ดหน้านี้ ว่ากดแล้วเงินเข้าไหม ถ้ามีหน้าต่างอื่นเด้งขึ้นมาแสดงว่าวิธีนี้ไม่เหมาะกับเกมนี้ ให้ปิด)",
})
