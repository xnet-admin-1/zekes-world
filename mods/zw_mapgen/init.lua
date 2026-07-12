-- zw_mapgen: OpenStreetMap World Generator
-- Generates voxel terrain from real-world OSM data

local MOD_NAME = minetest.get_current_modname()
local MOD_PATH = minetest.get_modpath(MOD_NAME)

-- Settings
local CENTER_LAT = tonumber(minetest.settings:get("zw_mapgen_lat")) or 43.6057601
local CENTER_LON = tonumber(minetest.settings:get("zw_mapgen_lon")) or -116.3932135
local MAP_RADIUS = tonumber(minetest.settings:get("zw_mapgen_radius")) or 80

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
-- OSM data loading (disabled - using random gen for now)
-------------------------------------------------------------------------------

--[[
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
]]--

-------------------------------------------------------------------------------
-- World Generation (Random/Procedural with VoxelManip for speed)
-------------------------------------------------------------------------------

local function generate_world()
    minetest.log("action", "[zw_mapgen] Generating random world with VoxelManip...")

    local rng = PcgRandom(os.time())
    local R = MAP_RADIUS  -- 80 blocks radius = 160x160 area

    -- Get content IDs for fast VoxelManip writing
    local c_air = minetest.get_content_id("air")
    local c_grass = minetest.get_content_id("zw_blocks:grass")
    local c_dirt = minetest.get_content_id("zw_blocks:dirt")
    local c_stone = minetest.get_content_id("zw_blocks:stone")
    local c_wood = minetest.get_content_id("zw_blocks:wood")
    local c_leaf = minetest.get_content_id("zw_blocks:leaf")
    local c_glass = minetest.get_content_id("zw_blocks:glass")
    local c_water = minetest.get_content_id("zw_blocks:water")
    local c_sand = minetest.get_content_id("zw_blocks:sand")
    local c_bedrock = minetest.get_content_id("zw_blocks:bedrock")

    -- Create VoxelManip covering our entire world
    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(
        vector.new(-R - 2, -41, -R - 2),
        vector.new(R + 2, 41, R + 2)
    )
    local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
    local data = vm:get_data()

    -- Fill everything with air first
    for i = 1, #data do
        data[i] = c_air
    end

    -- Ground layer (thick - 40 blocks deep)
    for x = -R, R - 1 do
        for z = -R, R - 1 do
            data[area:index(x, 0, z)] = c_grass
            for y = -1, -39, -1 do
                data[area:index(x, y, z)] = c_dirt
            end
            data[area:index(x, -40, z)] = c_bedrock
        end
    end

    -- Roads - 8 random paths, wider
    for _ = 1, 8 do
        local sx = rng:next(-R + 5, R - 5)
        local sz = rng:next(-R + 5, R - 5)
        local ex = rng:next(-R + 5, R - 5)
        local ez = rng:next(-R + 5, R - 5)
        plot_line(sx, sz, ex, ez, function(x, z)
            for dx = -1, 1 do
                for dz = -1, 1 do
                    if in_bounds(x + dx, z + dz) then
                        data[area:index(x + dx, 0, z + dz)] = c_stone
                    end
                end
            end
        end)
    end

    -- Buildings - 25 of them, closer together
    for _ = 1, 25 do
        local bx = rng:next(-R + 10, R - 20)
        local bz = rng:next(-R + 10, R - 20)
        local bw = rng:next(4, 9)
        local bd = rng:next(4, 9)
        local bh = rng:next(3, 8)

        -- Floor
        for x = bx, bx + bw do
            for z = bz, bz + bd do
                if in_bounds(x, z) then
                    data[area:index(x, 0, z)] = c_wood
                end
            end
        end

        -- Walls
        for y = 1, bh do
            for x = bx, bx + bw do
                if in_bounds(x, bz) then
                    local node = c_stone
                    if y > 1 and y < bh and (x - bx) % 3 == 1 then node = c_glass end
                    data[area:index(x, y, bz)] = node
                    data[area:index(x, y, bz + bd)] = node
                end
            end
            for z = bz, bz + bd do
                if in_bounds(bx, z) then
                    local node = c_stone
                    if y > 1 and y < bh and (z - bz) % 3 == 1 then node = c_glass end
                    data[area:index(bx, y, z)] = node
                    data[area:index(bx + bw, y, z)] = node
                end
            end
        end

        -- Roof
        for x = bx, bx + bw do
            for z = bz, bz + bd do
                if in_bounds(x, z) then
                    data[area:index(x, bh, z)] = c_stone
                end
            end
        end

        -- Door (front wall center)
        local door_x = bx + math.floor(bw / 2)
        for dx = 0, 1 do
            for y = 1, 3 do
                if in_bounds(door_x + dx, bz) then
                    data[area:index(door_x + dx, y, bz)] = c_air
                end
            end
        end
    end

    -- Trees - denser, every 4 blocks
    for x = -R + 2, R - 2, 4 do
        for z = -R + 2, R - 2, 4 do
            if rng:next(0, 100) < 15 then
                -- Only place on grass
                if data[area:index(x, 0, z)] == c_grass then
                    -- Trunk
                    local trunk_h = rng:next(3, 5)
                    for y = 1, trunk_h do
                        data[area:index(x, y, z)] = c_wood
                    end
                    -- Crown
                    for dy = 0, 2 do
                        for dx = -2, 2 do
                            for dz = -2, 2 do
                                if dx * dx + dz * dz <= 4 and in_bounds(x + dx, z + dz) then
                                    data[area:index(x + dx, trunk_h + 1 + dy, z + dz)] = c_leaf
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Ponds - 5 of them
    for _ = 1, 5 do
        local px = rng:next(-R + 10, R - 10)
        local pz = rng:next(-R + 10, R - 10)
        local pr = rng:next(2, 5)
        for dx = -pr, pr do
            for dz = -pr, pr do
                if dx * dx + dz * dz <= pr * pr and in_bounds(px + dx, pz + dz) then
                    data[area:index(px + dx, 0, pz + dz)] = c_water
                    -- Sand border
                    if dx * dx + dz * dz > (pr - 1) * (pr - 1) then
                        data[area:index(px + dx, 0, pz + dz)] = c_sand
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Underground: Caves
    ---------------------------------------------------------------------------
    for _ = 1, 8 do
        local cx = rng:next(-R + 10, R - 10)
        local cz = rng:next(-R + 10, R - 10)
        local cy = rng:next(-30, -5)
        local cave_len = rng:next(10, 30)
        local dir_x = rng:next(-2, 2)
        local dir_z = rng:next(-2, 2)

        local px, py, pz = cx, cy, cz
        for _ = 1, cave_len do
            -- Carve a 2x2x2 or 3x3x3 sphere
            local cr = rng:next(1, 2)
            for dx = -cr, cr do
                for dy = -cr, cr do
                    for dz = -cr, cr do
                        if dx*dx + dy*dy + dz*dz <= cr*cr then
                            local nx, ny, nz = px + dx, py + dy, pz + dz
                            if in_bounds(nx, nz) and ny > -39 and ny < 0 then
                                data[area:index(nx, ny, nz)] = c_air
                            end
                        end
                    end
                end
            end
            -- Wander
            px = px + dir_x + rng:next(-1, 1)
            pz = pz + dir_z + rng:next(-1, 1)
            py = py + rng:next(-1, 1)
            py = math.max(-35, math.min(-3, py))
        end
    end

    ---------------------------------------------------------------------------
    -- Underground: Ore veins (glow, amethyst, ruby-colored stones)
    ---------------------------------------------------------------------------
    local c_glow = minetest.get_content_id("zw_blocks:glow")
    local c_purple = minetest.get_content_id("zw_blocks:purple")
    local c_blue = minetest.get_content_id("zw_blocks:blue")
    local c_red = minetest.get_content_id("zw_blocks:red")

    local ores = { c_glow, c_purple, c_blue, c_red }
    for _ = 1, 20 do
        local ox = rng:next(-R + 5, R - 5)
        local oz = rng:next(-R + 5, R - 5)
        local oy = rng:next(-35, -5)
        local ore_type = ores[rng:next(1, #ores)]
        local vein_size = rng:next(3, 8)

        for _ = 1, vein_size do
            if in_bounds(ox, oz) and oy > -39 and oy < 0 then
                data[area:index(ox, oy, oz)] = ore_type
            end
            ox = ox + rng:next(-1, 1)
            oz = oz + rng:next(-1, 1)
            oy = oy + rng:next(-1, 1)
        end
    end

    ---------------------------------------------------------------------------
    -- Underground: Treasure rooms (small lit rooms with glow blocks)
    ---------------------------------------------------------------------------
    for _ = 1, 3 do
        local rx = rng:next(-R + 15, R - 15)
        local rz = rng:next(-R + 15, R - 15)
        local ry = rng:next(-25, -10)
        local rw = rng:next(3, 5)
        local rd = rng:next(3, 5)
        local rh = 4

        -- Carve room
        for x = rx, rx + rw do
            for z = rz, rz + rd do
                for y = ry, ry + rh do
                    if in_bounds(x, z) and y > -39 and y < 0 then
                        data[area:index(x, y, z)] = c_air
                    end
                end
            end
        end

        -- Glow blocks on ceiling
        for x = rx + 1, rx + rw - 1, 2 do
            for z = rz + 1, rz + rd - 1, 2 do
                if in_bounds(x, z) then
                    data[area:index(x, ry + rh, z)] = c_glow
                end
            end
        end

        -- Treasure in center
        local tx = rx + math.floor(rw / 2)
        local tz = rz + math.floor(rd / 2)
        if in_bounds(tx, tz) then
            data[area:index(tx, ry, tz)] = c_purple
            data[area:index(tx, ry + 1, tz)] = c_glow
        end
    end

    ---------------------------------------------------------------------------
    -- Surface: Hills (raised terrain areas)
    ---------------------------------------------------------------------------
    for _ = 1, 6 do
        local hx = rng:next(-R + 15, R - 15)
        local hz = rng:next(-R + 15, R - 15)
        local hr = rng:next(4, 10)
        local hh = rng:next(2, 5)

        for dx = -hr, hr do
            for dz = -hr, hr do
                local dist_sq = dx*dx + dz*dz
                if dist_sq <= hr*hr and in_bounds(hx + dx, hz + dz) then
                    -- Height falls off from center
                    local height = math.floor(hh * (1 - math.sqrt(dist_sq) / hr) + 0.5)
                    for y = 1, height do
                        data[area:index(hx + dx, y, hz + dz)] = c_dirt
                    end
                    if height > 0 then
                        data[area:index(hx + dx, height, hz + dz)] = c_grass
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Surface: Flower patches (colored blocks at ground level)
    ---------------------------------------------------------------------------
    local c_yellow = minetest.get_content_id("zw_blocks:yellow")
    local c_pink = minetest.get_content_id("zw_blocks:pink")
    local c_orange = minetest.get_content_id("zw_blocks:orange")
    local flower_colors = { c_red, c_yellow, c_pink, c_orange }

    for _ = 1, 12 do
        local fx = rng:next(-R + 5, R - 5)
        local fz = rng:next(-R + 5, R - 5)
        local color = flower_colors[rng:next(1, #flower_colors)]
        local patch_size = rng:next(2, 4)

        for dx = -patch_size, patch_size do
            for dz = -patch_size, patch_size do
                if rng:next(0, 100) < 40 and in_bounds(fx + dx, fz + dz) then
                    if data[area:index(fx + dx, 0, fz + dz)] == c_grass then
                        data[area:index(fx + dx, 1, fz + dz)] = color
                    end
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Surface: Stone outcrops
    ---------------------------------------------------------------------------
    for _ = 1, 8 do
        local sx = rng:next(-R + 5, R - 5)
        local sz = rng:next(-R + 5, R - 5)
        local sr = rng:next(1, 3)

        for dx = -sr, sr do
            for dz = -sr, sr do
                if dx*dx + dz*dz <= sr*sr and in_bounds(sx + dx, sz + dz) then
                    local sh = rng:next(1, 3)
                    for y = 0, sh do
                        data[area:index(sx + dx, y, sz + dz)] = c_stone
                    end
                end
            end
        end
    end

    -- Barrier walls (bedrock through ground + 2 above, glass above that)
    for x = -R - 1, R do
        for y = -40, 2 do
            data[area:index(x, y, -R - 1)] = c_bedrock
            data[area:index(x, y, R)] = c_bedrock
        end
        for y = 3, 40 do
            data[area:index(x, y, -R - 1)] = c_glass
            data[area:index(x, y, R)] = c_glass
        end
    end
    for z = -R - 1, R do
        for y = -40, 2 do
            data[area:index(-R - 1, y, z)] = c_bedrock
            data[area:index(R, y, z)] = c_bedrock
        end
        for y = 3, 40 do
            data[area:index(-R - 1, y, z)] = c_glass
            data[area:index(R, y, z)] = c_glass
        end
    end

    -- Bedrock floor at y=-40 (unbreakable)
    for x = -R - 1, R do
        for z = -R - 1, R do
            data[area:index(x, -40, z)] = c_bedrock
        end
    end

    -- Write all data at once
    vm:set_data(data)
    vm:write_to_map(true)

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
        local spawn_pos = vector.new(0, 5, 0)
        player:set_pos(spawn_pos)
    end)
end)

minetest.log("action", "[zw_mapgen] OSM Map Generator loaded")
