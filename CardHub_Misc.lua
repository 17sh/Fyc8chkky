--[[
	CardHub_Misc.lua : หน้า "เบ็ดเตล็ด"
	  - ฝั่งเซิร์ฟเวอร์: Rejoin / ย้ายเซิร์ฟเวอร์ / คัดลอก JobId / Rejoin อัตโนมัติเมื่อหลุด
	  - ฝั่งเครื่องมือ: ใส่โค้ดรับของ / ตัวยิง Remote (เฉพาะที่ปลอดภัย) / ยูทิลิตี้ / ปิดสคริปต์

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
]]

local H = ...
local Window = H.Window
local Players = H.Players
local TeleportService = game:GetService("TeleportService") -- ใช้ย้ายเซิร์ฟเวอร์/เข้าเกมใหม่
local HttpService = game:GetService("HttpService")         -- ใช้แปลง JSON ของรายชื่อเซิร์ฟเวอร์

local Page = Window:CreatePage({ Name = "เบ็ดเตล็ด" })
local SecServer = Page:CreateSection({ Name = "เซิร์ฟเวอร์", Side = 1, Collapsed = false })
local SecTools  = Page:CreateSection({ Name = "เครื่องมือ", Side = 2, Collapsed = false })

-- ข้อความ placeholder ของดรอปดาวน์ตอนไม่มีรายการ (ใช้เทียบในโค้ดด้วย จึงเก็บเป็นค่าคงที่ที่เดียว)
local NONE = "(ไม่มี)"

----------------------------------------------------------------------
-- เซิร์ฟเวอร์
----------------------------------------------------------------------

-- Rejoin = เข้าเซิร์ฟเวอร์เดิมอีกครั้ง
-- ถ้าเราอยู่คนเดียวในเซิร์ฟเวอร์ จะเข้าเซิร์ฟเวอร์เดิมไม่ได้ (เซิร์ฟเวอร์ปิดทันทีที่เราออก)
-- จึงเตะตัวเองออกก่อนแล้วเข้าเกมใหม่ (ได้เซิร์ฟเวอร์ใหม่)
local function rejoin()
	H.notify("เซิร์ฟเวอร์", "กำลัง Rejoin...", 3)
	if #Players:GetPlayers() <= 1 then
		pcall(function() H.lp:Kick("\nกำลัง Rejoin...") end)
		task.wait(0.5)
		TeleportService:Teleport(game.PlaceId, H.lp)
	else
		-- มีคนอื่นอยู่ด้วย: กลับเข้า "ห้อง" เดิมได้ด้วย JobId
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, H.lp)
	end
end

-- ดึงข้อมูลจาก URL ผ่านฟังก์ชันของ executor (แต่ละตัวชื่อฟังก์ชันไม่เหมือนกัน จึงไล่ลองทีละแบบ)
-- คืนข้อความเนื้อหา หรือ nil ถ้าดึงไม่ได้
local function httpGet(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok then return body end
	end
	local req = (syn and syn.request) or request or http_request or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res and res.Body then return res.Body end
	end
	return nil
end

-- ย้ายเซิร์ฟเวอร์ (Server Hop)
-- mode: "small" = เลือกเซิร์ฟเวอร์ที่คนน้อยที่สุด / "any" = เอาเซิร์ฟเวอร์แรกที่ยังไม่เต็ม
-- (ค่า "small"/"any" เป็นค่าภายในโค้ด ไม่ใช่ข้อความที่ผู้ใช้เห็น จึงไม่แปล)
local function hop(mode)
	H.notify("ย้ายเซิร์ฟเวอร์", "กำลังหาเซิร์ฟเวอร์...", 3)
	task.spawn(function()
		-- API สาธารณะของ Roblox: ขอรายชื่อเซิร์ฟเวอร์ 100 อันดับ (Asc = คนน้อยก่อน, Desc = คนมากก่อน)
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
			.. "/servers/Public?sortOrder=" .. (mode == "small" and "Asc" or "Desc") .. "&limit=100"
		local body = httpGet(url)
		local ok, data = pcall(function() return HttpService:JSONDecode(body or "") end)
		if not (ok and data and data.data) then
			H.notify("ย้ายเซิร์ฟเวอร์", "ดึงรายชื่อเซิร์ฟเวอร์ไม่ได้", 4)
			return
		end
		local best
		for _, s in ipairs(data.data) do
			-- ข้ามเซิร์ฟเวอร์ปัจจุบัน และเซิร์ฟเวอร์ที่เต็มแล้ว
			if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
				if not best or (mode == "small" and s.playing < best.playing) then
					best = s
					if mode ~= "small" then break end -- โหมด any เจออันแรกก็พอ
				end
			end
		end
		if best then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, H.lp)
		else
			H.notify("ย้ายเซิร์ฟเวอร์", "ไม่พบเซิร์ฟเวอร์ที่เหมาะสม", 4)
		end
	end)
