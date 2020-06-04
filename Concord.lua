-- Concord external scripts

if not concord then concord = {} end

function concord.onlogin()
	concord.paused = false
	sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
	if concord.defs then
		concord.defs.current = {}
	end
end
registerAnonymousEventHandler("concord logged in", "concord.onlogin")

function concord.pause(bool)
  if bool == true then concord.paused = true 
  elseif bool == false then concord.paused = false
  else concord.paused = (not concord.paused)
  end
  if concord.paused then send("autocuring off",false) else send("autocuring on",false) end
  concord.echo("Concord paused: "..tostring(concord.paused))
end


---------------------------------------
--	Concord track skills
---------------------------------------

concord.skills = concord.skills or {}

function concord.getSkills()
	concord.skills = {}
	local skills = gmcp.Char.Skills.Groups
	for i,v in ipairs(skills) do
		sendGMCP("Char.Skills.Get {\"group\":\"" .. v.name .. "\"}")
		send(" ",false)
	end
end
registerAnonymousEventHandler("concord logged in", "concord.getSkills")

function concord.processSkill()
	local skillname = string.lower(gmcp.Char.Skills.List.group)
	if #gmcp.Char.Skills.List.list > 3 then
		concord.skills[skillname] = {}
		  for i,v in ipairs(gmcp.Char.Skills.List.list) do
  		concord.skills[skillname][string.lower(v)] = true
  	end
  	raiseEvent("concord processed skill",skillname)
	end
end
registerAnonymousEventHandler("gmcp.Char.Skills.List", "concord.processSkill")

function concord.hasSkill(skillset,skill)
	skillset = string.lower(skillset)
	local value = false

	if skill then
		skill = string.lower(skill)
		if concord.skills[skillset] and concord.skills[skillset][skill] then
			value = true
		end
	else
		if concord.skills[skillset] then
			value = true
		end
	end
	
	if skillset == "powers" and concord.config.powers[skill] then
		value = true
	end
	
	if skillset == "artifacts" and concord.config.powers[skill] then
		value = true
	end
	
	if skillset == "any" then
		value = true
	end
	
	return value	
end

function concord.setCommands()
	concord.commands = {}
	for action,list in pairs(concord.skillprios) do
		for i,entry in ipairs(list) do
  		local skillset = string.lower(entry[1])
  		local skill = string.lower(entry[2])
  		local cmd = entry[3]
			if concord.hasSkill(skillset, skill) then
				concord.commands[action] = cmd
				break
			end
		end
	end
end

registerAnonymousEventHandler("concord processed skill", "concord.setCommands")

if not concord.enemies then concord.enemies = {} end
if not concord.allies then concord.allies = {} end

