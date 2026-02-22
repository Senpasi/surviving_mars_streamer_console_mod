
local g_env = _G
function OnMsg.ChoGGi_UpdateBlacklistFuncs(env)
	g_env = env
end

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
        if UIColony then
            UIColony.funds:ChangeFunding(tonumber(params) or 100000000)
        end
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
		    p.death_age = 5000
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
    elseif action == "StoryBit" then
        ForceActivateStoryBit(params, ActiveMapID, nil, true)
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

function SaveColonyStatusToYaml()
    print("SaveColonyStatusToYaml...")
    local city = UICity
    if not city then return end

    local res_overview = GetCityResourceOverview(city)
    if not res_overview then return end
    print("SaveColonyStatusToYaml running...")

    local data = {
        timestamp = RealTime(), -- Используем RealTime() вместо OsTime()
        sol = city.day or 0,
        population = table.count(city.labels.Colonist or ""),
        unemployed = table.count(city.labels.Unemployed or ""),
        homeless = table.count(city.labels.Homeless or ""),
        resources = {},
        buildings = {
            count = city:CountBuildings(),
            constructions_today = city.constructions_completed_today or 0
        },
        transportation = {
            drones = table.count(city.labels.Drone or ""),
            shuttles = city:CountShuttles() or 0
        },
        domes = table.count(GetCommandCenterDomesList()),
        funds = tostring(UIColony.funds:GetFunding()),
        temperature = string.format("%.1f", UICity.ambient_temp or 0),
        weather = ActiveMapData and ActiveMapData.MapSettings_DustStorm or "Unknown"
    }

    -- Вспомогательная функция для добавления ресурсов
    local function add_resource(name, stored, produced, consumed, capacity)
        data.resources[name] = {
            stored = string.format("%.1f", stored / const.ResourceScale),
            produced_per_hour = string.format("%.1f", produced / const.ResourceScale),
            consumed_per_hour = string.format("%.1f", consumed / const.ResourceScale),
            capacity = string.format("%.1f", capacity / const.ResourceScale)
        }
    end

    -- Электричество
    add_resource("electricity",
        res_overview:GetTotalStoredPower(),
        res_overview:GetTotalProducedPower(),
        res_overview:GetTotalRequiredPower(),
        res_overview:GetElectricityStorageCapacity()
    )

    -- Вода
    add_resource("water",
        res_overview:GetTotalStoredWater(),
        res_overview:GetTotalProducedWater(),
        res_overview:GetTotalRequiredWater(),
        res_overview:GetWaterStorageCapacity()
    )

    -- Кислород
    add_resource("oxygen",
        res_overview:GetTotalStoredAir(),
        res_overview:GetTotalProducedAir(),
        res_overview:GetTotalRequiredAir(),
        res_overview:GetAirStorageCapacity()
    )

    -- Собираем другие ресурсы: металлы, полимеры, бетон, машины и т.д.
    local stockpile_resources = GetStockpileResourceList() -- {"Concrete", "Metals", "Polymers", "Electronics", "Machinery", "PreciousMetals"}
    for _, res_name in ipairs(stockpile_resources) do
        local stored = res_overview["GetAvailable" .. res_name](res_overview)
        local produced = res_overview["Get" .. res_name .. "ProducedYesterday"](res_overview)
        local consumed = res_overview["Get" .. res_name .. "ConsumedByConsumptionYesterday"](res_overview)
        --local capacity = res_overview["GetMaxStored" .. res_name](res_overview)

        add_resource(res_name:lower(),
            stored, produced, consumed, 0
        )
    end

    -- Преобразование таблицы в YAML строку
    local yaml = ""

    local function serialize(value, indent)
        local indent = indent or ""
        if type(value) == "table" then
            for k, v in sorted_pairs(value) do
                if type(k) == "number" then
                    yaml = yaml .. indent .. "- "
                    if type(v) == "table" then
                        yaml = yaml .. "\n"
                        serialize(v, indent .. "  ")
                    else
                        yaml = yaml .. tostring(v) .. "\n"
                    end
                else
                    yaml = yaml .. indent .. tostring(k) .. ": "
                    if type(v) == "table" then
                        yaml = yaml .. "\n"
                        serialize(v, indent .. "  ")
                    else
                        yaml = yaml .. tostring(v) .. "\n"
                    end
                end
            end
        else
            yaml = yaml .. tostring(value) .. "\n"
        end
    end

    serialize(data)

    -- Сохранение
    g_env.AsyncStringToFile("AppData/from_game.yaml", yaml)
    print("SaveColonyStatusToYaml saved!")
end

-- Запуск раз в 30 секунд
CreateRealTimeThread(function()
    while true do
        Sleep(30 * 1000) -- 30 секунд
        SaveColonyStatusToYaml()
    end
end)

function CheckAccountStorage()

end

-- OnMsg.CityStart = CheckAccountStorage 