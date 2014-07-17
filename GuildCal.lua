-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildCal
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "ICCommLib"
require "GuildLib"
require "GameLib"

local GuildCal = {} 
			
function GuildCal:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	o.DayList = {"Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche" }
	o.MonthList = { "Janvier", "F\195\169vrier", "Mars", "Avril", "Mai", "Juin", "Juillet", "Ao\195\187t", "Septembre", "Octobre", "Novembre", "D\195\169cembre" }
	o.IconSprite = {
		Event="Icon_MapNode_Map_QuestHub",
		Donjon="Icon_Achievement_Achievement_Dungeon",
		Raid="Icon_Achievement_Achievement_Raid",
		Aventure="Icon_Achievement_Achievement_Adventures",
		Arena="Icon_Achievement_Achievement_PvP",
		Warplot="Icon_Achievement_Achievement_Reputation",
		Meeting="Icon_Achievement_Achievement_WorldEvent",
		Divers="Icon_Achievement_Achievement_Quest"
	}
	
	o.MonthCurrent = ""
	o.YearCurrent = ""
	
	o.DaySelect = ""
	o.MonthSelect = ""
	o.YearSelect = ""
	o.EventTab = {}
	o.EventRemoveTab = {}
	o.Guild = ""
	o.LastUpdate = ""
	
	
	self.bEventViewShown = false

    return o
end

function GuildCal:Init()
	Apollo.RegisterAddon(self,true,"GuildCal")
end

function GuildCal:OnLoad()	
	Apollo.RegisterSlashCommand("gcal", "OnGuildCalOn", self)
    
	self.wndMain = Apollo.LoadForm("GuildCal.xml", "Main", nil, self)
	self.wndDay = Apollo.LoadForm("GuildCal.xml", "ShowDay", nil, self)
	self.wndAddEvent = Apollo.LoadForm("GuildCal.xml", "AddEvent", nil, self)
    self.wndMain:Show(false)	
    self.wndDay:Show(false)	
    self.wndAddEvent:Show(false)	
		
	Event_FireGenericEvent("SendVarToRover", "GuildCal", self)
	
	self.channel = ICCommLib.JoinChannel(self:GetChannelName(),"OnMsgReceived",self)
	self:CleanEvent()
end

function GuildCal:OnGuildCalOn()
	self.wndMain:Invoke()
	
	self.MonthCurrent = tonumber(os.date("%m"))
	self.YearCurrent = tonumber(os.date("%Y"))
	
	-- self:AskUpdate()
	self:DisplayCalendar()
	
end

-----------------------------------------------------------------------------------------------
-- Display Functions
-----------------------------------------------------------------------------------------------

function GuildCal:DisplayCalendar()
	for i=1,31 do
		local DayBloc = self.wndMain:FindChild("DayBloc")
		if DayBloc ~= nil then
			DayBloc:FindChild("Text"):Destroy()
			DayBloc:Destroy()
		end
	end
	
	--Draw Month Name
	self.wndMain:FindChild("MonthBloc"):SetText(self.MonthList[self.MonthCurrent])
	
	--Draw Day Name
	for i =1, 7 do
		self.wndMain:FindChild("DayName"..i):SetText(self.DayList[i])
	end
	
	DayNumber = self:GetFirstDayNum()
	DayInMonth = self:GetDayInMonth(self.MonthCurrent, self.YearCurrent)
	-- Draw Days
	local X = 0
	local Y = 0
	local W = 60
	local H = 60
	local M = 2
	local CountLine = 1
	for i=1, DayInMonth do
		X = 0 + ( W + M ) * ( DayNumber - 1)
		local DayBloc= Apollo.LoadForm("GuildCal.xml", "DayBloc", self.wndMain:FindChild("Days"), self)
		DayBloc:SetAnchorOffsets(X, Y, X+W, Y+H)
		DayBloc:Show(true)
		DayBloc:FindChild("Text"):SetText(i)
		local EventIcon = DayBloc:FindChild("EventIcon")
		if i < 10 then
			EventIcon:SetName("EventIcon_0"..i)
		else
			EventIcon:SetName("EventIcon_"..i)
		end
		EventIcon:Show(false)
		
		if DayNumber == 7 and i ~= DayInMonth then
			DayNumber = 1
			Y = Y + ( H + M )
			CountLine = CountLine + 1
		else
			DayNumber = DayNumber + 1
		end
	end
		
	self:Resize(CountLine)
	self:DisplayDayIcon()