end

-- ปุ่มสองอันต่อแถว (ต่อด้วย :Add)
SecServer:Button():Add("Rejoin", rejoin):Add("ย้ายเซิร์ฟ (คนน้อย)", function() hop("small") end)
SecServer:Button():Add("ย้ายเซิร์ฟ (ทั่วไป)", function() hop("any") end)
	:Add("คัดลอก JobId", function()
		-- setclipboard เป็นฟังก์ชันของ executor
		if setclipboard then setclipboard(game.JobId) H.notify("เซิร์ฟเวอร์", "คัดลอก JobId แล้ว", 2) end
	end)

----------------------------------------------------------------------
-- Rejoin อัตโนมัติเมื่อหลุด/ถูกเตะ
-- หลักการ: เมื่อหลุด Roblox จะสร้างหน้าต่าง "ErrorPrompt" ใน CoreGui.RobloxPromptGui.promptOverlay
-- เราดักตอนมี ErrorPrompt โผล่ขึ้นมา แล้วเข้าเกมใหม่
----------------------------------------------------------------------
H.toggle(SecServer, "Rejoin อัตโนมัติเมื่อหลุด", "AutoRejoin", true, nil,
	"เมื่อขึ้นหน้าจอ error จะ Rejoin อัตโนมัติ (ใช้คู่กับ Auto Execute ใน Settings)")

local rejoining = false -- กันสั่ง Rejoin ซ้ำหลายรอบ
pcall(function()
	local cg = game:GetService("CoreGui")
	local overlay = cg:WaitForChild("RobloxPromptGui", 10) -- รอสูงสุด 10 วินาที
	overlay = overlay and overlay:WaitForChild("promptOverlay", 10)
	if overlay then
		H.conn(overlay.ChildAdded, function(c)
			-- "ErrorPrompt" คือชื่อวัตถุของ Roblox เอง ห้ามแปล
			if c.Name == "ErrorPrompt" and H.State.AutoRejoin and not rejoining then
				rejoining = true
				task.wait(2) -- รอสักครู่ให้หน้าต่างขึ้นครบก่อน
				pcall(function() TeleportService:Teleport(game.PlaceId, H.lp) end)
			end
		end)
	end
end)

----------------------------------------------------------------------
-- ใส่โค้ดรับของ (Redeem Code)
----------------------------------------------------------------------
local codeText = ""
SecTools:Textbox({
	Name = "โค้ด", Flag = "CodeBox", Placeholder = "ใส่โค้ดจากผู้พัฒนา",
	Finished = true, -- Finished = true : เรียก Callback เมื่อพิมพ์เสร็จ (กด Enter/ออกจากช่อง) ไม่ใช่ทุกตัวอักษร
	Callback = function(t) codeText = t or "" end,
})
SecTools:Button({ Name = "ใช้โค้ด", Callback = function()
	-- gsub ตัดช่องว่างหน้า-หลังข้อความ
	local c = codeText:gsub("^%s+", ""):gsub("%s+$", "")
	if c == "" then H.notify("ใช้โค้ด", "ใส่โค้ดก่อน", 2) return end
	H.fire("RedeemCode", c) -- ยิง Remote ชื่อ RedeemCode พร้อมโค้ดที่พิมพ์
	H.notify("ใช้โค้ด", "ส่งโค้ด " .. c .. " แล้ว", 3)
end })

