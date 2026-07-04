-- zw_mapgen: OpenStreetMap World Generator
-- Generates voxel terrain from real-world OSM data

local MOD_NAME = minetest.get_current_modname()
local MOD_PATH = minetest.get_modpath(MOD_NAME)

-- Settings
local CENTER_LAT = tonumber(minetest.settings:get("zw_mapgen_lat")) or 43.6057601
local CENTER_LON = tonumber(minetest.settings:get("zw_mapgen_lon")) or -116.3932135
local MAP_RADIUS = tonumber(minetest.settings:get("zw_mapgen_radius")) or 200

-- Constants
local METERS_PER_DEG_LAT = 111320.0
local METERS_PER_DEG_LON = METERS_PER_DEG_LAT * math.cos(math.rad(CENTER_LAT))

-------------------------------------------------------------------------------
-- Coordinate conversion
-------------------------------------------------------------------------------

local function latlon_to_block(lat, lon)
    local x = math.floor((lon - CENTER_LON) * METERS_PER_DEG_LON + 0.5)
    local z = math.floor((lat - CENTER_LAT) * METERS_PER_DEG_LAT + 0.5)
    return x, z
end

local function in_bounds(x, z)
    return x >= -MAP_RADIUS and x < MAP_RADIUS and z >= -MAP_RADIUS and z < MAP_RADIUS
end

-------------------------------------------------------------------------------
-- Bresenham line drawing
-------------------------------------------------------------------------------

local function plot_line(x0, z0, x1, z1, fn)
    local dx = math.abs(x1 - x0)
    local dz = math.abs(z1 - z0)
    local sx = x0 < x1 and 1 or -1
    local sz = z0 < z1 and 1 or -1
    local err = dx - dz
    local cx, cz = x0, z0

    while true do
        fn(cx, cz)
        if cx == x1 and cz == z1 then break end
        local e2 = 2 * err
        if e2 > -dz then err = err - dz; cx = cx + sx end
        if e2 < dx then err = err + dx; cz = cz + sz end
    end
end

-------------------------------------------------------------------------------
-- Point-in-polygon test
-------------------------------------------------------------------------------

local function point_in_polygon(x, z, pts)
    local inside = false
    local j = #pts
    for i = 1, #pts do
        local xi, zi = pts[i][1], pts[i][2]
        local xj, zj = pts[j][1], pts[j][2]
        if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
            inside = not inside
        end
        j = i
    end
    return inside
end

-------------------------------------------------------------------------------
-- Polygon fill
-------------------------------------------------------------------------------

local function fill_polygon(outline, fn)
    if #outline < 3 then return end
    local pts = {}
    local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
    for _, ll in ipairs(outline) do
        local x, z = latlon_to_block(ll.lat, ll.lon)
        table.insert(pts, { x, z })
        min_x = math.min(min_x, x); max_x = math.max(max_x, x)
        min_z = math.min(min_z, z); max_z = math.max(max_z, z)
    end
    for z = min_z, max_z do
        for x = min_x, max_x do
            if in_bounds(x, z) and point_in_polygon(x, z, pts) then
                fn(x, z)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Tree placement
-------------------------------------------------------------------------------

local function place_tree(pos)
    local trunk_height = 5
    for y = 1, trunk_height do
        minetest.set_node(vector.new(pos.x, y, pos.z), { name = "zw_blocks:wood" })
    end
    for dy = 0, 2 do
        for dx = -2, 2 do
            for dz = -2, 2 do
                if dx * dx + dz * dz <= 5 then
                    minetest.set_node(
                        vector.new(pos.x + dx, trunk_height + 1 + dy, pos.z + dz),
                        { name = "zw_blocks:leaf" }
                    )
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- OSM data loading
-------------------------------------------------------------------------------

local function load_osm_data()
    local filepath = MOD_PATH .. "/data/osm.json"
    local file = io.open(filepath, "r")
    if not file then
        minetest.log("warning", "[zw_mapgen] No OSM data file found at " .. filepath)
        return nil
    end
    local content = file:read("*a")
    file:close()
    return minetest.parse_json(content)
end