end

function GuildCal:Resize(CountLine)
	local X,Y,W,H = self.wndMain:GetAnchorOffsets()
	H = 150 + CountLine * 62 + 65 + Y
	self.wndMain:SetAnchorOffsets(X,Y,W,H)
end

function GuildCal:PopulateEventList()
	self.wndDay:FindChild("EventList"):DestroyChildren()
	local Day = tonumber(self.DaySelect)
	local Month = tonumber(self.MonthSelect)
	local DayEvent = self:GetDayEvent(Day, Month)
	for i=1,table.getn(DayEvent) do
		local Event = Apollo.LoadForm("GuildCal.xml", "Event", self.wndDay:FindChild("EventList"), self)
		Event:FindChild("Title"):SetText(DayEvent[i].Title)
		Event:FindChild("Hours"):SetText(DayEvent[i].Hours)
		Event:SetTooltip(DayEvent[i].Description)
		Event:SetData(DayEvent[i].Description)
		local Icon = DayEvent[i].Icon
		Event:FindChild("Icon"):SetSprite(self.IconSprite[DayEvent[i].Icon])
		Event:Show(true)
	end
	self.wndDay:FindChild("EventList"):ArrangeChildrenVert()
end

function GuildCal:DisplayDayIcon()
	local Month = tonumber(self.MonthCurrent)
	if Month < 10 then Month="0"..Month end
	for i=1,self:GetDayInMonth(Month, self.YearCurrent) do
		local Day = i
		if Day < 10 then Day="0"..Day end
		local DayEvents = self:GetDayEvent(Day, Month)
		if table.getn(DayEvents) == 1 then
			self.wndMain:FindChild("EventIcon_"..Day):SetSprite(self.IconSprite[DayEvents[1].Icon])
			self.wndMain:FindChild("EventIcon_"..Day):Show(true)
		elseif table.getn(DayEvents) > 1 then
			self.wndMain:FindChild("EventIcon_"..Day):SetSprite(self.IconSprite["Divers"])
			self.wndMain:FindChild("EventIcon_"..Day):Show(true)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Data Access Functions
-----------------------------------------------------------------------------------------------

function GuildCal:GetDayEvent(Day, Month)
	local Day = tonumber(Day)
	local Month = tonumber(Month)
	if Day < 10 then Day="0"..Day end
	if Month < 10 then Month="0"..Month end
	
	local SearchDateMin = self.YearCurrent..Month..Day.."0000"
	local SearchDateMax = self.YearCurrent..Month..Day.."2359"
	local DayEvent = {}
	for i = 1, table.getn(self.EventTab) do
		if DayEvent[1] ~= nill and self.EventTab[i].Date > SearchDateMax then
			return DayEvent
		end
		if self.EventTab[i].Date >= SearchDateMin and self.EventTab[i].Date <= SearchDateMax then
			local EMinutes = string.sub(self.EventTab[i].Date,11,12)
			local EHours = string.sub(self.EventTab[i].Date,9,10)
			
			table.insert(DayEvent,{Hours=EHours.."h"..EMinutes, Title=self.EventTab[i].Title, Description = self.EventTab[i].Description, Icon=self.EventTab[i].Icon})
		end
	end
	return DayEvent
end

