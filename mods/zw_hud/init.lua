-- zw_hud: Kid-Friendly HUD for Zeek's World
-- Large icons, speech bubbles, simplified inventory for small hands

local MOD_NAME = minetest.get_current_modname()

-------------------------------------------------------------------------------
-- HUD element IDs per player
-------------------------------------------------------------------------------

local player_huds = {}

-------------------------------------------------------------------------------
-- Speech Bubble
-------------------------------------------------------------------------------

local SPEECH_DURATION = 6.0
local speech_timers = {}

local function show_speech_bubble(player_name, text)
    local player = minetest.get_player_by_name(player_name)
    if not player then return end

    local huds = player_huds[player_name]
    if not huds then return end

    -- Update speech text
    if huds.speech_bg then
        player:hud_change(huds.speech_bg, "text", "zw_hud_speech_bg.png")
    end
    if huds.speech_text then
        player:hud_change(huds.speech_text, "text", text)
    end

    -- Set timer to hide
    speech_timers[player_name] = SPEECH_DURATION
end

-- Hook into Oliver's speech system
minetest.register_on_chat_message(function(name, message)
    -- Intercept Oliver messages and show as HUD bubble instead
    -- (Oliver sends via chat_send_player, this catches display)
    return false
end)

-- Override Oliver's chat output to use HUD
local original_chat_send = minetest.chat_send_player
minetest.chat_send_player = function(name, message)
    if message:sub(1, 9) == "[Oliver] " then
        local text = message:sub(10)
        show_speech_bubble(name, text)
        return -- Don't show in chat
    end
    original_chat_send(name, message)
end

-------------------------------------------------------------------------------
-- Hotbar setup
-------------------------------------------------------------------------------

local HOTBAR_SIZE = 8  -- Limited slots for simplicity

local function setup_hotbar(player)
    player:hud_set_hotbar_itemcount(HOTBAR_SIZE)
    player:hud_set_hotbar_image("zw_hud_hotbar.png")
    player:hud_set_hotbar_selected_image("zw_hud_hotbar_selected.png")
end

-------------------------------------------------------------------------------
-- Simple creative inventory
-------------------------------------------------------------------------------

local function get_inventory_formspec()
    -- Large buttons, simple grid, no crafting
    local blocks = {
        "zw_blocks:grass", "zw_blocks:dirt", "zw_blocks:stone",
        "zw_blocks:sand", "zw_blocks:wood", "zw_blocks:leaf",
        "zw_blocks:glass", "zw_blocks:cloud",
        "zw_blocks:red", "zw_blocks:orange", "zw_blocks:yellow",
        "zw_blocks:green", "zw_blocks:blue", "zw_blocks:purple",
        "zw_blocks:pink", "zw_blocks:white", "zw_blocks:black",
        "zw_blocks:glow",
    }

    -- Big formspec for small fingers
    local fs = "formspec_version[6]"
    fs = fs .. "size[12,8]"
    fs = fs .. "label[0.5,0.5;Pick a Block!]"

    local col = 0
    local row = 0
    for i, block_name in ipairs(blocks) do
        local x = 0.5 + col * 1.4
        local y = 1.2 + row * 1.4
        fs = fs .. "item_image_button[" .. x .. "," .. y .. ";1.2,1.2;" .. block_name .. ";block_" .. i .. ";]"
        col = col + 1
        if col >= 8 then
            col = 0
            row = row + 1
        end
    end

    -- Hotbar at bottom
    fs = fs .. "list[current_player;main;0.5,6.5;8,1;]"

    return fs
end

local function fill_creative_inventory(player)
    local inv = player:get_inventory()
    inv:set_size("main", HOTBAR_SIZE * 4)

    -- Pre-fill hotbar with basics
    local starter_blocks = {
        "zw_blocks:grass", "zw_blocks:stone", "zw_blocks:wood",
        "zw_blocks:red", "zw_blocks:blue", "zw_blocks:yellow",
        "zw_blocks:glow", "zw_blocks:cloud",
    }

    for i, name in ipairs(starter_blocks) do
        inv:set_stack("main", i, ItemStack(name .. " 99"))
    end
