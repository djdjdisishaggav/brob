-- Drives the physical displays of one matchmaking station from a
-- Net.StationSnapshot: status board, pad ring, slot lanterns and name plates.
--
-- The view only changes instances whose value actually differs, so it can be
-- rendered every heartbeat or countdown tick without replication churn.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")
local Net = require(shared:WaitForChild("Net"))
local Theme = require(shared:WaitForChild("Theme"))

local Palette = require(script.Parent.Palette)

local StationView = {}
StationView.__index = StationView

StationView.SlotState = {
	Filled = "Filled",
	Empty = "Empty",
	Closed = "Closed",
}

StationView.SlotCount = 4

local SLOT = StationView.SlotState
local STATUS = Net.StationStatus
local SEPARATOR = "  ·  "

export type SlotDescription = { state: string, name: string }

export type Description = {
	status: string,
	label: string,
	color: Color3,
	detail: string,
	info: string,
	slots: { SlotDescription },
}

-- Pure translation of a snapshot into what the station shows.
function StationView.describe(snapshot: Net.StationSnapshot, serverNow: number): Description
	local status = snapshot.status
	local style = Theme.Status[status]
	if not style then
		status = STATUS.Unavailable
		style = Theme.Status[status]
	end

	local memberCount = math.max(0, snapshot.memberCount or 0)
	local maxSize = math.clamp(snapshot.maxSize or 0, 0, StationView.SlotCount)
	local hasParty = snapshot.partyId ~= nil or memberCount > 0

	local detail: string
	if status == STATUS.Available then
		detail = "Step on the pad to create a party"
	elseif status == STATUS.Occupied then
		detail = `{snapshot.leaderName or "Guardian"}'s party  {memberCount}/{maxSize}`
	elseif status == STATUS.Full then
		detail = `Party full  {maxSize}/{maxSize}`
	elseif status == STATUS.Starting then
		local remaining = if snapshot.countdownEndsAt then math.ceil(snapshot.countdownEndsAt - serverNow) else 0
		detail = if remaining > 0 then `Departing in {remaining}` else "Departing..."
	elseif status == STATUS.Error then
		detail = snapshot.message or "Teleport failed"
	else
		detail = snapshot.message or "Closed for now"
	end

	local info = ""
	if hasParty then
		local parts = {}
		if snapshot.chapterName then
			table.insert(parts, snapshot.chapterName)
		end
		if snapshot.difficultyName then
			table.insert(parts, snapshot.difficultyName)
		end
		if snapshot.peaceful then
			table.insert(parts, "Peaceful")
		end
		info = table.concat(parts, SEPARATOR)
	end

	local slots = table.create(StationView.SlotCount)
	for index = 1, StationView.SlotCount do
		if index <= memberCount then
			slots[index] = { state = SLOT.Filled, name = snapshot.memberNames[index] or "Guardian" }
		elseif index <= maxSize then
			slots[index] = { state = SLOT.Empty, name = "Open" }
		else
			slots[index] = { state = SLOT.Closed, name = "" }
		end
	end

	return {
		status = status,
		label = style.Label,
		color = style.Color,
		detail = detail,
		info = info,
		slots = slots,
	}
end

local function need(root: Instance, name: string): any
	local found = root:FindFirstChild(name, true)
	if not found then
		error(`station {root.Name} is missing "{name}"`, 3)
	end
	return found
end

function StationView.new(stationModel: Model)
	local self = setmetatable({}, StationView)
	self.Model = stationModel
	self.StationId = stationModel:GetAttribute("StationId") or stationModel.Name
	self.Accent = Theme.Station[self.StationId] or Theme.Color.Amber400

	self._ring = need(stationModel, "Ring") :: BasePart
	self._ringInner = need(stationModel, "RingInner") :: BasePart
	self._glow = need(self._ringInner, "Glow") :: PointLight

	local board = need(stationModel, "StatusBoard")
	self._bar = need(board, "Bar") :: Frame
	self._status = need(board, "Status") :: TextLabel
	self._detail = need(board, "Detail") :: TextLabel
	self._info = need(board, "Info") :: TextLabel

	local slots = need(stationModel, "Slots")
	self._slots = table.create(StationView.SlotCount)
	for index = 1, StationView.SlotCount do
		local slot = need(slots, "Slot" .. index)
		self._slots[index] = {
			model = slot,
			core = need(slot, "Core") :: BasePart,
			light = need(slot, "Light") :: PointLight,
			shutter = need(slot, "Shutter") :: BasePart,
			label = need(need(slot, "Plate"), "Label") :: TextLabel,
		}
	end

	-- Last value written per target, so repeated renders are free.
	self._written = {}
	return self