function GuildCal:EventExist(Tab, Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	if tonumber(Month) <= 9 then Month="0"..Month end
	if tonumber(Day) <= 9 then Day="0"..Day end
	if tonumber(Hours) <= 9 then Hours="0"..Hours end
	if tonumber(Minutes) <= 9 then Minutes="0"..Minutes end
		
	local Date = Year..Month..Day..Hours..Minutes
	for i=1,table.getn(Tab) do
		if Tab[i].Date > Date then break end
		if Tab[i].Date == Date and Tab[i].Title == Title and Tab[i].Description == Description and Tab[i].Icon == Icon then
			return i
		end
	end
	return 0
end

function GuildCal:SaveEvent(Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	if self:EventExist(self.EventTab, Title, Description, Hours, Minutes, Icon, Day, Month, Year) == 0 then
		if tonumber(Month) <= 9 then Month="0"..Month end
		if tonumber(Day) <= 9 then Day="0"..Day end
		if tonumber(Hours) <= 9 then Hours="0"..Hours end
		if tonumber(Minutes) <= 9 then Minutes="0"..Minutes end
		
		local Date = Year..Month..Day..Hours..Minutes
		table.insert(self.EventTab, {Date=Date,Title=Title,Description=Description,Icon=Icon})
		table.sort(self.EventTab, function (a, b) return a.Date < b.Date end)
		return true
	else
		return false
	end
end

function GuildCal:DeleteEvent(Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	local EventId = self:EventExist(self.EventTab, Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	if EventId ~= 0 then
		table.remove(self.EventTab,EventId)
		table.sort(self.EventTab, function (a, b) return a.Date < b.Date end)
		if tonumber(Month) <= 9 then Month="0"..Month end
		if tonumber(Day) <= 9 then Day="0"..Day end
		if tonumber(Hours) <= 9 then Hours="0"..Hours end
		if tonumber(Minutes) <= 9 then Minutes="0"..Minutes end
		
		local Date = Year..Month..Day..Hours..Minutes
		if self:EventExist(self.EventRemoveTab, Title, Description, Hours, Minutes, Icon, Day, Month, Year) == 0 then
			table.insert(self.EventRemoveTab, {Date=Date,Title=Title,Description=Description,Icon=Icon})
			table.sort(self.EventRemoveTab, function (a, b) return a.Date < b.Date end)
		end
		
		return true
	else
		return false
	end
end

function GuildCal:GetFirstDayNum()
	local t = os.date('*t')
	t.day = 1
	t.month = self.MonthCurrent
	t.hour = 12
	t.min = 0
	t.sec = 0
	t.year = self.YearCurrent
	local FirstDayTime = os.time(t)
	local FirstDayTab = os.date('*t', FirstDayTime)
	local FirstDayNumber = FirstDayTab.wday
	
	if FirstDayNumber > 1 then
		FirstDayNumber = FirstDayNumber - 1
	else
		FirstDayNumber = 7
	end
	return FirstDayNumber 
end

function GuildCal:GetDayInMonth(Month, Year)
	Month = tonumber(Month)
	Year = tonumber(Year)
	if Month == 1 or Month == 3 or Month == 5 or Month == 7 or Month == 9 or Month == 11 then
		return 31
	elseif Month == 4 or Month == 6 or Month == 8 or Month == 10 or Month == 12 then
		return 30
	elseif Month == 2 then
		if Year%4 == 0 and Year%100 ~= 0 or Year%400 == 0 then
			return 29
		else
			return 28
		end
	end	
end

function GuildCal:CleanEvent()
	local Month = tonumber(os.date("%m"))
	
	if Month < 10 then Month="0"..Month end
	
	local SearchDate = self.YearSelect..Month.."01".."0000"
	
	local EventTitle = {}
	for i = 1, table.getn(self.EventRemoveTab) do
		if EventTitle[1] ~= nill and self.EventRemoveTab[i].Date > SearchDate then
			break
		end
		if self.EventRemoveTab[i].Date >= SearchDate then
			table.remove(self.EventRemoveTab,i)
			table.sort(self.EventRemoveTab, function (a, b) return a.Date < b.Date end)
		end
	end
	
	EventTitle = {}
	for i = 1, table.getn(self.EventTab) do
		if EventTitle[1] ~= nill and self.EventTab[i].Date > SearchDate then
			break
		end
		if self.EventTab[i].Date >= SearchDate then
			table.remove(self.EventTab,i)
			table.sort(self.EventTab, function (a, b) return a.Date < b.Date end)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Click Functions
-----------------------------------------------------------------------------------------------

function GuildCal:OnClose(wndControl)
	local Control = wndControl:GetParent():GetName()
	
	self.wndAddEvent:Close()
	self.wndAddEvent:FindChild("InputTitle"):FindChild("Value"):SetText("")
	self.wndAddEvent:FindChild("InputDescription"):FindChild("Value"):SetText("")
	self.wndAddEvent:FindChild("InputHours"):FindChild("Value"):SetText("")
	self.wndAddEvent:FindChild("InputMinutes"):FindChild("Value"):SetText("")
	self.wndAddEvent:FindChild("InputIcon"):SetRadioSelButton("IconRadio", self.wndAddEvent:FindChild("InputIcon"):FindChild("Divers"))
	
	if Control == "AddEvent" then return 1 end
	self.wndDay:Close()
	
	if Control == "ShowDay" then return 1 end
	
	self.wndMain:Close()
end

function GuildCal:OnPrevMonth()
	local date = os.date('*t')
	if not (date.month == self.MonthCurrent and date.year == self.YearCurrent) then
		if self.MonthCurrent == 1 then
			self.MonthCurrent = 12
			self.YearCurrent = self.YearCurrent - 1
		else
			self.MonthCurrent = self.MonthCurrent - 1
		end
		self:DisplayCalendar()
	self:OnClose(self.wndDay:FindChild("CloseButton"))
	end
end

function GuildCal:OnNextMonth()
	if self.MonthCurrent == 12 then
		self.MonthCurrent = 1
		self.YearCurrent = self.YearCurrent + 1
	else
		self.MonthCurrent = self.MonthCurrent + 1
	end
	self:DisplayCalendar()
	self:OnClose(self.wndDay:FindChild("CloseButton"))
end

function GuildCal:OnShowDay(wndControl)
	self.channel:SendMessage({Type="NeedUpdate"})
	local L,T,R,B = self.wndMain:GetAnchorOffsets()
	self.wndDay:SetAnchorOffsets(R-50,T,R+250,B)
    self.wndDay:Show(true)
	self.YearSelect = self.YearCurrent
	self.MonthSelect = self.MonthCurrent
	self.DaySelect = wndControl:FindChild("Text"):GetText()
	self.wndDay:FindChild("Date"):SetText(self.DaySelect.." "..self.MonthList[self.MonthCurrent].." "..self.YearSelect)
	self:PopulateEventList()
	self:OnClose(self.wndAddEvent:FindChild("CloseButton"))
end

function GuildCal:OnAddEvent()
	local L,T,R,B = self.wndDay:GetAnchorOffsets()
	self.wndAddEvent:SetAnchorOffsets(R-50,T,R+300,T+375)
    self.wndAddEvent:Show(true)
	self.wndAddEvent:FindChild("InputIcon"):SetRadioSelButton("IconRadio", self.wndAddEvent:FindChild("InputIcon"):FindChild("Divers"))
end

function GuildCal:OnSaveEvent()
	local Title = self.wndAddEvent:FindChild("InputTitle"):FindChild("Value"):GetText()
	local Description = self.wndAddEvent:FindChild("InputDescription"):FindChild("Value"):GetText()
	local Hours = self.wndAddEvent:FindChild("InputHours"):FindChild("Value"):GetText()
	local Minutes = self.wndAddEvent:FindChild("InputMinutes"):FindChild("Value"):GetText()
	local Icon = self.wndAddEvent:FindChild("InputIcon"):GetRadioSelButton("IconRadio"):GetName()
	if Description == nil then Description = ""	end
	if Title ~= "" and Hours ~= "" and Minutes ~= "" and Icon ~= "" then
		if self:SaveEvent(Title, Description, Hours, Minutes, Icon, self.DaySelect, self.MonthSelect, self.YearSelect) then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "[GuildCal] Event Save")
			self.wndAddEvent:FindChild("InputTitle"):FindChild("Value"):SetText("")
			self.wndAddEvent:FindChild("InputDescription"):FindChild("Value"):SetText("")
			self.wndAddEvent:FindChild("InputHours"):FindChild("Value"):SetText("")
			self.wndAddEvent:FindChild("InputMinutes"):FindChild("Value"):SetText("")
			self.wndAddEvent:FindChild("InputIcon"):SetRadioSelButton("IconRadio", self.wndAddEvent:FindChild("InputIcon"):FindChild("Divers"))
			self.wndAddEvent:Close()
			self:PopulateEventList()
			self:DisplayCalendar()
		else
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "[GuildCal] This event allready exist")
		end
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "[GuildCal] Title, Hours, Minutes and Icon must not be empty")
	end
end

function GuildCal:OnDeleteEvent(wndControl)
	local Title = wndControl:GetParent():FindChild("Title"):GetText()
	local Description = wndControl:GetParent():GetData()
	local Time = wndControl:GetParent():FindChild("Hours"):GetText()
	local Sprite = wndControl:GetParent():FindChild("Icon"):GetSprite()
	local Icon = "Divers"
	for k,g in pairs(self.IconSprite) do
		if g == Sprite then
			Icon = k
		end
	end
	local Hours = tonumber(string.sub(Time,1,2))
	local Minutes = tonumber(string.sub(Time,4,5))
	
	if self:DeleteEvent(Title, Description, Hours, Minutes, Icon, self.DaySelect, self.MonthSelect, self.YearSelect) then
		self:PopulateEventList()
		self:DisplayCalendar()
		self:BroacastDelEvent(Title, Description, Hours, Minutes, Icon, self.DaySelect, self.MonthSelect, self.YearSelect)
	end
end

-----------------------------------------------------------------------------------------------
-- Dialog Functions
-----------------------------------------------------------------------------------------------

function GuildCal:GetChannelName()
	local Channel = "GuildCalPublic"
	local Count = ""
	for k,g in pairs(GuildLib.GetGuilds()) do
		if g:GetType() == GuildLib.GuildType_Guild then
			Channel,Count = string.gsub(g:GetName(), "%s", "")
		end
	end
	self.Guild = Channel..Count
	return self.Guild
end

function GuildCal:BroacastNewEvent(Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	if self.Guild ~= "" then
		self.channel:SendMessage({Type="NewEvent",  Title=Title, Description=Description, Hours=Hours, Minutes=Minutes, Icon=Icon, Day=Day, Month=Month, Year=Year})
	end
end

function GuildCal:BroacastDelEvent(Title, Description, Hours, Minutes, Icon, Day, Month, Year)
	if self.Guild ~= "" then
		self.channel:SendMessage({Type="DelEvent",  Title=Title, Description=Description, Hours=Hours, Minutes=Minutes, Icon=Icon, Day=Day, Month=Month, Year=Year})
	end
end

function GuildCal:BroadcastAllEvents()
	if self.Guild ~= "" then
		local Msg = ""
		for i=1,table.getn(self.EventTab) do
			Msg = Msg..self.EventTab[i].Date..":SEP:"..self.EventTab[i].Title..":SEP:"..self.EventTab[i].Description..":SEP:"..self.EventTab[i].Icon
			if i ~= table.getn(self.EventTab) then
				Msg = Msg.."/"
			end
		end
		
		local Day = tonumber(os.date("%d"))
		local Month = tonumber(os.date("%m"))
		local Year = tonumber(os.date("%Y"))
		local Hours = tonumber(os.date("%H"))
		local Minutes = tonumber(os.date("%M"))
		
		if Day < 10 then Day="0"..Day end
		if Month < 10 then Month="0"..Month end
		if Hours < 10 then Hours="0"..Hours end
		if Minutes < 10 then Minutes="0"..Minutes end
		
		UpdateTime = Year..Month..Day..Hours..Minutes
		
		
		self.channel:SendMessage({Type="Update", Time=UpdateTime, Events=self.EventTab, EventsRemove=self.EventRemoveTab})
	end
end

function GuildCal:OnMsgReceived(channel, Msg, Sender)
	if Msg and Msg.Type == "NewEvent" then
		if self:SaveEvent(Msg.Title, Msg.Description, Msg.Hours, Msg.Minutes, Msg.Icon, Msg.Day, Msg.Month, Msg.Year) then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "[GuildCal] Event Add : "..Msg.Day.." "..Msg.Month.." "..Msg.Year..", "..Msg.Hours.."H"..Msg.Minute.." : "..Msg.Msg.Title..", by "..Sender)
		end
	elseif Msg and Msg.Type == "Update" then
		if self.LastUpdate ~= Msg.Time then
			self.LastUpdate = Msg.Time
			for i=1,table.getn(Msg.Event) do
				local Year = string.sub(Msg.Event[i].Date,1,4)
				local Month = string.sub(Msg.Event[i].Date,5,6)
				local Day = string.sub(Msg.Event[i].Date,7,8)
				local Hours = string.sub(Msg.Event[i].Date,9,10)
				local Minute = string.sub(Msg.Event[i].Date,11,12)
				self:SaveEvent(Msg.Event[i].Title, Msg.Event[i].Description, Hours, Minutes, Msg.Event[i].Icon, Day, Month, Year)
			end
			
			for i=1, table.getn(Msg.EventRemove) do
				local Year = string.sub(Msg.EventRemove[i].Date,1,4)
				local Month = string.sub(Msg.EventRemove[i].Date,5,6)
				local Day = string.sub(Msg.EventRemove[i].Date,7,8)
				local Hours = string.sub(Msg.EventRemove[i].Date,9,10)
				local Minute = string.sub(Msg.EventRemove[i].Date,11,12)
				self:DeleteEvent(Msg.EventRemove[i].Title, Msg.EventRemove[i].Description, Hours, Minutes, Msg.EventRemove[i].Icon, Day, Month, Year)
			end
		end
	elseif Msg and Msg.Type == "DelEvent" then
		if self:DeleteEvent(Msg.Title, Msg.Description, Msg.Hours, Msg.Minutes, Msg.Icon, Msg.Day, Msg.Month, Msg.Year) then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "[GuildCal] Event Delete : "..Msg.Day.." "..Msg.Month.." "..Msg.Year..", "..Msg.Hours.."H"..Msg.Minute.." : "..Msg.Msg.Title..", by "..Sender)
		end
	elseif Msg and Msg.Type == "NeedUpdate" then
		self:BroadcastAllEvents()
	end
