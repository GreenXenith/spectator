spectator = {}
spectator.spectators = {}

local spectators = spectator.spectators

minetest.register_privilege("spectator", {
	description = "Allows player to use spectator mode."
})

function spectator.is_spectator(name)
    return spectators[name] ~= nil
end

function spectator.send(name, msg)
	minetest.chat_send_player(name, minetest.colorize("#00ff00", "[SPECTATE] ") .. msg)
end

minetest.register_on_player_hpchange(function(player, hp_change)
	if spectator.is_spectator(player:get_player_name()) then
		player:set_breath(11)
		return 0
	else
		return hp_change
	end
end, true)

minetest.register_playerevent(function(player, event)
	local air = player:get_breath()
	if spectator.is_spectator(player:get_player_name()) and event == "breath_changed" and air < 11 then
		player:set_breath(11)
	end
end)

function spectator.start(player)
	local name = player:get_player_name()
	local privs = minetest.get_player_privs(name)
	local props = player:get_properties()
	local origin = player:get_pos()
	spectators[name] = {
		privs = privs,
		origin = origin,
		armor_groups = player:get_armor_groups(),
		hud = player:hud_get_flags(),
		hp = player:get_hp(),
		breath = player:get_breath(),
		properties = {
			visual_size = props.visual_size,
			makes_footstep_sound = props.makes_footstep_sound,
			collisionbox = props.collisionbox,
		},
	}
	minetest.set_player_privs(name, {shout = true, fly = true, fast = privs.fast, noclip = true})
	player:set_armor_groups({immortal = 1})
	player:hud_set_flags({
		hotbar = false,
		healthbar = false,
		crosshair = false,
		wielditem = false,
		breathbar = false,
	})
	player:set_properties({
		visual_size = {x = 0, y = 0},
		makes_footstep_sound = false,
		selectionbox = {0, 0, 0, 0, 0, 0}
	})
	minetest.after(30, spectator.stop, player, "30 seconds expired, returning to origin.")
end

function spectator.stop(player, reason)
	local name = player:get_player_name()
	if spectator.is_spectator(name) then
		local data = spectators[name]
		minetest.set_player_privs(name, data.privs)
		player:set_armor_groups(data.armor_groups)
		player:hud_set_flags(data.hud)
		player:set_properties(data.properties)
		player:set_pos(data.origin)
		player:set_hp(data.hp)
		player:set_breath(data.hp)
		spectators[name] = nil
		if reason and type(reason) == "string" then
			spectator.send(name, reason)
		end
	end
end


minetest.register_chatcommand("spectate", {
	description = "Toggle spectate mode for 30 seconds.",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		local has_interact = minetest.check_player_privs(player, {interact=true})
		if not spectator.is_spectator(name) then
			if not has_interact then
				spectator.send(name, "You need the 'interact' priv to run this command.")
				return false
			end
			spectator.start(player)
			spectator.send(name, "You are in spectator mode for 30 seconds.")
			return true
		else
			spectator.stop(player, "Exiting spectator mode, returning to origin.")
		end
	end
})

minetest.register_on_leaveplayer(function(player)
	spectator.stop(player)
end)

local timer = 0
if minetest.get_modpath("areas") then
	minetest.register_globalstep(function(dt)
		timer = timer + dt
		if timer >= 1 then
			for name, data in pairs(spectators) do
				local player = minetest.get_player_by_name(name)
				if player then
					if not areas:canInteract(player:get_pos(), name) then
						spectator.send(name, "You entered another player's area, returning to origin.")
						player:set_pos(data.origin)
					end
				end
			end
			timer = 0
		end
	end)
end