local function parse_osm_elements(raw)
    local buildings = {}
    local roads = {}
    local parks = {}
    local water = {}

    if not raw or not raw.elements then return buildings, roads, parks, water end

    for _, el in ipairs(raw.elements) do
        local tags = el.tags or {}
        local geom = el.geometry or {}
        if #geom == 0 then goto continue end

        local coords = {}
        for _, node in ipairs(geom) do
            table.insert(coords, { lat = node.lat, lon = node.lon })
        end

        if tags.building then
            local h = 4.0
            if tags.height then
                local hv = tonumber(tags.height)
                if hv then h = math.max(3, math.min(5, hv / 2)) end
            end
            table.insert(buildings, { outline = coords, height = h, name = tags.name or "" })
        elseif tags.highway then
            local road_widths = {
                motorway = 4, trunk = 4,
                primary = 3, secondary = 3,
                tertiary = 2, residential = 2,
            }
            local w = road_widths[tags.highway] or 1
            table.insert(roads, { points = coords, width = w, type = tags.highway })
        elseif tags.leisure == "park" then
            table.insert(parks, { outline = coords, name = tags.name or "" })
        elseif tags.natural == "water" then
            table.insert(water, { outline = coords })
        end

        ::continue::
    end

    return buildings, roads, parks, water
end

-------------------------------------------------------------------------------
-- World Generation
-------------------------------------------------------------------------------

local function generate_world()
    minetest.log("action", "[zw_mapgen] Generating world from OSM data...")

    -- Ground layer
    for x = -MAP_RADIUS, MAP_RADIUS - 1 do
        for z = -MAP_RADIUS, MAP_RADIUS - 1 do
            minetest.set_node(vector.new(x, 0, z), { name = "zw_blocks:grass" })
        end
    end

    -- Load and parse OSM data
    local raw = load_osm_data()
    if not raw then
        minetest.log("warning", "[zw_mapgen] No OSM data - generating flat world only")
        return
    end

    local buildings, roads, parks, water = parse_osm_elements(raw)

    -- Water
    for _, w in ipairs(water) do
        fill_polygon(w.outline, function(x, z)
            minetest.set_node(vector.new(x, 0, z), { name = "zw_blocks:water" })
        end)
    end

    -- Parks
    for _, p in ipairs(parks) do
        fill_polygon(p.outline, function(x, z)
            minetest.set_node(vector.new(x, 0, z), { name = "zw_blocks:grass" })
        end)
    end

    -- Roads
    for _, r in ipairs(roads) do
        local half_w = math.ceil(r.width / 2)
        for i = 1, #r.points - 1 do
            local x0, z0 = latlon_to_block(r.points[i].lat, r.points[i].lon)
            local x1, z1 = latlon_to_block(r.points[i + 1].lat, r.points[i + 1].lon)
            plot_line(x0, z0, x1, z1, function(x, z)
                for dx = -half_w, half_w do
                    for dz = -half_w, half_w do
                        if in_bounds(x + dx, z + dz) then
                            minetest.set_node(vector.new(x + dx, 0, z + dz), { name = "zw_blocks:stone" })
                        end
                    end
                end
            end)
        end
    end

    -- Buildings
    for _, b in ipairs(buildings) do
        local height = math.floor(b.height * 2 + 0.5)
        height = math.max(6, math.min(15, height))

        -- Walls
        for i = 1, #b.outline - 1 do
            local x0, z0 = latlon_to_block(b.outline[i].lat, b.outline[i].lon)
            local x1, z1 = latlon_to_block(b.outline[i + 1].lat, b.outline[i + 1].lon)
            plot_line(x0, z0, x1, z1, function(x, z)
                if not in_bounds(x, z) then return end
                for y = 1, height do
                    local node_name = "zw_blocks:stone"
                    if y > 1 and y < height and x % 3 == 0 then
                        node_name = "zw_blocks:glass"
                    end
                    minetest.set_node(vector.new(x, y, z), { name = node_name })
                end
            end)
        end

        -- Floor
        fill_polygon(b.outline, function(x, z)
            minetest.set_node(vector.new(x, 0, z), { name = "zw_blocks:wood" })
        end)
    end

    -- Scatter trees
    local rng = PcgRandom(42)
    for x = -MAP_RADIUS, MAP_RADIUS - 1, 6 do
        for z = -MAP_RADIUS, MAP_RADIUS - 1, 6 do
            if rng:next(0, 100) < 12 then
                local node = minetest.get_node(vector.new(x, 0, z))
                local above = minetest.get_node(vector.new(x, 1, z))
                if node.name == "zw_blocks:grass" and above.name == "air" then
                    place_tree(vector.new(x, 0, z))
                end
            end
        end
    end

    minetest.log("action", "[zw_mapgen] World generation complete")
end

-------------------------------------------------------------------------------
-- Hook into mapgen or generate on first join
-------------------------------------------------------------------------------

local world_generated = false

minetest.register_on_joinplayer(function(player)
    if world_generated then return end
    world_generated = true

    -- Use minetest.after to avoid blocking the join
    minetest.after(1.0, function()
        generate_world()
        -- Teleport player to spawn after generation
        local spawn_pos = vector.new(0, 2, 0)
        player:set_pos(spawn_pos)
    end)
end)

minetest.log("action", "[zw_mapgen] OSM Map Generator loaded")