end

function GuildCal:AskUpdate()
	self.channel:SendMessage({Type="NeedUpdate"})
end

-----------------------------------------------------------------------------------------------
-- Save and Restore Functions
-----------------------------------------------------------------------------------------------

function GuildCal:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 0
	end
	local tSave = {}
	tSave.MainOffset = {self.wndMain:GetAnchorOffsets()}
	tSave.DayOffset = {self.wndDay:GetAnchorOffsets()}
	tSave.AddEventOffset = {self.wndAddEvent:GetAnchorOffsets()}
	tSave.Guild = self.Guild
	tSave.LastUpdate = self.LastUpdate
	tSave.Events = self.EventTab
	tSave.EventsRemove = self.EventRemoveTab
	return tSave
end

function GuildCal:OnRestore(eLevel, tSavedData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 0
	end
	
	if tSavedData.MainOffset then
		self.wndMain:SetAnchorOffsets(unpack(tSavedData.MainOffset))
	end
	if tSavedData.DayOffset then
		self.wndDay:SetAnchorOffsets(unpack(tSavedData.DayOffset))
	end
	if tSavedData.AddEventOffset then
		self.wndAddEvent:SetAnchorOffsets(unpack(tSavedData.AddEventOffset))
	end
	
	if tSavedData.LastUpdate then
		self.LastUpdate = tSavedData.LastUpdate
	end
	
	local Guild = ""
	if tSavedData.Guild then
		Guild = tSavedData.Guild
	end
	if Guild == self.Guild then
		if tSavedData.Events then
			self.EventTab = tSavedData.Events
		end
		if tSavedData.EventsRemove then
			self.EventRemoveTab = tSavedData.EventsRemove
		end
	else
		self.EventTab = {}
		self.EventRemoveTab = {}
	end
end

-----------------------------------------------------------------------------------------------
-- GuildCal Instance
-----------------------------------------------------------------------------------------------

local GuildCalInst = GuildCal:new()
GuildCalInst:Init()