----------------------------------------------------------------------
-- ตัวยิง Remote (Remote Launcher)
-- ยิง Remote แบบไม่ส่งค่า เฉพาะตัวที่ "ไม่เกี่ยวกับเงิน/เทรด/ลบ" เท่านั้น
-- ชื่อ Remote ที่มีคำต้องห้ามด้านล่างจะถูกตัดออกจากรายการ (คำเหล่านี้คือชื่อใน "เกม" จึงเป็นอังกฤษ)
----------------------------------------------------------------------
local BLOCK = {
	"Purchase", "Buy", "Robux", "Gift", "Trade", "Delete", "Sell", "Salvage", "Fuse", "Burn",
	"Leave", "Reroll", "Craft", "Integrity", "Chat", "Block", "Party", "Clan", "Auction", "Pvp", "PvP",
}
-- คืน true ถ้าชื่อ Remote ไม่มีคำต้องห้ามอยู่เลย (find แบบ plain ไม่ตีความ pattern)
local function allowed(name)
	for _, b in ipairs(BLOCK) do
		if name:find(b, 1, true) then return false end
	end
	return true
end

-- รวบรวมชื่อ Remote ที่ยิงได้ใน ReplicatedStorage.Remotes เรียงตามตัวอักษร
local function remoteList()
	local t = {}
	local f = H.remotes() -- โฟลเดอร์ Remotes
	if f then
		for _, r in ipairs(f:GetChildren()) do
			if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and allowed(r.Name) then
				t[#t + 1] = r.Name
			end
		end
	end
	table.sort(t)
	if #t == 0 then t[1] = NONE end -- ไม่มีรายการ ใส่ placeholder กันดรอปดาวน์ว่าง
	return t
end

local rd = H.dropdown(SecTools, "Remote", "RemotePick", remoteList(), nil, false)
SecTools:Button():Add("ยิง (ไม่ส่งค่า)", function()
	local n = H.State.RemotePick
	if not n or n == NONE then return end
	if H.fire(n) then H.notify("Remote", "ยิง " .. n .. " แล้ว", 2) end
end):Add("รีเฟรช", function()
	pcall(function() rd:Refresh(remoteList()) end) -- โหลดรายการใหม่เข้าดรอปดาวน์
end)

SecTools:Label({
	Name = "รายการปลอดภัย",
	Description = "รายการนี้ตัด remote ที่เกี่ยวกับซื้อ/ขาย/เทรด/ลบ/คราฟต์/ต่อสู้ออกให้แล้ว",
})

----------------------------------------------------------------------
-- ยูทิลิตี้
----------------------------------------------------------------------
SecTools:Button():Add("คัดลอก PlaceId", function()
	if setclipboard then setclipboard(tostring(game.PlaceId)) H.notify("เบ็ดเตล็ด", "คัดลอก PlaceId แล้ว", 2) end
end):Add("ดูข้อมูลแปลง", function()
	-- นับจำนวนแพ็กที่เก็บได้ในแปลงของเราแล้วแจ้งเตือน
	local plot = H.myPlot()
	if not plot then H.notify("เบ็ดเตล็ด", "ไม่พบแปลงของคุณ", 3) return end
	local packs = 0
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == "Collect" then packs = packs + 1 end
	end
	H.notify("แปลง", plot.Name .. " | แพ็กที่เก็บได้: " .. packs, 5)
end)

-- ปิดสคริปต์ทั้งหมด: ถามยืนยันก่อน แล้วเรียก H.Stop() ซึ่งจะ
-- หยุดทุกลูป ตัด event ทั้งหมด คืนค่าที่แก้ไว้ (ความเร็ว/แสง ฯลฯ) และลบเมนู
SecTools:Button({ Name = "ปิดสคริปต์ (หยุดทุกอย่าง)", Callback = function()
	H.Library:ConfirmDialog({
		Message = "ปิดสคริปทั้งหมดและลบเมนู?",
		OnConfirm = function() H.Stop() end,
	})
end })