end

function StationView:_set(key: string, instance: Instance, property: string, value: any)
	local id = key .. "." .. property
	if self._written[id] == value then
		return
	end
	self._written[id] = value;
	(instance :: any)[property] = value
end

function StationView:_attribute(key: string, instance: Instance, name: string, value: any)
	local id = key .. "@" .. name
	if self._written[id] == value then
		return
	end
	self._written[id] = value
	instance:SetAttribute(name, value)
end

function StationView:Render(snapshot: Net.StationSnapshot, serverNow: number)
	if not self.Model then
		return
	end
	local description = StationView.describe(snapshot, serverNow)
	local color = description.color
	local lit = description.status ~= STATUS.Unavailable

	self:_attribute("model", self.Model, "Status", description.status)

	local ringMaterial = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	self:_set("ring", self._ring, "Color", color)
	self:_set("ring", self._ring, "Material", ringMaterial)
	self:_set("ringInner", self._ringInner, "Color", color)
	self:_set("ringInner", self._ringInner, "Material", ringMaterial)
	self:_set("glow", self._glow, "Color", color)
	self:_set("glow", self._glow, "Enabled", lit)

	self:_set("bar", self._bar, "BackgroundColor3", color)
	self:_set("status", self._status, "Text", description.label)
	self:_set("status", self._status, "TextColor3", color)
	self:_set("detail", self._detail, "Text", description.detail)
	self:_set("info", self._info, "Text", description.info)
	-- Without a party line the detail takes the whole lower half of the board.
	local hasInfo = description.info ~= ""
	self:_set("info", self._info, "Visible", hasInfo)
	self:_set("detail", self._detail, "Size", if hasInfo then UDim2.new(1, -48, 0, 58) else UDim2.new(1, -48, 0, 86))

	for index, slot in self._slots do
		local key = "slot" .. index
		local slotDescription = description.slots[index]
		local state = slotDescription.state
		self:_attribute(key, slot.model, "State", state)
		self:_attribute(key, slot.model, "MemberName", slotDescription.name)

		if state == SLOT.Filled then
			self:_set(key .. "core", slot.core, "Material", Enum.Material.Neon)
			self:_set(key .. "core", slot.core, "Color", Theme.lighten(self.Accent, 0.12))
			self:_set(key .. "core", slot.core, "Transparency", 0)
			self:_set(key .. "label", slot.label, "TextColor3", Palette.SignText)
		elseif state == SLOT.Empty then
			self:_set(key .. "core", slot.core, "Material", Enum.Material.Glass)
			self:_set(key .. "core", slot.core, "Color", Palette.SignTextSoft)
			self:_set(key .. "core", slot.core, "Transparency", 0.62)
			self:_set(key .. "label", slot.label, "TextColor3", Palette.SignTextMuted)
		else
			self:_set(key .. "core", slot.core, "Material", Enum.Material.Glass)
			self:_set(key .. "core", slot.core, "Color", Palette.BarkDark)
			self:_set(key .. "core", slot.core, "Transparency", 1)
			self:_set(key .. "label", slot.label, "TextColor3", Palette.SignTextMuted)
		end
		self:_set(key .. "light", slot.light, "Enabled", state == SLOT.Filled)
		self:_set(key .. "light", slot.light, "Color", self.Accent)
		self:_set(key .. "shutter", slot.shutter, "Transparency", if state == SLOT.Closed then 0 else 1)
		self:_set(key .. "label", slot.label, "Text", slotDescription.name)
	end
end

function StationView:Destroy()
	self.Model = nil
	self._slots = {}
	self._written = {}
end

return StationView