end

-------------------------------------------------------------------------------
-- Inventory formspec handler
-------------------------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= MOD_NAME .. ":inventory" then return false end

    local inv = player:get_inventory()
    for key, _ in pairs(fields) do
        if key:sub(1, 6) == "block_" then
            local idx = tonumber(key:sub(7))
            if idx then
                -- Add stack of this block to player inventory
                local blocks = {
                    "zw_blocks:grass", "zw_blocks:dirt", "zw_blocks:stone",
                    "zw_blocks:sand", "zw_blocks:wood", "zw_blocks:leaf",
                    "zw_blocks:glass", "zw_blocks:cloud",
                    "zw_blocks:red", "zw_blocks:orange", "zw_blocks:yellow",
                    "zw_blocks:green", "zw_blocks:blue", "zw_blocks:purple",
                    "zw_blocks:pink", "zw_blocks:white", "zw_blocks:black",
                    "zw_blocks:glow",
                }
                if blocks[idx] then
                    local stack = ItemStack(blocks[idx] .. " 99")
                    if not inv:contains_item("main", stack) then
                        inv:add_item("main", stack)
                    end
                end
            end
        end
    end
    return true
end)

-- Open inventory on key
minetest.register_on_player_inventory_action(function(player) end)

-- Set the inventory formspec for all players
minetest.register_on_joinplayer(function(player)
    player:set_inventory_formspec(get_inventory_formspec())
end)

-------------------------------------------------------------------------------
-- HUD Elements
-------------------------------------------------------------------------------

local function create_hud(player)
    local name = player:get_player_name()
    player_huds[name] = {}

    -- Crosshair (large, friendly)
    player_huds[name].crosshair = player:hud_add({
        hud_elem_type = "image",
        position = { x = 0.5, y = 0.5 },
        scale = { x = 2, y = 2 },
        text = "zw_hud_crosshair.png",
        alignment = { x = 0, y = 0 },
        offset = { x = 0, y = 0 },
    })

    -- Speech bubble background (hidden initially)
    player_huds[name].speech_bg = player:hud_add({
        hud_elem_type = "image",
        position = { x = 0.5, y = 0.12 },
        scale = { x = 2, y = 1 },
        text = "",  -- Empty = hidden
        alignment = { x = 0, y = 0 },
        offset = { x = 0, y = 0 },
    })

    -- Speech bubble text (hidden initially)
    player_huds[name].speech_text = player:hud_add({
        hud_elem_type = "text",
        position = { x = 0.5, y = 0.12 },
        scale = { x = 100, y = 100 },
        text = "",
        number = 0xFFFFFF,
        alignment = { x = 0, y = 0 },
        offset = { x = 0, y = 0 },
        size = { x = 1, y = 1 },
    })

    -- Setup hotbar and inventory
    setup_hotbar(player)
    fill_creative_inventory(player)
end

local function remove_hud(player)
    local name = player:get_player_name()
    player_huds[name] = nil
    speech_timers[name] = nil
end

-------------------------------------------------------------------------------
-- Player join/leave hooks
-------------------------------------------------------------------------------

minetest.register_on_joinplayer(function(player)
    create_hud(player)
end)

minetest.register_on_leaveplayer(function(player)
    remove_hud(player)
end)

-------------------------------------------------------------------------------
-- Globalstep for speech timer
-------------------------------------------------------------------------------

minetest.register_globalstep(function(dtime)
    for name, remaining in pairs(speech_timers) do
        remaining = remaining - dtime
        if remaining <= 0 then
            -- Hide speech bubble
            local player = minetest.get_player_by_name(name)
            if player and player_huds[name] then
                player:hud_change(player_huds[name].speech_bg, "text", "")
                player:hud_change(player_huds[name].speech_text, "text", "")
            end
            speech_timers[name] = nil
        else
            speech_timers[name] = remaining
        end
    end
end)

minetest.log("action", "[zw_hud] Kid-friendly HUD loaded")
