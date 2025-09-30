
local storage = core.get_mod_storage()
local cooldowns = {}
local flying = {}
local sword_entities = {}

local FLY_TIME = 4
local FALL_IMMUNITY = 2
local FLY_COOLDOWN = 120  -- right-click fly cooldown in seconds

core.register_privilege("antifall", {
    description = "No fall damage",
    give_to_singleplayer = false,
})

core.register_on_player_hpchange(function(player, hp_change, reason)
    if reason.type == "fall" then
        local name = player:get_player_name()
        local privs = core.get_player_privs(name)
        if privs and privs.antifall then
            return 0
        end
    end
    return hp_change
end, true)

core.register_entity("swordfly:flying_sword", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        pointable = false,
        visual = "wielditem",
        visual_size = {x=1, y=1},
        textures = {"swordfly:sword_of_wind"},
    },

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end
        local objects = core.get_objects_inside_radius(pos, 2)
        local player_near = false
        for _, obj in ipairs(objects) do
            if obj:is_player() then
                player_near = true
                break
            end
        end
        if not player_near then
            self.object:remove()
        end
    end,
})

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local val = storage:get_int("cd_" .. name)
    if val and val > 0 then
        cooldowns[name] = val
    end
end)

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local privs = core.get_player_privs(name)
    if privs then
        privs.fly = nil
        privs.antifall = nil
        core.set_player_privs(name, privs)
    end
    if sword_entities[name] then
        local ent = sword_entities[name]
        if ent and ent:get_luaentity() then
            ent:remove()
        end
        sword_entities[name] = nil
    end
    if cooldowns[name] then
        storage:set_int("cd_" .. name, cooldowns[name])
    end
    flying[name] = nil
end)

core.register_on_prejoinplayer(function(name, ip)
    if flying[name] then
        return "You cannot log out while flying on the Sword of Wind."
    end
end)

core.register_tool("swordfly:sword_of_wind", {
    description = "Sword of Wind (right-click to ground to fly)",
    inventory_image = "sword_of_winds.png",
    tool_capabilities = {
        full_punch_interval = 0.8,  -- left-click interval 0.8s
        max_drop_level = 1,
        groupcaps = {
            snappy = {times = {[1]=0.8, [2]=0.8, [3]=0.8}, uses=30, maxlevel=2},
        },
        damage_groups = {fleshy=5},
    },

    on_place = function(itemstack, user, pointed_thing)
        local name = user:get_player_name()
        if not name then return itemstack end

        local now = core.get_gametime()
        if cooldowns[name] and cooldowns[name] > now then
            local left = cooldowns[name] - now
            core.chat_send_player(name, string.format("Sword fly is recharging (%.0f s left)", left))
            return itemstack
        end

        if flying[name] then
            core.chat_send_player(name, "You are already flying on the Sword of Wind!")
            return itemstack
        end

        local privs = core.get_player_privs(name)
        if not privs then privs = {} end
        privs.fly = true
        core.set_player_privs(name, privs)

        core.chat_send_player(name, "You are flying on the Sword of Wind for " .. FLY_TIME .. " seconds.")
        flying[name] = true

        local pos = user:get_pos()
        local sword_entity = core.add_entity({x=pos.x, y=pos.y-5, z=pos.z}, "swordfly:flying_sword")
        if sword_entity then
            sword_entity:set_attach(user, "", {x=0, y=-5, z=0}, {x=0, y=0, z=0})
            sword_entities[name] = sword_entity
        end

        local remaining = FLY_TIME
        local function countdown()
            if remaining > 0 then
                if remaining <= 3 then
                    core.chat_send_player(name, "Flight ends in " .. remaining .. "s...")
                end
                remaining = remaining - 1
                core.after(1, countdown)
            end
        end
        core.after(1, countdown)

        core.after(FLY_TIME + 1, function()
            local privs2 = core.get_player_privs(name) or {}
            privs2.fly = nil
            privs2.antifall = true
            core.set_player_privs(name, privs2)

            local player_obj = core.get_player_by_name(name)
            if player_obj then
                core.chat_send_player(name, "Sword power faded. Safe landing for " .. FALL_IMMUNITY .. " seconds.")
            end

            core.after(FALL_IMMUNITY, function()
                local privs3 = core.get_player_privs(name) or {}
                privs3.antifall = nil
                core.set_player_privs(name, privs3)
                local p = core.get_player_by_name(name)
                if p then
                    core.chat_send_player(name, "Safe landing effect ended.")
                end
            end)

            if sword_entities[name] then
                local ent = sword_entities[name]
                if ent and ent:get_luaentity() then
                    ent:remove()
                end
                sword_entities[name] = nil
            end

            flying[name] = nil
            cooldowns[name] = core.get_gametime() + FLY_COOLDOWN  -- 120s right-click cooldown
            storage:set_int("cd_" .. name, cooldowns[name])
        end)

        return itemstack
    end,
})

core.register_craft({
    output = "swordfly:sword_of_wind",
    recipe = {
        {"", "default:diamond", ""},
        {"default:diamond", "default:diamond", "default:diamond"},
        {"", "default:diamond", ""},
    }
})
