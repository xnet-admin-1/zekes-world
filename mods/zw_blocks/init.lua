-- zw_blocks: Curated Block Palette for Zeek's World
-- A small, colorful set of blocks designed for a 5-year-old

local MOD_NAME = minetest.get_current_modname()

-------------------------------------------------------------------------------
-- Helper to register a simple colored block
-------------------------------------------------------------------------------

local function register_block(name, description, color_hex, groups)
    groups = groups or { cracky = 3 }
    groups.creative_breakable = 1

    minetest.register_node(MOD_NAME .. ":" .. name, {
        description = description,
        tiles = { MOD_NAME .. "_" .. name .. ".png" },
        groups = groups,
        -- Fallback color if texture is missing
        color = color_hex,
        paramtype2 = "color",
        palette = "",
    })
end

-------------------------------------------------------------------------------
-- Core terrain blocks
-------------------------------------------------------------------------------

minetest.register_node(MOD_NAME .. ":grass", {
    description = "Grass",
    tiles = { MOD_NAME .. "_grass_top.png", MOD_NAME .. "_dirt.png", MOD_NAME .. "_grass_side.png" },
    groups = { crumbly = 3, soil = 1, creative_breakable = 1 },
})

minetest.register_node(MOD_NAME .. ":dirt", {
    description = "Dirt",
    tiles = { MOD_NAME .. "_dirt.png" },
    groups = { crumbly = 3, soil = 1, creative_breakable = 1 },
})

minetest.register_node(MOD_NAME .. ":stone", {
    description = "Stone",
    tiles = { MOD_NAME .. "_stone.png" },
    groups = { cracky = 3, creative_breakable = 1 },
})

minetest.register_node(MOD_NAME .. ":sand", {
    description = "Sand",
    tiles = { MOD_NAME .. "_sand.png" },
    groups = { crumbly = 3, falling_node = 1, creative_breakable = 1 },
})

minetest.register_node(MOD_NAME .. ":wood", {
    description = "Wood",
    tiles = { MOD_NAME .. "_wood.png" },
    groups = { choppy = 2, creative_breakable = 1 },
})

minetest.register_node(MOD_NAME .. ":leaf", {
    description = "Leaves",
    tiles = { MOD_NAME .. "_leaf.png" },
    drawtype = "allfaces_optional",
    paramtype = "light",
    groups = { snappy = 3, leafdecay = 3, creative_breakable = 1 },
})

-------------------------------------------------------------------------------
-- Water (special - non-solid, flowing appearance)
-------------------------------------------------------------------------------

minetest.register_node(MOD_NAME .. ":water", {
    description = "Water",
    tiles = { MOD_NAME .. "_water.png" },
    drawtype = "liquid",
    paramtype = "light",
    walkable = false,
    pointable = false,
    buildable_to = true,
    liquidtype = "source",
    liquid_alternative_flowing = MOD_NAME .. ":water",
    liquid_alternative_source = MOD_NAME .. ":water",
    liquid_viscosity = 1,
    groups = { water = 1, liquid = 3, creative_breakable = 1 },
    post_effect_color = { a = 128, r = 30, g = 80, b = 180 },
})

-------------------------------------------------------------------------------
-- Glass
-------------------------------------------------------------------------------

minetest.register_node(MOD_NAME .. ":glass", {
    description = "Glass",
    tiles = { MOD_NAME .. "_glass.png" },
    drawtype = "glasslike",
    paramtype = "light",
    sunlight_propagates = true,
    groups = { cracky = 3, oddly_breakable_by_hand = 3, creative_breakable = 1 },
})

-------------------------------------------------------------------------------
-- Fun colored blocks (the kid palette)
-------------------------------------------------------------------------------

local fun_blocks = {
    { name = "red",      desc = "Red Block",      hex = "#E04040" },
    { name = "orange",   desc = "Orange Block",   hex = "#F09020" },
    { name = "yellow",   desc = "Yellow Block",   hex = "#F0E040" },
    { name = "green",    desc = "Green Block",    hex = "#40C040" },
    { name = "blue",     desc = "Blue Block",     hex = "#4060E0" },
    { name = "purple",   desc = "Purple Block",   hex = "#9040D0" },
    { name = "pink",     desc = "Pink Block",     hex = "#F080C0" },
    { name = "white",    desc = "White Block",    hex = "#F0F0F0" },
    { name = "black",    desc = "Black Block",    hex = "#303030" },
    { name = "glow",     desc = "Glow Block",     hex = "#FFEE55" },
}

for _, b in ipairs(fun_blocks) do
    local groups = { cracky = 3, creative_breakable = 1 }
    local light_source = 0

    if b.name == "glow" then
        light_source = 12
    end

    minetest.register_node(MOD_NAME .. ":" .. b.name, {
        description = b.desc,
        tiles = { MOD_NAME .. "_" .. b.name .. ".png" },
        groups = groups,
        light_source = light_source,
    })
end

-------------------------------------------------------------------------------
-- Special blocks
-------------------------------------------------------------------------------

minetest.register_node(MOD_NAME .. ":cloud", {
    description = "Cloud",
    tiles = { MOD_NAME .. "_cloud.png" },
    drawtype = "glasslike",
    paramtype = "light",
    walkable = true,
    sunlight_propagates = true,
    groups = { cracky = 3, creative_breakable = 1 },
    light_source = 4,
})

-------------------------------------------------------------------------------
-- Unknown node handler (shows as pink error block)
-------------------------------------------------------------------------------

minetest.register_node(MOD_NAME .. ":unknown", {
    description = "Unknown Block",
    tiles = { "unknown_node.png" },
    groups = { cracky = 3 },
})

-------------------------------------------------------------------------------
-- Creative inventory - only show our blocks
-------------------------------------------------------------------------------

if minetest.get_modpath("creative") then
    -- Will be handled by zw_hud
end

minetest.log("action", "[zw_blocks] Block palette loaded (" ..
    tostring(8 + #fun_blocks + 2) .. " block types)")
