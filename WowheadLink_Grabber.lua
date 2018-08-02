local tooltipInfo = {}
local customframes;
local wowheadLink = "wowhead.com/"
local hash = ""
local frame = CreateFrame("Frame")
local gotoLink = ""
local QuestMapFrame_IsQuestWorldQuest = QuestMapFrame_IsQuestWorldQuest or QuestUtils_IsQuestWorldQuest

local validfounds = {
	npc = "",
	spell = GetSpellInfo,
	achievement = function(id)
		return select(2, GetAchievementInfo(id))
	end,
	quest = function(id)
		for i = 1, GetNumQuestLogEntries() do
			local name, _, _, _, _, _, _, qid = GetQuestLogTitle(i)
			if id == qid then
				return name
			end
		end
		return "Quest";
	end,
	item = GetItemInfo
}

local function clearTooltipInfo(tooltip)
	wipe(tooltipInfo[tooltip])
end

local function setTooltipHyperkink(tooltip, hyperlink)
	local ttable = tooltipInfo[tooltip];
	ttable.hl = hyperlink;
end

local function setTooltipAura(tooltip, unit, index, filter)
	local ttable = tooltipInfo[tooltip];
	local name = UnitAura(unit, index, filter);
	local id = select(10, UnitAura(unit, index, filter));
	--print("Name: "..name.." = ID: "..id)
	ttable.aura = id
	ttable.name = name
end

local function hookTooltip(tooltip)
	tooltipInfo[tooltip] = {}
	hooksecurefunc(tooltip, "SetHyperlink", setTooltipHyperkink)
	hooksecurefunc(tooltip, "SetUnitAura", setTooltipAura)
	tooltip:HookScript("OnTooltipCleared", clearTooltipInfo)
end

local function onEvent(frame, event)
	if event == "PLAYER_ENTERING_WORLD" then
		hookTooltip(GameTooltip)
		hookTooltip(ItemRefTooltip)
	end
end

local function onUpdate()
	StaticPopup_Show("WOWHEAD_LINK_GRABBER")
	frame:Hide();
end

local function found(ftype, id, name)
	local foundAccept = validfounds[ftype];
	if foundAccept then
		name = name or foundAccept;
		if type(name) == 'function' then
			name = name(id);
		end
		name = name or ftype;
		--print("Found "..type.." "..id)
		-- Show frame to recieve OnUpdate next frame
		-- So pressed hotkey doesnt erase text field
		gotoLink = "http://" .. wowheadLink .. ftype .. "=" .. id .. hash;
		local upper_name = firstToUpper(ftype)
		if QuestMapFrame_IsQuestWorldQuest(id) then
			upper_name = firstToUpper("World Quest");
		end
		StaticPopupDialogs["WOWHEAD_LINK_GRABBER"].text = "|cffffff00"..upper_name .. ":\n|r" .. name .. "\n\n|cff00ff00CTRL+C to copy!|r";
		frame:Show();
		return true;
	end
end

local function foundplayer(name)
	return true;
end

local function getUnitInfo(unit, name)
	if UnitIsPlayer(unit) then
		return foundplayer(name)
	else
		local GUID = UnitGUID(unit)
		local type, _, _, _, _, id = strsplit("-", GUID);
		if type == "Creature" then return found("npc", id, name) end
	end
end

local function getFocusInfo()
	local focus = GetMouseFocus()
	local current = focus;
	local focusname;
	--__LASTFRAME = focus;
	while current and not focusname do

		-- Added by fuba82 for World Quest support
		if WorldMapFrame and WorldMapFrame:IsVisible() and current and current.questID and QuestMapFrame_IsQuestWorldQuest(current.questID) then
			return found("quest", current.questID, select(4, GetTaskInfo(current.questID)))
		end

		focusname = current:GetName()
		current = current:GetParent()
	end

	if not focusname then return end
	local focuslen = string.len(focusname);
	--print(focusname);
	for name, func in pairs(customframes) do
		local customlen = string.len(name)
		if customlen <= focuslen and name == string.sub(focusname, 1, customlen) then
			if func(focus, focusname) then return true end
		end
	end
end

