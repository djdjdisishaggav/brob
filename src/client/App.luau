-- Client composition root: builds the lobby screens, feeds them the state the
-- server sent, and turns their callbacks into server requests. All decisions
-- about parties are made by the server; this file only routes.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Store = require(script.Parent.Store)
local UI = script.Parent.UI
local Kit = require(UI.Kit)
local CreatePartyPanel = require(UI.CreatePartyPanel)
local Hud = require(UI.Hud)
local InviteCards = require(UI.InviteCards)
local InvitePicker = require(UI.InvitePicker)
local JoinPrompt = require(UI.JoinPrompt)
local NotificationCenter = require(UI.NotificationCenter)
local PartyPanel = require(UI.PartyPanel)
local SettingsPanel = require(UI.SettingsPanel)
local TeleportOverlay = require(UI.TeleportOverlay)
local Toasts = require(UI.Toasts)

local Action = Net.Action
local Phase = Net.Phase
local Status = Net.StationStatus

local App = {}

local started = false

function App.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local state = Store.state

	local hudGui = Kit.screen("MG_Hud", 5, playerGui)
	local hudLayer = Kit.layer("Layer", hudGui)
	local panelGui = Kit.screen("MG_Panels", 6, playerGui)
	local dialogGui = Kit.screen("MG_Dialogs", 7, playerGui)
	local dialogLayer = Kit.layer("Layer", dialogGui)
	local overlayGui = Kit.screen("MG_Overlay", 8, playerGui)
	overlayGui.IgnoreGuiInset = true

	local hud, createPanel, partyPanel, joinPrompt, inviteCards, picker, settingsPanel, notifications, toasts, overlay
	local openPopover: string? = nil
	local pickerMode: string? = nil

	local function candidates()
		local list = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(list, { userId = other.UserId, name = other.Name, displayName = other.DisplayName })
			end
		end
		table.sort(list, function(a, b)
			return a.displayName:lower() < b.displayName:lower()
		end)
		return list
	end

	local function closePicker()
		pickerMode = nil
		picker:Close()
	end

	local function setPopover(id: string?)
		openPopover = id
		if id == "settings" then
			settingsPanel:Render(state.settings)
			settingsPanel:Open()
		else
			settingsPanel:Close()
		end
		if id == "notifications" then
			notifications:Render(state.notifications)
			notifications:Open()
			Store.markNotificationsRead()
		else
			notifications:Close()
		end
		hud:SetSelected(id)
	end

	-- Ambient particle effects are a local preference; remember which emitters the lobby shipped enabled.
	local ambientEmitters: { ParticleEmitter }? = nil
	local function applySettings()
		local settings = state.settings
		Kit.reduceMotion = settings.reduceMotion == true
		Kit.setUserScale(Config.Settings.UiScaleFactors[settings.uiScale] or 1)

		local lobby = Workspace:FindFirstChild(Config.World.ModelName)
		if not ambientEmitters and lobby then
			local found = {}
			for _, descendant in lobby:GetDescendants() do
				if descendant:IsA("ParticleEmitter") and descendant.Enabled then
					table.insert(found, descendant)
				end
			end
			ambientEmitters = found
		end
		for _, emitter in ambientEmitters or {} do
			emitter.Enabled = settings.ambientEffects ~= false
		end
	end

	-- Decides what a station pad offers this player right now.
	local function showStation(stationId: string)
		local station = state.stations[stationId]
		if not station or station.status == Status.Available then
			joinPrompt:Hide()
			setPopover(nil)
			createPanel:Open(stationId, state.progress)
		else
			createPanel:Close()
			if pickerMode == "queue" then
				closePicker()
			end
			joinPrompt:Show(station)
		end
	end

	local function hideStationFlows()
		createPanel:Close()
		joinPrompt:Hide()
		if pickerMode == "queue" then
			closePicker()
		end
	end

	local function refreshParty()
		local party = state.party
		partyPanel:Render(party)
		hud:SetPartySize(if party then #party.members else nil)

		if not party then
			overlay:Hide()
			if pickerMode == "send" then
				closePicker()
			end
			return
		end

		hideStationFlows()
		if party.phase == Phase.Teleporting then
			local chapter = Config.getChapter(party.chapterId)
			local difficulty = Config.getDifficulty(party.difficultyId)
			overlay:Show({
				chapterName = if chapter then chapter.Name else party.chapterId,
				difficultyName = if difficulty then difficulty.Name else party.difficultyId,
				peaceful = party.peaceful,
				memberCount = #party.members,
			})
		else
			overlay:Hide()
		end

		if pickerMode == "send" then
			local isLeader = party.leaderUserId == player.UserId
			if party.phase ~= Phase.Forming or not isLeader or #party.members >= party.maxSize then
				closePicker()
			else
				local pendingIds, memberIds = {}, {}
				for _, invite in party.invites do
					table.insert(pendingIds, invite.userId)
				end
				for _, member in party.members do
					table.insert(memberIds, member.userId)
				end
				picker:SetPending(pendingIds, memberIds)
			end
		end
	end

	local function refreshStations()
		if state.party then
			return
		end
		local promptStation = joinPrompt:GetStationId()
		if joinPrompt:IsShown() and promptStation then
			showStation(promptStation)
		elseif createPanel:IsOpen() then
			local stationId = createPanel:GetStationId()
			local station = stationId and state.stations[stationId]
			if stationId and station and station.status ~= Status.Available then
				showStation(stationId)
			end
		end
	end

	toasts = Toasts.new({ parent = dialogLayer })

	hud = Hud.new({
		parent = hudLayer,
		player = player,
		playerGui = playerGui,
		onToggle = function(id)
			if id == "party" then
				if state.party then
					partyPanel:SetCollapsed(not partyPanel:IsCollapsed())
				else
					toasts:Push(Net.NoticeLevel.Info, "Step onto a station pad to create or join a party.")
				end
			else
				setPopover(if openPopover == id then nil else id)
			end
		end,
	})

	settingsPanel = SettingsPanel.new({
		parent = hudLayer,
		onChange = function(key, value)
			state.settings[key] = value
			applySettings()
			return Store.request(Action.UpdateSetting, { key = key, value = value })
		end,
		onClose = function()
			setPopover(nil)
		end,
	})

	notifications = NotificationCenter.new({
		parent = hudLayer,
		serverNow = Store.serverNow,
		onClose = function()
			setPopover(nil)
		end,
	})

	picker = InvitePicker.new({ parent = dialogLayer, getCandidates = candidates })

	createPanel = CreatePartyPanel.new({
		parent = panelGui,
		localUser = { userId = player.UserId, displayName = player.DisplayName },
		onCreate = function(params)
			return Store.request(Action.CreateParty, params)
		end,
		onBack = function()
			hideStationFlows()
		end,
		pickInvites = function(selected, limit, onChanged)
			pickerMode = "queue"
			picker:Open({
				title = "Invite guardians",
				mode = "queue",
				selected = selected,
				limit = limit,
				onChanged = onChanged,
			})
		end,
	})

	partyPanel = PartyPanel.new({
		parent = hudLayer,
		localUserId = player.UserId,
		serverNow = Store.serverNow,
		onReady = function(ready)
			return Store.request(Action.SetReady, { ready = ready })
		end,
		onLeave = function()
			return Store.request(Action.LeaveParty)
		end,
		onStart = function()
			return Store.request(Action.Start)
		end,
		onCancel = function()
			return Store.request(Action.CancelCountdown)
		end,
		onCancelInvite = function(userId)
			return Store.request(Action.CancelInvite, { userId = userId })
		end,
		onOpenInvite = function()
			local party = state.party
			if not party then
				return
			end
			local pendingIds, memberIds = {}, {}
			for _, invite in party.invites do
				table.insert(pendingIds, invite.userId)
			end
			for _, member in party.members do
				table.insert(memberIds, member.userId)
			end
			pickerMode = "send"
			picker:Open({
				title = "Invite to party",
				mode = "send",
				pendingIds = pendingIds,
				memberIds = memberIds,
				onInvite = function(user)
					return Store.request(Action.Invite, { userId = user.userId })
				end,
			})
		end,
	})

	joinPrompt = JoinPrompt.new({
		parent = hudLayer,
		onJoin = function(stationId)
			return Store.request(Action.JoinStationParty, { stationId = stationId })
		end,
		onDismiss = function()
			joinPrompt:Hide()
		end,
	})

	inviteCards = InviteCards.new({
		parent = hudLayer,
		serverNow = Store.serverNow,
		onRespond = function(inviteId, accept)
			return Store.request(Action.RespondInvite, { inviteId = inviteId, accept = accept })
		end,
	})

	overlay = TeleportOverlay.new({ parent = overlayGui })

	Store.changed:Connect(function(key)
		if key == "party" then
			refreshParty()
		elseif key == "stations" then
			refreshStations()
		elseif key == "invites" then
			inviteCards:Render(state.invites)
			hud:SetInviteCount(#state.invites)
		elseif key == "notifications" then
			hud:SetUnread(state.unread)
			if openPopover == "notifications" then
				notifications:Render(state.notifications)
				Store.markNotificationsRead()
			end
		elseif key == "settings" then
			applySettings()
			settingsPanel:Render(state.settings)
		elseif key == "progress" then
			createPanel:SetProgress(state.progress)
		end
	end)

	Store.presenceChanged:Connect(function(stationId, viaPrompt)
		if state.party then
			return
		end
		if not stationId then
			hideStationFlows()
		elseif viaPrompt or not createPanel:IsOpen() or createPanel:GetStationId() ~= stationId then
			showStation(stationId)
		end
	end)

	Store.noticed:Connect(function(notice)
		toasts:Push(notice.level, notice.text)
	end)

	local function onRosterChanged()
		if picker:IsOpen() then
			-- PlayerRemoving fires before the player leaves the Players list.
			task.defer(function()
				if picker:IsOpen() then
					picker:Refresh()
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(onRosterChanged)
	Players.PlayerRemoving:Connect(onRosterChanged)

	applySettings()
	settingsPanel:Render(state.settings)

	Store.start()

	refreshParty()
	inviteCards:Render(state.invites)
	hud:SetInviteCount(#state.invites)
	if not state.party and state.presence then
		showStation(state.presence)
	end
end

return App