function concord.getFullName(t)
	if not t then return end
  local ignore_players = concord.ignoretargets or {}
  local t_table = {}
  local in_room = false
  local possible_match = nil
	local value = ""

	for i,v in ipairs(concord.enemies) do
		t_table[#t_table+1] = v
	end
	
	for i,v in pairs(concord.areaPlayers) do
		t_table[#t_table+1] = i
	end
  
	for i,v in pairs(concord.allies) do
		t_table[#t_table+1] = v
	end

   
  for k,v in pairs(concord.roomPlayers) do
      if k == string.title(t) and not table.contains(ignore_players, k) then
          in_room = true
          break
      elseif string.starts(k, string.title(t)) and not table.contains(ignore_players, k) then
          possible_match = k
      end
  end
   
  if in_room then
      -- Input matches player in room
      value = string.title(t)
  elseif table.contains(t_table, string.title(t)) then
      -- Input matches concord.target table
      value = string.title(t)
  elseif possible_match then
      -- Input matches start of player in room
      value = possible_match
  else
      local in_targets = false
      for k,v in pairs(t_table) do
          if string.starts(v, string.title(t)) then
              -- Input matches start of player in concord.target table
             	value = v
              in_targets = true
              break
          end
      end
      if not in_targets then
          -- Can't match anything else so just set concord.target as inputted
          value = string.title(t)
      end
  end
	return value
end



---------------------------------------
--	Concord ally/enemies
---------------------------------------
function concord.setTarget(t)
	if not t then return end
	local old_target = concord.target or ""
	concord.target = concord.getFullName(t)
  raiseEvent("concord set target",concord.target)
	if concord.target == old_target then return end
  
  if concord.targetTriggerID then killTrigger(concord.targetTriggerID) end
  concord.targetTriggerID = tempTrigger(concord.target, [[selectString("]] .. concord.target .. [[ ", 1) fg("gold") resetFormat()]])
  concord.echo("Target Set: <gold>" .. string.upper(concord.target).."\n") 
	local str = "Target: " .. concord.target
	if concord.roomPlayers[concord.target] then str = str.." at v"..gmcp.Room.Info.num end
	concord.call(str,3)
	concord.call(str,3)
  raiseEvent("concord changed target",concord.target)
end

-- load enemy table from file
function concord.loadEnemies()
  local path = getMudletHomeDir() .. "\\Concord\\enemies"
	concord.enemies = concord.enemies or {}
	table.load(path, concord.enemies)
end
registerAnonymousEventHandler("sysLoadEvent", "concord.loadEnemies")

-- save enemy table to file
function concord.saveEnemies()
  -- Create Concord folder if it doesn't exist yet
  local path = getMudletHomeDir() .. "\\Concord"
  if not lfs.attributes(path) then
    lfs.mkdir(path)
	end
  path = path .. "\\enemies"
	table.save(path, concord.enemies)
end

-- show enemy table
function concord.showEnemies()
  concord.echo("Enemies in your table:")
	for k,v in ipairs(concord.enemies) do
	  local remove = " - "
		cecho("\n<dark_slate_gray>  [")
		echoLink(remove, [[concord.removeEnemy("]] .. v .. [[")			]], "Click to remove " .. v .. " from the enemy table.", true)
		cecho("<dark_slate_gray>] " .. ndb.getcolor(v) .. v)
	end
	send(" ")
end

-- add to enemy table
function concord.addEnemy(name, showTable)
  name = string.title(name)
		concord.removeAlly(name)
	  if not table.contains(concord.enemies, name) then
		  table.insert(concord.enemies, name)
			concord.echo(ndb.getcolor(name) .. name .. " <green>has been added to the enemy table.")
			if showTable then concord.showEnemies() end
		else
		  concord.echo(ndb.getcolor(name) .. name .. " <red>is already in the enemy table.")
		end
end

-- remove from enemy table
function concord.removeEnemy(name, showTable)
  name = string.title(name)
	if table.contains(concord.enemies, name) then
	  local index = table.index_of(concord.enemies, name)
		table.remove(concord.enemies, index)
		concord.echo(ndb.getcolor(name) .. name .. " <green>has been removed from the enemy table.")
	  if showTable then concord.showEnemies() end
	else
	  concord.echo(ndb.getcolor(name) .. name .. " <red>not found in enemy table.")
	end
end

-- enemy all people in list
function concord.enemyAll()
  local cmd = "enemy"
  for k, v in ipairs(concord.enemies) do
	  cmd = cmd .. " " .. v
	end
	send(cmd)
end

-- see if person is in enemy table
-- maybe link in ndb.isenemy()?
function concord.isEnemy(name)
  name = string.title(name)
	if table.contains(concord.enemies, name) then
	  return true
	else
	  return false
	end
end

-- load ally table from file
function concord.loadAllies()
  local path = getMudletHomeDir() .. "\\Concord\\allies"
	concord.allies = concord.allies or {}
	table.load(path, concord.allies)
end
registerAnonymousEventHandler("sysLoadEvent", "concord.loadAllies")

-- save ally table to file
function concord.saveAllies()
  -- Create Concord folder if it doesn't exist yet
  local path = getMudletHomeDir() .. "\\Concord"
  if not lfs.attributes(path) then
    lfs.mkdir(path)
	end
  path = path .. "\\allies"
	table.save(path, concord.allies)
end

-- show ally table
function concord.showAllies()
  concord.echo("Allies in your table:")
	for k,v in ipairs(concord.allies) do
	  local remove = " - "
		cecho("\n<dark_slate_gray>  [")
		echoLink(remove, [[concord.removeAlly("]] .. v .. [[")			]], "Click to remove " .. v .. " from the ally table.", true)
		cecho("<dark_slate_gray>] " .. ndb.getcolor(v) .. v)
	end
	send(" ")
end

-- add to ally table
function concord.addAlly(name, showTable)
  name = string.title(name)
		concord.removeEnemy(name)
	  if not table.contains(concord.allies, name) then
			table.insert(concord.allies, name)
			concord.echo(ndb.getcolor(name) .. name .. " <green>has been added to the ally table.")
			if showTable then concord.showAllies() end
		else
		  concord.echo(ndb.getcolor(name) .. name .. " <red>is already in the ally table.")
		end
end

-- remove from ally table
function concord.removeAlly(name, showTable)
  name = string.title(name)
	if table.contains(concord.allies, name) then
	  local index = table.index_of(concord.allies, name)
		table.remove(concord.allies, index)
		concord.echo(ndb.getcolor(name) .. name .. " <green>has been removed from the ally table.")
	  if showTable then concord.showAllies() end
	else
	  concord.echo(ndb.getcolor(name) .. name .. " <red>not found in ally table.")
	end
end

-- enemy all people in list
function concord.allyAll()
  local cmd = "ally"
  for k, v in ipairs(concord.allies) do
	  cmd = cmd .. " " .. v
	end
	send(cmd)
end

-- see if person is in ally table
-- maybe link in ndb.isally()?
function concord.isAlly(name)
  name = string.title(name)
	if table.contains(concord.allies, name) then
	  return true
	else
	  return false
	end
end

--processes entire area of players
function concord.enemyArea()
	if concord.enemyallarea == true then
	local list = ""
	for i,v in pairs(concord.areaPlayers) do
		if ndb.isenemy(i) then
			list = list.." "..i
		end
	end
	send("enemy "..list)
	concord.enemyallarea = false
	end
end
registerAnonymousEventHandler("concord scented", "concord.enemyArea")


---------------------------------------
--	Concord track players
---------------------------------------

if not concord.roomPlayers then concord.roomPlayers = {} end
if not concord.areaPlayers then concord.areaPlayers = {} end

function concord.roomUpdate()
	for m,n in pairs(gmcp.Room.Players) do 		-- if in gmcp but not in players, add
		if not table.contains(concord.roomPlayers, n["name"]) then
			concord.playerInit(n["name"])
		end
	end
	for k,v in pairs(concord.roomPlayers) do 	-- if in players list but not in gmcp, delete
		if not table.contains(gmcp.Room.Players, k) then
			concord.roomPlayers[k] = nil
		end
	end
	raiseEvent("Concord room players updated")
end 
-- this function is so we can store stuff about each player in concord.roomPlayers without losing it every time we look
registerAnonymousEventHandler("gmcp.Room.Players", "concord.roomUpdate")

function concord.roomRemove(person)
	local person = person or gmcp.Room.RemovePlayer
	concord.roomPlayers[person] = nil
	raiseEvent("Concord room players updated", person)
end
registerAnonymousEventHandler("gmcp.Room.RemovePlayer", "concord.roomRemove")

function concord.roomAddGmcp()
  concord.roomAdd(gmcp.Room.AddPlayer.name)
end
registerAnonymousEventHandler("gmcp.Room.AddPlayer", "concord.roomAddGmcp")

function concord.roomAdd(person)
	if person == "gmcp.Room.AddPlayer" then person = nil end
	person = person or gmcp.Room.AddPlayer.name
	concord.playerInit(person)
	concord.areaAdd(person)
	raiseEvent("Concord room players updated", person)
end

concord.areaPlayers = concord.areaPlayers or {}

function concord.areaList(table)
	concord.areaPlayers = {}
	for i,v in ipairs(table) do
		v = string.title(string.lower(v))
		concord.areaPlayers[v] = true
	end
end

function concord.areaAdd(person)
	concord.areaPlayers[person] = true
end

function concord.areaRemove(person)
	concord.areaPlayers[person] = nil
end

---------------------------------------
--	Concord track player affs
---------------------------------------
 
function concord.playerAff(player,aff,bool)
	if bool == nil then bool = true end
	if bool == false then bool = nil end
	if not concord.roomPlayers[player] then concord.playerInit(player) end
	if not concord.roomPlayers[player]["afflictions"] then concord.roomPlayers[player]["afflictions"] = {} end
	concord.roomPlayers[player]["afflictions"][aff] = bool
end

function concord.playerInit(player)
	concord.roomPlayers[player]={
		vitals = {};
		afflictions = {
		};
	}
end

function concord.playerHasAff(player,aff)
	if concord.roomPlayers[player] 
	and concord.roomPlayers[player]["afflictions"]
	and concord.roomPlayers[player]["afflictions"][aff] then 
		return true 
	end
	return false
end

function concord.playerVitals(player,vital,value)
	if not concord.roomPlayers[player] then concord.playerInit(player) end
	concord.roomPlayers[player]["vitals"] = concord.roomPlayers[player]["vitals"] or {}
	concord.roomPlayers[player]["vitals"][vital] = tonumber(value)
end

function concord.onDiscern(player,instanow)
	local vitals = concord.roomPlayers[player]["vitals"]
	for i,v in ipairs({"health","mana","ego"}) do
		if vitals[v] then
			vitals[v.."percent"] = math.floor(vitals[v]*100/vitals["max"..v])
		end
	end
	local instakill = false
	for i,method in pairs(concord.instakills) do
		for stat,num in pairs(method.conditions) do
			if vitals[stat] and ((type(vitals[stat]) == "number" and vitals[stat] < num)  or (type(vitals[stat]) == "string" and vitals[stat] == num)) then			
				if concord.hasSkill(method["skillset"]) and concord.vitals.pow >= method.power then
					instakill = method.command
				end
				concord.call(player.."'s "..stat.." at "..vitals[stat],1)
			end
		end
	end
	if instakill then
		concord.box("INSTAKILLING - HANDS OFF", "medium_turquoise", "^*")
		if instanow then
			concord.instanow = false
			concord.doClear(true)
			concord.doAdd(instakill,player,false,false)
		else
			concord.instanow = true
			concord.doClear(true)
			concord.doAdd("discern @target health mana ego hemorrhaging wounding timewarp cloudcoils",player,true,false)
		end
	end
end

function concord.onDiagnose(player,todo)
	if todo == "discordantchord" then
 		concord.symph.discordantChord(player)
	end
	concord.diagnosedo = nil
end


---------------------------------------
--	Concord track affs
---------------------------------------
concord.affl = {}

function concord.remAff()
  for k,v in pairs(gmcp.Char.Afflictions.Remove) do
    concord.affl[v] = nil
  end
	raiseEvent("concord updated affs")
end
registerAnonymousEventHandler("gmcp.Char.Afflictions.Remove", "concord.remAff")

function concord.listAff()
	concord.affl = {}
	for i,v in ipairs(gmcp.Char.Afflictions.List) do
		concord.affl[v["name"]]=true
	end
	raiseEvent("concord updated affs")
end
registerAnonymousEventHandler("gmcp.Char.Afflictions.List", "concord.listAff")

function concord.gotAff()
  concord.affl[gmcp.Char.Afflictions.Add.name] = true
	raiseEvent("concord updated affs")
end
registerAnonymousEventHandler("gmcp.Char.Afflictions.Add", "concord.gotAff")

-- gets aff info from prompt

function concord.vitalsAff()
	local vitalaffs = {"blind", "deaf"}
	for j,k in ipairs(vitalaffs) do
  	if gmcp.Char.Vitals[k] == "1" then
  		concord.affl[k]=true
  	else
  		concord.affl[k]=nil
  	end
	end
	if (gmcp.Char.Vitals.hp == "0" and gmcp.Char.Vitals.mp == "0" and gmcp.Char.Vitals.ego == "0" and gmcp.Char.Vitals.pow == "0") then
		concord.affl["blackout"] = true
	else
		concord.affl["blackout"] = nil
	end
	raiseEvent("concord updated affs")
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.vitalsAff")


---------------------------------------
--	Concord track vitals/bals
---------------------------------------

function concord.getVitals()
	concord.vitals = {}
	for k,v in pairs(gmcp.Char.Vitals) do
		concord.vitals[k] = tonumber(v)
		if gmcp.Char.Vitals["max"..k] then
			concord.vitals[k.."percent"] = math.floor(tonumber(v)*100/tonumber(gmcp.Char.Vitals["max"..k]))
		end
	end
	concord.balChanges()
	concord.vitalChanges()
	concord.oldVitals = gmcp.Char.Vitals
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.getVitals")

function concord.balChanges()
	if concord.oldVitals then
		for k,v in pairs(gmcp.Char.Vitals) do
			if v == "1" and concord.oldVitals[k] == "0" then raiseEvent("concord got "..k) raiseEvent("concord got bal",k)  end
			if v == "0" and concord.oldVitals[k] == "1" then raiseEvent("concord lost "..k) raiseEvent("concord lost bal",k) end
		end
		if tonumber(gmcp.Char.Vitals.pow) ~= tonumber(concord.oldVitals.pow) then
			raiseEvent("concord got power", tonumber(gmcp.Char.Vitals.pow))
		end
	end

end

function concord.vitalChanges()
	concord.deltaVitals = {};
	if concord.oldVitals then
		for i,v in ipairs({"hp","mp","ego"}) do
			concord.deltaVitals[v] = tonumber(gmcp.Char.Vitals[v]) - tonumber(concord.oldVitals[v])
			concord.deltaVitals[v.."percent"] = math.floor(concord.deltaVitals[v]*100/tonumber(gmcp.Char.Vitals["max"..v]))
		end
	end
end

---------------------------------------
--	Concord display
---------------------------------------
function concord.box(text, color, border, person)
  local width = 50
  local textstr = text
  text = string.gsub(text,"<%w.->","")
  if #text + 4 > width then
    width = #text + 4
  end
	
	if not border then border = "-" end
	color = color or "red"
	
  local lindent = math.floor(((width - #text) / 2) - 1)
  local rindent = math.ceil(((width - #text) / 2) - 1)

  local colors = {
    red     = "<red>",
    blue    = "<royal_blue>",
    green   = "<green>",
    yellow  = "<yellow>",
    purple  = "<medium_orchid>",
    orange  = "<dark_orange>",
  }

  local selection = colors[color] or "<"..color..">"

	if person then textstr = string.gsub(textstr, person, ndb.getcolor(string.title(string.lower(person)))..person..selection) end

  cecho("\n" .. selection .. "+" .. string.rep(border, (width - 2)/#border) .. "+")
  cecho("\n" .. selection .. "|" .. string.rep(" ", lindent) .. textstr .. string.rep(" ", rindent) .. "|")
  cecho("\n" .. selection .. "+" .. string.rep(border, (width - 2)/#border) .. "+")
end

function concord.echo(text, color, rep)
  if not color then color = "cornflower_blue" end
  if not rep then rep = 1 end
	
	for i=1,rep,1 do
	  cecho("\n<white>[<cornflower_blue>Concord<white>]: <" .. color .. ">" .. text)
	end
end

function concord.format(str, person, fgc, bgc, bold)
	local tbl = string.split(str,person)
	for i,str in ipairs(tbl) do
		selectString(str,1)
		if fgc then fg(fgc) end
		if bgc then bg(bgc) end
		if bold then setBold(true) end
		resetFormat()
	end
end

function concord.instaPrompt(insta, instatime)
	if not concord.customPrompt then concord.box(insta) return end
	if not instatime then instatime = 9 end
	concord.preprompt = "<DarkGoldenrod>("..insta..")" 
	if concord.instatimer then killTimer(concord.instatimer) end
	concord.instatimer = tempTimer(instatime, function()
		concord.preprompt = false
		end)
end

---------------------------------------
--	Concord geography
---------------------------------------

function concord.isNeutralArea(room)
	if room.details[1] == "the Prime Material Plane" then
		if string.find(room.area, "the City of ") or string.find(room.area, "the Village of ") then 
			return false
		else 
			return true 
		end
	end
	if room.details[1] == "the Aetherways" then
		return true
	end
	return false
end

function concord.randomDir(dir)
	local exits = {}
	local	i = 1
  local roomexits = getRoomExits(gmcp.Room.Info.num) or gmcp.Room.Info.exits
	for k,v in pairs(roomexits) do
    	if k ~= "x" then
     	   exits[i] = k
				 i = i + 1
			end
	end
	local thisnum = math.random(1, #exits)
	return dir or exits[thisnum]
end

function concord.gotoRoom(vnum,immediately)
	if not vnum then vnum = concord.pathto end
	if immediately then concord.going = true end
	local from, to = tonumber(gmcp.Room.Info.num), tonumber(vnum)

  if concord.going == true then
  	for room in pairs(mmp.getpathhighlights) do
   	 unHighlightRoom(room)
  	end
	if concord.config.pathtrack then
		send("path track "..to)
	else
	  	mmp.gotoRoom(to)
	end
  else
  	mmp.echoPath(from, to)
  	concord.going = true
		mmp = mmp or {}
  
    mmp.getPathPerf = mmp.getPathPerf or createStopWatch()
    startStopWatch(mmp.getPathPerf)
    
    getPath(from, to)
    
    mmp.getpathhighlights = mmp.getpathhighlights or {}
    
    for room in pairs(mmp.getpathhighlights) do
      unHighlightRoom(room)
    end
    
    mmp.getpathhighlights = {}
    
    local r,g,b = unpack(color_table.yellow)
    local br,bg,bb = unpack(color_table.yellow)
    -- add the first room to the speedWalkPath, as we'd like it highlighted as well
    table.insert(speedWalkPath, 1, from)
    for i = 1, #speedWalkPath do
      local room = speedWalkPath[i]
      highlightRoom(room, r,g,b,br,bg,bb, 0.7, 255, 255)
      mmp.getpathhighlights[room] = true
    end
	end
end

function concord.gotoMoved()
	concord.going = false
	if not mmp.getpathhighlights then return end
	for room in pairs(mmp.getpathhighlights) do
		unHighlightRoom(room)
	end
end
registerAnonymousEventHandler("gmcp.Room.Info", "concord.gotoMoved")

function concord.gotoPerson(whom)
  local p = concord.getFullName(whom)
  if not mmp.pdb[p] then mmp.echo("Sorry - don't know where "..p.." is.") return end

  local nums = mmp.getnums(mmp.pdb[p], true)
	local area = getRoomArea(mmp.currentroom)
	for i,v in ipairs(nums) do
		if getRoomArea(v) ~= area then table.remove(nums, i) end 
	end
 -- mmp.gotoRoom(nums[1])
  send("path shortest "..nums[1].." go")
  mmp.echo(string.format("Going to %s in %s%s.", p, mmp.cleanAreaName(mmp.areatabler[getRoomArea(nums[1])]) or "", (#nums ~= 1 and " (non-unique location though)" or "")))
end

---------------------------------------
--	Concord calling
---------------------------------------

concord.calling = concord.calling or {}
concord.calling.call_mode = concord.calling.call_mode or 1
concord.calling.leaders = concord.calling.leaders or {}
--[[
  Calling modes:
	0: No calling
	1: Calling my own actions
	2: General calling
	3: Target calling
]]--
function concord.toggleCallMode(mode)
  local mode_orig = concord.calling.call_mode
	if not mode then
	  if concord.calling.call_mode < 3 then
		  concord.calling.call_mode = concord.calling.call_mode + 1
		else
		  concord.calling.call_mode = 0
		end
	else
		concord.calling.call_mode = mode
	end

  if concord.calling.call_mode == 0 then
	  concord.echo("No longer calling anything.")
	elseif concord.calling.call_mode == 1 then
	  concord.echo("Calling my own actions.")
	elseif concord.calling.call_mode == 2 then
	  concord.echo("Calling general observations.")
	elseif concord.calling.call_mode == 3 then
	  concord.echo("Calling targets.")
  end
end

function concord.call(str, mode)
  if not mode then mode = 1 end -- defaults to 1, own stuff
  if concord.calling.call_mode >= mode then
    if concord.paused then return 
		else
      concord.doCall(str)
    end
  end
end

function concord.doCall(str)	
	local prefix = ""
	if concord.calling.channel == "team" then
	  prefix = "team"
	elseif concord.calling.channel == "sqt" then
	  prefix = "sqt"
	else
	  prefix = "clan " .. concord.calling.channel .. " tell"
	end
	
	send(prefix .. " " .. str,false)
end

---------------------------------------
--	Concord stratagems
---------------------------------------

concord.stratagem = 0
concord.numberdictionary = {
	one = 1;
	two = 2;
	three = 3;
	four = 4;
	five = 5;
	six = 6;
	seven = 7;
	eight = 8;
	nine = 9;
	ten = 10;
};

function concord.canAuto(thing)
	if concord.paused == true then return false end
	local afflictions = {"aeon", "sap"}
	for i,v in ipairs(afflictions) do
		if table.contains(concord.affl, v) then return false end
	end
	if concord.config.auto.enabled and concord.escape == false and not concord.affl.aeon then
		if not thing or concord.config.auto[thing] then 
			return true 
		end
	end
	return false
end

function concord.doAdd(action, tar, free, prepend)
	if not prepend and not string.find(action,"@target") then prepend = false end
	if prepend == nil then prepend = true end
	if action == "" then return false end -- don't send anything if we're not doing any commands
	tar = tar or concord.target
	if free then 
		action = "free "..action
	elseif prepend == true then
		action = concord.config.prepend.."|"..action
	end
	action = string.gsub(action, "@target", tar)
	send("sm add "..action,false)
end

function concord.doRemove(action, tar, free, prepend)
	if not prepend and not string.find(action,"@target") then prepend = false end
	if prepend == nil then prepend = true end
	if action == "" then return false end -- don't send anything if we're not doing any commands
	tar = tar or concord.target
	if free then 
		action = "free "..action
	elseif prepend == true then
		action = concord.config.prepend.."|"..action
	end
	action = string.gsub(action, "@target", tar)
	send("sm remove "..action,false)
end

function concord.doAddFree(action, tar, prepend)
	concord.doAdd(action, tar, true, prepend)
end

function concord.doInsert(action, tar, free)
if action == "" then return false end -- don't send anything if we're not doing any commands
	if tar then else tar = concord.target end
	if free then 
		action = "free "..action
	end
	action = string.gsub(action, "@target", tar)
	concord.echo("<green>INSERTED ACTION: <magenta>"..string.upper(action))
	send("sm insert "..action)
	concord.inserting = true
end

function concord.doInsertFree(action, tar)
	concord.doInsert(action, tar, true)
end

function concord.doClear(override)
	if override or (not concord.inserting) then
		send("sm clear",false)
	end
end

function concord.send(string)
	if concord.canAuto() then
		send(string)
	end
end


---------------------------------------
--	Concord basic actions
---------------------------------------

-- Don't call this function directly - instead, call it through setting values for concord.escape
-- if you want to escape in a given direction, set concord.escape = "n" etc
-- if you don't care, set concord.escape = nil
-- function will not trigger if concord.escape = false

function concord.gtfo()
	if concord.escape ~= false and not (concord.affl.attraction and concord.affl.earache) and gmcp.Char.Vitals.balance == "1" and gmcp.Char.Vitals.equilibrium == "1" then
  	local dir = concord.escape
  	local action = ""
  	local count = 1
  	if concord.affl.attraction and not concord.affl.deaf then
      enableTrigger("gtfo of p5")
      send("ac mod steamqueue insert 1 truehearing")
			action = "truehearing|"
      concord.tempescape = concord.escape
      concord.escape = false
  	end
		
		if not concord.commands.leap then concord.commands.leap = "@direction" end
		send("dismount")
		send("dismount")
		send("dismount")
		local leap = string.gsub(concord.commands.leap, "@direction", concord.randomDir(dir))
		local tumble = string.gsub(concord.commands.tumble, "@direction", concord.randomDir(dir))
		
		action = "stand|"..action
		
  	for i = count,2,1 do
  		action = action .. leap .. "|"
  	end
  	action = action .. tumble
  	if not concord.affl.aeon then
  		send("sm insert "..action)
  		for i = count,5,1 do
  			send(tumble)
  		end
  	else -- even if we're in slowcuring or otherwise can't do anything, gtfo is serious and we should try
      send("ac off")
      if concord.actimer then killTimer(concord.actimer); concord.actimer = nil end
      concord.actimer = tempTimer("1.7", [[send("ac on")]])
			send(tumble)
  	end
		enableTrigger("Leap success")
		concord.escape = false
	end
end

registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.gtfo")

function concord.gust(person, dir)
	concord.doInsert("beast order gust @target "..concord.randomDir(dir).."|"..concord.commands.gust.." "..concord.randomDir(dir),person,false)
end

-- basically we need a damage function (instead of just calling the command) because of bards and blanknote.
function concord.damage(person)
	person = person or concord.target
	if concord.canAuto() then
  	if string.match(concord.commands.damage, 'play (%w+) @target') then
  		concord.symph.play(person,string.match(concord.commands.damage, 'play (%w+) @target'))
  	else
  		concord.doAdd(concord.commands.damage, person)
		end
	end
end

function concord.snipe(tar,direction)
  if concord.commands.snipe then
		if direction then
			local str = string.gsub(concord.commands.snipe, "@direction", direction)
			concord.doAdd(str,tar,false,false)
		elseif string.find(concord.commands.snipe, "@direction") then
    	if table.size(gmcp.Room.Info.exits) <=5 then
    		local str = ""
        for k,v in pairs(gmcp.Room.Info.exits) do
        	str = str.."|"..string.gsub(concord.commands.snipe, "@direction", k)
      	end
    		str = string.sub(str, 2,-1)
      	concord.doAdd(str,tar,true,false)
    	else
    		for k,v in pairs(gmcp.Room.Info.exits) do
        	local str = string.gsub(concord.commands.snipe, "@direction", k)
    			concord.doAdd(str,tar,true,false)
      	end
    	end
  	else
			concord.doAdd(concord.commands.snipe,tar,false,false)
		end
	end
end

function concord.geyser(tar)
	concord.doInsert(concord.commands.geyser, tar,false)
end

function concord.moved()
	if not concord.roomnum then concord.roomnum = 1 return end
	if concord.roomnum ~= gmcp.Room.Info.num then
		concord.lastroom = concord.roomnum
		concord.roomnum = gmcp.Room.Info.num
	  concord.justmoved = true
	  tempPromptTrigger([[concord.justmoved = false]],1)
	end
end
registerAnonymousEventHandler("gmcp.Room.Info","concord.moved")

function concord.gotMovedDir(last,now)
  getPath(last,now)
  local dir = speedWalkDir[1] or "x"
  dir = mmp.anytolong(dir)
  local back = mmp.ranytolong(dir)
  return dir, back
end

--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
--	Aeromancy scripts
--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
if not concord.aero then concord.aero = {} end

function concord.aero.focus(event,target)
	if not target then target = concord.target end
	if concord.hasSkill("Aerochemantics") then
		send("aerowork focus "..target,false)
	end
end
registerAnonymousEventHandler("concord changed target", "concord.aero.focus")

function concord.aero.bomb(type)
	if not type then type = "cloudkill" end
  if not concord.affl.powerspikes then
    concord.doClear()
    concord.doAdd("aerowork catalyst "..type,nil,false,false)
  else
  	concord.box("GOT POWERSPIKES", "red", "^")
  end
end

concord.aero.demesne = {
	nodes = {};
	links = {};
}

function concord.aero.demesne.clearEnvironment()
	concord.aero.demesne.envtype = nil
end
registerAnonymousEventHandler("gmcp.Room.Info", "concord.aero.demesne.clearEnvironment")

function concord.aero.demesne.addRoom(vnum,name,node)
	if not vnum then 
		local tbl = mmp.searchRoomExact(name)
		local tbl2 = {}
		for i,v in pairs(tbl) do
			tbl2[#tbl2+1] = i
		end
		if #tbl2 == 1 then
			vnum = next(tbl)
		else
			return
		end
	end

	if node then
  	concord.aero.demesne.nodes[vnum] = name or true
  else
	concord.aero.demesne.links[vnum] = name or true
  end
	concord.aero.demesne.highlight()
end

function concord.aero.demesne.clear()
  local roomlist, endresult = getAreaRooms(getRoomArea(mmp.currentroom)) or {}, {}
  for i = 0,#roomlist,1 do
  	unHighlightRoom(roomlist[i])
  end
  concord.aero.demesne.nodes = {}
  concord.aero.demesne.links = {}
end

function concord.aero.demesne.highlight()
	for i,v in pairs(concord.aero.demesne.nodes) do
		concord.aero.demesne.maxLink(i)
	end
	for i,v in pairs(concord.aero.demesne.links) do
		highlightRoom(i, 0,0,200,0,0,0,0.7,255,0)
	end
	for i,v in pairs(concord.aero.demesne.nodes) do
		highlightRoom(i, 0,200,200,0,0,0,0.7,255,0)
	end
end

function concord.aero.demesne.maxLink(room)
	room = tonumber(room)
  local rooms = {}
	local temp = {}
  rooms[0] = {room}
	for i=0,4,1 do
		rooms[i+1] = {}
  	for k,r in pairs(rooms[i]) do
			local tbl = getRoomExits(r)
			for dir,num in pairs(tbl) do
  			if not table.contains(rooms,num) then
    			table.insert(rooms[i+1],num)
  			end
			end
  	end
  end
  for i,v in ipairs(rooms) do
		for k,num in ipairs(v) do
			highlightRoom(num, 143,188,143,0,0,0,0.5,255,0)
		end
	end
end

--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
--	Institute scripts
--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
if not concord.inst then concord.inst = {} end


--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
--	Symphonium scripts
--x-x-x-x-x-x-x-x-x-x-x-x-x-x-

if not concord.symph then concord.symph = {} end
concord.symph.aurics = {
		manabarbs = "tritone",
		egovice = "majorsecond",
		achromaticaura = "minorseventh",
		powerspikes = "majorseventh",
		[1] = "tritone",
		[2] = "majorsecond",
		[3] = "minorseventh",
		[4] = "majorseventh"}

function concord.symph.blanknote(target,bool)
	if not target then target = concord.target end
	target = concord.getFullName(target)
	if bool == nil then
		bool = false
		if concord.config.auto.blanknote and not concord.playerHasAff(target,"undeaf") then
		bool = true
		end
	end
	if bool then
		concord.doAdd("play blanknote @target",target)
	end
end

function concord.symph.play(target,what,blanknote) 
	if not target then target = concord.target end
	--blanknote takes a boolean value, true/false, and overrides autoblanknote
	if concord.affl.powerspikes and what == "discordantchord" then
		concord.box("GOT POWERSPIKES", "red", "^")
		return
	end
	concord.symph.blanknote(target,blanknote)
	concord.doAdd("play "..what.." @target",target)
end

function concord.symph.perform(stanza,effect,target)
	if not stanza then stanza = concord.symph.current.stanza end
	if not target then target = concord.target end
	if effect then
		if not concord.symph.song.canImbue(effect) then
			concord.box("Wrong stanza!","red")
			return
		end
	else
		effect = ""
	end
	local todo = stanza - concord.symph.current.stanza
	if todo > 1 then
		for i = 1,todo-1,1 do
			send("sm add perform song "..concord.symph.song.name)
		end
		send("sm add perform song "..concord.symph.song.name.." "..target.." "..effect)
	end
	if todo == 1 then
		send("sm add perform song "..concord.symph.song.name.." "..target.." "..effect)
	end
	if todo == 0 then
		send("sm add perform refrain "..concord.symph.song.name.." "..target.." "..effect)
	end
	if todo < 0 then
		concord.box("Song stanza too high!","red")
	end
end

function concord.symph.discordantChord(player)
	local count = 0
	local aurics = {
    {"manabarbs","green"},
    {"egovice","yellow"},
    {"powerspikes","orchid"};
    {"achromaticaura","gray"};
    }
	concord.doClear()
	for i,v in ipairs(aurics) do
		if concord.playerHasAff(player,v[1]) then
			count = count+1
		else
			concord.echo("Missing: <"..v[2]..">"..v[1])
			concord.symph.play(player,concord.symph.aurics[v[1]]) 
		end
	end
	if count == 4 then
		concord.symph.play(player,"discordantchord")
		concord.box("ATTEMPTING DCC ON "..player,"yellow","~%",player)
	end
end

function concord.symph.song.canImbue(effect,stanza)
	if not stanza then stanza = concord.symph.current.stanza end
	local val = table.contains(concord.symph.effects[math.ceil(stanza/3)], effect)
	return val
end


--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
--	Tessenchi scripts
--x-x-x-x-x-x-x-x-x-x-x-x-x-x-

if not concord.tessenchi then concord.tessenchi = {} end

function concord.tessenchi.eflowSip()
	if concord.hasSkill("Zarakido","Enigmaticflow") then
  	local teas = {"whitetea","greentea","oolongtea","blacktea"}
  	if not concord.tessenchi.sipping then
    	local teamode
    	if concord.tessenchi.discordantsymmetry then 
  			teamode = "chaotic" 
  		else
  			teamode = "harmonic"
  		end 
  		if concord.vitals.eflowbal == 1 and  concord.vitals.enigmaticflow <= 90 then
  			send("drink "..teas[math.random(4)].." "..teamode)
  			concord.tessenchi.sipping = true
  			tempTimer(2, [[concord.tessenchi.sipping = false]])
  		end
  	end
	end
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.tessenchi.eflowSip")

function concord.tessenchi.getStance()
	local stance = string.sub(gmcp.Char.Vitals.stance, 2,2)
	local stancetable = {
		n=0;b=1;t=2;c=3;s=4;k=5;		
	}
	concord.vitals.stance = stancetable[stance]
	concord.vitals.nextstance = math.mod(concord.vitals.stance,5)+1
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.tessenchi.getStance")

function concord.tessenchi.form(target,form,poison1,poison2)
	poison1 = poison1 or "escozul"
	poison2 = poison2 or "anerod"
	form = form or "duststack"
	send("wipe left")
	send("wipe right")
	concord.doAdd("envenom left with "..poison1.."|envenom right with "..poison2.."|beast order spit @target|kata perform @target "..form,target)
end


--x-x-x-x-x-x-x-x-x-x-x-x-x-x-
--	Healing scripts
--x-x-x-x-x-x-x-x-x-x-x-x-x-x-

if not concord.healing then concord.healing = {} end

function concord.healing.healme()
	local todo = {}
	if (not concord.healing.sentcmd)
	and (not concord.affl["aeon"])
	and (not concord.paused)
	and concord.config.healme
	and gmcp.Char.Vitals.balance == "1" 
	and gmcp.Char.Vitals.equilibrium == "1"
	and concord.hasSkill("Healing")
	and tonumber(gmcp.Char.Vitals.empathy) > 50
	then
		for i,v in ipairs(concord.healing.prios) do
			if concord.affl[v["aff"]] and (gmcp.Char.Vitals[v["bal"]] ~= "1" or concord.affl[concord.healing.preventedby[v["bal"]]]) then
				todo[#todo+1] = "cure me "..v["cure"]
			end
		end
	end
	local str = "sm insert 1 free "
	for i = 1,5,1 do
		if todo[1] then
			str = str..todo[1].."|"
			table.remove(todo, 1)
		end
	end
	if str ~= "sm insert 1 free " then
  	send(string.sub(str,1,-2))
    concord.healing.sent()
	end
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.healing.healme")

function concord.healing.sent()
	concord.healing.sentcmd = true
	if concord.healing.sentTimer then killTimer(concord.healing.sentTimer) end
	concord.healing.sentTimer = tempTimer(2, [[concord.healing.sentcmd = false]])
end

----------------------
-- Farheal
----------------------
function farheal.canDo()
	local health = tonumber(gmcp.Char.Vitals.hp)
	local maxhealth = tonumber(gmcp.Char.Vitals.maxhp)
	local ego = tonumber(gmcp.Char.Vitals.ego)
	local maxego = tonumber(gmcp.Char.Vitals.maxego)
	local healthpct = health/maxhealth
	local egopct = ego/maxego
	
	if concord and not concord.canAuto() then
		return false
	end
	
	if not concord.hasSkill("Healing") then
		return false
	end
	
	if healthpct > farheal.config.keephealth and egopct > farheal.config.keepego then
		return true
	end
	
	return false
end

function farheal.showAllies()
	local str = ""
	for i,v in pairs(farheal.allies) do
		str = str.." "..ndb.getcolor(i)..i..","
	end
	str = string.sub(str, 1, -2).."."
	cecho("\n<white>[<CornflowerBlue>Farheal<white>]: <green>Allies:"..str)
end

function farheal.ally(person,bool)
	person = string.title(person)
	if concord then person = concord.getFullName(person) end
	if bool == nil then bool = true end
	if bool then
		farheal.allies[person] = true
	else
		farheal.allies[person] = nil
	end
	local saveFile = getMudletHomeDir() .. "/farheal.allies.lua"
	table.save(saveFile, farheal.allies)
end

function farheal.succor()
	if farheal.canDo() then
  	enableTrigger("Farheal succor")
  	enableTrigger("Gag healing stratagem spam")
  	farheal.people = {}
  	local sendtable = {}
  	local strind = 0
  	local sendind = 1
  	for i,v in pairs(farheal.allies) do
		  strind = strind + 1
  		sendind = math.ceil(strind/5)
  		sendtable[sendind] = sendtable[sendind] or ""
  		sendtable[sendind] = sendtable[sendind].."succor "..i.."|"
  	end
		local strmod = math.mod(strind,5)
		if strmod == 0 then
			sendtable[#sendtable+1] = "echo ==Farheal succored everyone==|"
		else
			sendtable[#sendtable] = sendtable[#sendtable] .. "echo ==Farheal succored everyone==|"
		end
  	for i,v in ipairs(sendtable) do
  		v = string.sub(v, 1, -2)
  		send("sm add free "..v)
  	end
	end
end

function farheal.process()
	if farheal.canDo() then
  	for i,v in ipairs(farheal.prios) do
  		local affliction = v[1]
  		local cure = v[2]
  		for person,tbl in pairs(farheal.people) do
  			if tbl.affs[affliction] then
  				enableTrigger("Gag healing stratagem spam")
  				return "cure "..person.." "..cure.."|farcure "..person.." "..cure.."|echo ==Farheal healed=="
  			end
  		end
  	end
  	local heal_target
  	local lowest_health = farheal.config.healing_threshold
  	for person,tbl in pairs(farheal.people) do
  			if (tbl.vitals.health/tbl.vitals.maxhealth) < lowest_health and not table.contains(farheal.harmony, person) then
    			lowest_health = (tbl.vitals.health/tbl.vitals.maxhealth)
    			heal_target = person
  			end
  	end
  	if heal_target then 
  		enableTrigger("Gag healing stratagem spam")
  		return "heal "..heal_target.."|farheal "..heal_target.."|echo ==Farheal healed=="
  	else 
  		return false
  	end
	end
end

function concord.deleteAllP(count)
  if not count then deleteLine() end
  tempLineTrigger(count or 1,1,[[
  deleteLine()
if not isPrompt() then
  concord.deleteAllP()
end
]])
end

--o-o-o-o-o-o-o-o-o-o-o-o-o--
-- CONCORD EXTERNAL TRIGGERS
--o-o-o-o-o-o-o-o-o-o-o-o-o--

concord.loaded = concord.loaded or {
	triggers = {},
	aliases = {},
}

local triggers = {
	combat_awareness = 	
	{
	{
		name =  "Person sapped",
		script =  [[
			if ndb.isenemy(matches[2]) and concord.canAuto() then
				concord.doAdd(concord.commands.webbing, matches[2])
			end
			concord.call(matches[2].." is sapped.", 2)
					]],
		pattern =  [[^With a grim smile, \w+ touches the trees and sap courses out in a thick syrup that lunges at (\w+), coating \w+ in the viscid liquid.$]],
	},
	{
		name =  "Person succumbed",
		script =  [[
			if ndb.isenemy(matches[2]) and concord.canAuto() then
				if concord.hasSkill("Music","Tritone") and concord.symph then
					concord.doClear()
					concord.symph.play(matches[2],"tritone")
				else
					concord.doAdd(concord.commands.stun, matches[2])
				end
			end
			concord.format(matches[1],matches[2],"cyan")
			]],
		pattern =  [[^Whispering to \w+self, \w+ points at (\w+).$]],
	},
	{
		name =  "Succumb tick",
		script =  [[
			concord.format(matches[1],matches[2],"cyan")
			]],
		pattern =  [[^(\w+)'s eyes become vacant and wider as a silver light envelops \w+.$]],
	},
	{
		name =  "Person getting summoned",
		script =  [[
			concord.box(matches[2] .. " is summoned! Use alias MONO.","red","~-",matches[2])
			concord.call(matches[2] .. " is being summoned!",2)
			]],
		pattern =  [[^(\w+) suddenly stumbles as the air is filled with a high-pitched thrum.$]],

	},
	{
		name =  "Person truehealed",
		script =  [[
			concord.echo(matches[2].." TRUEHEALED", "white")
			]],
		pattern =  [[^(\w+) stretches \w+ arms out to either side and drops \w+ head back with \w+ eyes closed. A blinding white light strikes him on the forehead and travels to \w+ feet, lifting \w+ off the ground. As \w+ slowly turns, all \w+ wounds heal and a blazing aura pulsates around \w+.$]],
	},
	{
		name =  "Ally calling toad",
		script =  [[
			if ndb.isenemy(string.title(string.lower(matches[2]))) then
				enableTrigger("concord contemplate and toadcurse now")
				concord.doadd("discern target",matches[2],false)
			end
			]],
		pattern =  [[^\(.+\): \w+ says, "(\w+).+\b(?:MANA|mana|Mana)\b.+
			]],
	},
	{
		name =  "Person pitted",
		script =  [[
			if ndb.isenemy(matches[2]) then
				concord.box(matches[2].." PITTED! Attack them!","orange","^-_",matches[2])
			end
			]],
		pattern =  [[^The ground suddenly falls away from beneath (\w+) and \w+ goes tumbling into a pit.$]],
	},
	{
		name =  "Greatpent up",
		script =  [[
			concord.call("Greatpent is up at "..gmcp.Room.Info.name .." (v"..gmcp.Room.Info.num..")!",2)
			]],

		pattern =  [[^Muttering words of power, you trace a cobalt blue pentagram in each of the four directions. The four pentagrams remain hovering in the air, connected to each other by lines of energy.$]],
	},
	{
		name =  "Dispelled illself",
		script =  [[
			concord.echo("<green>Dispelled illself!")
			]],

		pattern =  [[^With a simple gesture, you dispel an illusory self on
			]],
	},
	{
		name =  "Person has illself",
		script =  [[
		if ndb.isenemy(matches[2]) then
			concord.format(matches[1],matches[2],"firebrick")
		end
			]],
		pattern =  [[^(\w+)'s illusory doppleganger completely absorbs the damage.$]],

	},
	{
		name =  "Person in room",
		script =  [[
			if ndb.isenemy(matches[2]) and not concord.isNeutralArea(gmcp.Room.Info) then
				concord.call(matches[2].." entered room at " ..gmcp.Room.Info.num,2)
			end
			deleteLine()
			concord.echo(ndb.getcolor(matches[2])..matches[2].."<tomato> IN ROOM")
			]],

		pattern =  [[^A shimmer of light plays on your goggle lenses as (\w+) arrives from
			]],

	},
	{
		name =  "Successful dcc",
		script =  [[
			concord.playerAff(matches[2],"undeaf",true)
			if ndb.isenemy(matches[2]) then
				concord.call("Damage "..matches[2])
				if concord.hasSkill("Music") then
					concord.box(matches[2].." DCC", "green_yellow","~%",matches[2])
					concord.symph.play(matches[2],"minorsixth")
					concord.symph.play(matches[2],"minorsixth")
				end
			elseif ndb.exists(matches[2]) then
				concord.echo(ndb.getcolor(matches[2])..matches[2].."<red> got dcc!")
				concord.call("Gust "..matches[2],3)
				concord.gust(matches[2])
			end
			]],
		pattern =  [[^(\w+) screams in agony as four notes threaten to rip \w+ asunder.$]],

	},
	},
	
	mage_bombs = {
		{
		name = "Cyclone 1 of 2",
		script = [[concord.echo("Aeromancy unleash incoming in 12s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Aeromancy unleash damage incoming in 2s!","red") end )
		]],
		pattern = [[^From the four directions, winds blow in and gather, rotating slowly and gathering more momentum. The clouds begin to twist as they follow in their wake.$]],
		},
		{
		name = "Cyclone 2 of 2",
		script = [[concord.echo("Aeromancy unleash incoming in 8s! Brace yourself or leave the meld!", "orange")
		]],
		pattern = [[^Picking up speed, the relentlessly churning winds become more powerful, and lightning begins to strike out from among the swirling clouds.$]],
		},
		{
		name = "Maelstrom 1 of 2",
		script = [[concord.echo("Aquamancy unleash incoming in 12s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Aquamancy unleash damage incoming in 2s!","red") end )
		]],
		pattern = [[^The sky glows with glowing sapphire clouds that release a powerful rain that pounds down upon you in heavy sheets.$]],
		},
		{
		name = "Maelstrom 2 of 2",
		script = [[concord.echo("Aquamancy unleash incoming in 8s! Brace yourself or leave the meld!", "orange")
		]],
		pattern = [[^Towering waves roll across the waters, reaching to impossible heights and forming watery figures of monstrous sea creatures.$]],
		},
		{
		name = "Pollute 1 of 2",
		script = [[concord.echo("Geomancy unleash incoming in 12s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Geomancy unleash damage incoming in 2s!","red") end )
		]],
		pattern = [[^Small fissures open up in the tainted earth, releasing toxic fumes that blacken the ground and pollute the air.$]],
		},
		{
		name = "Pollute 2 of 2",
		script = [[concord.echo("Geomancy unleash incoming in 8s! Brace yourself or leave the meld!", "orange")
		]],
		pattern = [[^With a great rumble, the small fissures on the ground widen to large cracks, sending great gouts of poisonous clouds roiling and churning into the air, making breathing difficult and your eyes water painfully.$]],
		},
		{
		name = "Inferno 1 of 2",
		script = [[concord.echo("Pyromancy unleash incoming in 12s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Pyromancy unleash damage incoming in 2s!","red") end )
		]],
		pattern = [[^Small bonfires suddenly burst into existence here, surrounded by circles of dancing flames.$]],
		},
		{
		name = "Inferno 2 of 2",
		script = [[concord.echo("Pyromancy unleash incoming in 8s! Brace yourself or leave the meld!", "orange")
		]],
		pattern = [[^Dancing flames jump into the small bonfires here, which suddenly explode into enormous pyres of incandescent fire which radiate waves of intense heat.$]],
		},
		{
		name = "Fury 1 of 2",
		script = [[concord.echo("Druidry unleash incoming in 12s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Druidry unleash damage incoming in 2s!","red") end )
		]],
		pattern = [[^Deep within the ground, an ominous rumbling shakes the earth and the trees begin to sway.$]],
		},
		{
		name = "Fury 2 of 2",
		script = [[concord.echo("Druidry unleash incoming in 8s! Brace yourself or leave the meld!", "orange")
		]],
		pattern = [[^A shrieking wind rushes through the trees, sending forest debris and small rocks up into the air. Animals howl around you and the sky darkens overhead.$]],
		},
		{
		name = "Wildewood Glinshari",
		script = [[concord.echo("Wildewood Glinshari incoming in 10s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Wildewood Glinshari damage incoming in 2s!","red") end )
		]],
		pattern = [[^(\w+) goes rigid and still before a quiver climbs up (?:her|his) behemoth form, causing (?:her|his) roots and branches to quiver as a thrill rushes through (?:her|him)\. Every blossom upon (?:her|his) branches spread their petals wide, releasing their pollen in a multicoloured cloud that twists about (?:her|him), throbbing and churning as it grows in size\.$]],
		},
		{
		name = "Aquachemantics Aquoxitism",
		script = [[concord.echo("Aquachemantics Aquoxitism incoming in 10s! Prepare for a lot of damage!", "yellow")
		tempTimer(10, function() concord.echo("Aquachemantics Aquoxitism damage incoming in 2s!","red") end )
		]],
		pattern = [[^(\w+) exhales a long, slow breath into (?:his|her) mists, willing many of them together\. A swirling mass of mists churns together, expanding outwards in a chilly fog\.$]],
		},
		{
		name = "Wyrdenwood bomb start",
		script = [[concord.echo("Wyrdenwood bomb incoming in 10s! Prepare for a lot of damage!", "yellow")
		tempTimer(5, function() concord.echo("Wyrdenwood bomb damage incoming in 5s!","red") end )
		]],
		pattern = [[^A pool of shadows and decay floods out from (\w+)'s treehollow and pours down \w+ trunk. A blanket of sinisterly chittering insects, their multi-faceted eyes glowing a deep red, manifests from within the murky shadows and slowly creeps across the ground in an impassable carpet of hunger, rage, and doom.$]],
		},
	},
}

function concord.createTriggers()
	for i,v in ipairs(concord.loaded.triggers) do
		killTrigger(v)
		concord.loaded.triggers[i] = nil
	end
	for i,v in pairs(triggers) do
		for n,trigger in ipairs(v) do
			disableTrigger(trigger.name)
			concord.loaded.triggers[#concord.loaded.triggers+1] = tempRegexTrigger(trigger.pattern,trigger.script)
		end
	end
end
registerAnonymousEventHandler("concord loaded", "concord.createTriggers")

function concord.checkPrivs()
	local ret = 0
	if gmcp.Comm.Channel then
		ret = -1
		if table.contains(gmcp.Comm.Channel,"The Clan of the Rose Court") then
		  ret = 1
		end
	else
		sendGMCP([[Core.Supports.Add ["Comm.Channel 1"] ]])
	end
	if ret < 0 then
		for i,v in ipairs(concord.loaded.triggers) do
			  killTrigger(v)
			  concord.loaded.triggers[i] = nil
		end
		local keep = {"load","skillprios","instakills","customPrompt","config","aero","inst","tessenchi","symph","sentinel","checkPrivs","onlogin","vitals","save","paused","escape","skills","deltaVitals","loaded","defs","healing","target"}
		for k,v in pairs(concord) do
			if not table.contains(keep,k) then
				concord[k]=nil
			end
		end
	end
end
registerAnonymousEventHandler("gmcp.Char.Vitals", "concord.checkPrivs")



