
function TriggerConsoleAction(action, params)
    if action == "DustStorm" then
		CreateGameTimeThread(function()
			local data = DataInstances.MapSettings_DustStorm
			local descr = data[ActiveMapData.MapSettings_DustStorm] or data.DustStorm_VeryLow
			StartDustStorm("normal", descr)
		end)
    elseif action == "Meteor" then
		local meteors_type = "single"
		pos = GetCursorWorldPos()

		if IsValid(pos) then
			pos = pos.GetVisualPos and pos:GetVisualPos() or pos:GetPos()
		end

		local data = DataInstances.MapSettings_Meteor
		local descr =  data[ActiveMapData.MapSettings_Meteor] or data.Meteor_VeryLow

		local orig_storm_radius = descr.storm_radius
		if meteors_type == "single" then
			-- defaults to 50000 (no good for aiming).
			descr.storm_radius = 2500
		end

		CreateGameTimeThread(function()
			MeteorsDisaster(descr, meteors_type, pos)
			descr.storm_radius = orig_storm_radius
		end)
    elseif action == "GiveMoney" then
        -- UIAddFunding(100000000)
    elseif action == "SpawnColonists" then
		local GenerateColonistDataOrig = GenerateColonistData
		function GenerateColonistData(city, _, ...)
			local p = GenerateColonistDataOrig(city, "Youth", ...)
			to_add =  GetRandomTrait(p.traits, {}, {}, "Rare", "base")
			if type(to_add) == "table" then
				for trait in pairs(to_add) do
					p.traits[trait] = true
				end
			elseif to_add then
				p.traits[to_add] = true
			end
			if params then
				p.name = params
			end
			return p
		end
        CheatSpawnNColonists(1)
		GenerateColonistData = GenerateColonistDataOrig
    elseif action == "Fireworks" then
		local city = Cities[ActiveMapID]
		local domes = city.labels.Domes or ""
		if #domes < 11 then
			for i = 1, #domes do
				Dome.TriggerFireworks(domes[i], const.HourDuration, 15)
			end
		else
			local domes_copy = table.copy(domes)
			table.shuffle(domes_copy)
			for i = 1, 10 do
				Dome.TriggerFireworks(domes_copy[i], const.HourDuration, 15)
			end
		end
    elseif action == "CaveIn" then
        local TriggerCaveIn = TriggerCaveIn
		local IsValid = IsValid
		local ActiveMapID = ActiveMapID

		-- disable any struts around
		for _ = 1, 25 do
			local strut = TriggerCaveIn(ActiveMapID, GetCursorWorldPos())
			if IsValid(strut) and strut:IsKindOf("SupportStruts") then
				strut:CheatMalfunction()
			else
				break
			end
		end
    elseif action == "ColdWave" then
		CreateGameTimeThread(function()
			local data = DataInstances.MapSettings_ColdWave
			local descr = data[ActiveMapData.MapSettings_ColdWave] or data.ColdWave_VeryLow
			StartColdWave(descr)
		end)
    elseif action == "SpawnPOIs" then
        local item_list = {}
		local c = 0

		local POIPresets = POIPresets
		for id, item in pairs(POIPresets) do
			c = c + 1
			item_list[c] = {
				text = T(item.display_name),
				value = id,
				icon = item.display_icon,
				hint = T(item.description),
			}
		end

		local function CallBackFunc(choices)
			if choices.nothing_selected then
				return
			end
			for i = 1, #choices do
				local value = choices[i].value
				if POIPresets[value] then
					CheatSpawnSpecialProjects(value)
				end
			end
		end

		ChoGGi_Funcs.Common.OpenInListChoice{
			callback = CallBackFunc,
			items = item_list,
			title = "Test POI",
			multisel = true,
		}
	else
		print("Unknown action " .. action)
    end
    
    print("Console Action Executed: " .. tostring(action))
end

CreateRealTimeThread(function()
	local filename = "AppData/to_game.csv"
	local csv_load_fields = {
		[1] = "command",
		[2] = "params",
	}
	local captions = {
		"command",
		"params",
	}
    while true do
		local loaded_csv = {}
		LoadCSV(filename,loaded_csv,csv_load_fields,true)
		if next(loaded_csv) ~= nil then
			SaveCSV(filename, {}, csv_load_fields, captions)
		end
		for _, val in ipairs(loaded_csv) do
			local success, err = pcall(function()
			   TriggerConsoleAction(val.command, val.params)
			end)
			if not success then
				print("Error in TriggerConsoleAction: " .. err)
			end
		end
        Sleep(1000)
    end
end)

function CheckAccountStorage()

end

-- OnMsg.CityStart = CheckAccountStorage 