local function parseLink(link)
	local linkstart = string.find(link, "|H")
	local _, lastfound, type, id = string.find(link, "(%a+):(%d+):", linkstart and linkstart + 2)
	local _, _, name = string.find(link, "%[([^%[%]]*)%]", lastfound)
	return found(type, id, name)
end

local function parseTooltip(tooltip)
	local name, link = tooltip:GetItem()
	if name then return parseLink(link) end
	--local name, _, id = tooltip:GetSpell();
	local name, id = tooltip:GetSpell();
	if name then return found("spell", id, name) end
	local name, unit = tooltip:GetUnit()
	if unit then return getUnitInfo(unit, name) end
	local ttdata = tooltipInfo[tooltip];
	if ttdata.hl then return parseLink(ttdata.hl) end
	if ttdata.aura then return found("spell", ttdata.aura, ttdata.name) end
end

local function linkGrabberRunInternal()
	return parseTooltip(ItemRefTooltip)
	or parseTooltip(GameTooltip)
	or getFocusInfo()
end

linkGrabberRun = function()
	linkGrabberRunInternal()
	--pcall(linkGrabberRunInternal);
end

-- Formatting
function firstToUpper(str)
	return (str:gsub("^%l", string.upper))
end

-- Custom frames mouseover

local function AchievmentWidget(widget)
	return found("achievement", widget.id);
end

local function AchievmentWidgetParent(widget)
	return AchievmentWidget(widget:GetParent())
end

local function QuestWidget(widget)
	if widget.questID then return found("quest", widget.questID) end
end

local function TrackWidget(widget)
	local parent = widget:GetParent()
	local module = parent.module;
	if module == QUEST_TRACKER_MODULE then
		return found("quest", parent.id)
	elseif module == ACHIEVEMENT_TRACKER_MODULE then
		return found("achievement", parent.id)
	end
end

-- Added by fuba82 for World Quest support
local function TrackWorldQuestWidget(widget)
	local module = widget.module;
	if module == WORLD_QUEST_TRACKER_MODULE then
		if widget.id then
			return found("quest", widget.id, select(4, GetTaskInfo(widget.id)))
		end
	elseif widget.questID then -- World Quest Tracker support
		if QuestMapFrame_IsQuestWorldQuest(widget.questID) then
			return found("quest", widget.questID, select(4, GetTaskInfo(widget.questID)))
		end
	end
end

customframes = {
	["AchievementFrameCriteria"] = AchievmentWidgetParent,
	["AchievementFrameSummaryAchievement"] = AchievmentWidget,
	["AchievementFrameAchievementsContainerButton"] = AchievmentWidget,
	["QuestScrollFrame"] = QuestWidget,
	["ObjectiveTrackerBlocksFrameHeader"] = TrackWidget,

	-- Added by fuba82 for World Quest support
	["ObjectiveTrackerBlocksFrame"] = TrackWorldQuestWidget,
	["WorldMapFrameTaskPOI"] = WolrdQuestWidget,
	["WorldQuestTrackerZonePOIWidget"] = WolrdQuestWidget, -- World Quest Tracker support
	["WorldQuestTracker_Tracker"] = TrackWorldQuestWidget -- World Quest Tracker support
}

frame:Hide()
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", onUpdate)

local locale = string.sub(GetLocale(), 1, 2)
if locale ~= "en" then
	wowheadLink = locale.."."..wowheadLink
	hash = "#english-comments"
end

BINDING_HEADER_LINK_GRABBER_HEAD = "Wowhead Link Grabber"
BINDING_DESCRIPTION_LINK_GRABBER_DESC = "Hotkey for displaying wowhead link"
BINDING_NAME_LINK_GRABBER_NAME = "Generate Link"

StaticPopupDialogs["WOWHEAD_LINK_GRABBER"] = {
	OnShow = function (self, data)
		self.editBox:SetText(gotoLink)
		self.editBox:HighlightText()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	EditBoxOnTextChanged = function(self)
		self:SetText(gotoLink)
		self:HighlightText()
	end,
	button1 = OKAY,
	editBoxWidth = 350,
	hasEditBox = true,
	preferredIndex = 3
}
