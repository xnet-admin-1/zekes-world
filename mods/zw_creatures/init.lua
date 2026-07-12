-- zw_creatures: Friendly Ambient Creatures
-- Passive mobs that make the world feel alive

local MOD_NAME = minetest.get_current_modname()

-------------------------------------------------------------------------------
-- Butterfly
-------------------------------------------------------------------------------

local butterfly_entity = {
    initial_properties = {
        physical = false,
        collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
        visual = "cube",
        visual_size = { x = 0.15, y = 0.1, z = 0.15 },
        textures = {
            "zw_creatures_butterfly.png",
            "zw_creatures_butterfly.png",
            "zw_creatures_butterfly.png",
            "zw_creatures_butterfly.png",
            "zw_creatures_butterfly.png",
            "zw_creatures_butterfly.png",
        },
        static_save = false,
        pointable = false,
    },

    _timer = 0,
    _dir_x = 0,
    _dir_z = 0,
    _bob_phase = 0,
    _lifetime = 0,
}

function butterfly_entity:on_activate()
    self._dir_x = (math.random() - 0.5) * 2
    self._dir_z = (math.random() - 0.5) * 2
    self._bob_phase = math.random() * math.pi * 2
    self._lifetime = 0
end

function butterfly_entity:on_step(dtime)
    self._timer = self._timer + dtime
    self._lifetime = self._lifetime + dtime

    -- Despawn after 5 minutes
    if self._lifetime > 300 then
        self.object:remove()
        return
    end

    -- Change direction occasionally
    if self._timer > 3 then
        self._timer = 0
        self._dir_x = (math.random() - 0.5) * 2
        self._dir_z = (math.random() - 0.5) * 2
    end

    local pos = self.object:get_pos()
    self._bob_phase = self._bob_phase + dtime * 4

    -- Float and drift
    local new_pos = vector.new(
        pos.x + self._dir_x * dtime * 0.8,
        2.5 + math.sin(self._bob_phase) * 0.5,
        pos.z + self._dir_z * dtime * 0.8
    )

    self.object:set_pos(new_pos)
    self.object:set_yaw(math.atan2(self._dir_z, self._dir_x))
end

minetest.register_entity(MOD_NAME .. ":butterfly", butterfly_entity)

-------------------------------------------------------------------------------
-- Bunny
-------------------------------------------------------------------------------

local bunny_entity = {
    initial_properties = {
        physical = false,
        collisionbox = { -0.15, -0.12, -0.15, 0.15, 0.18, 0.15 },
        visual = "cube",
        visual_size = { x = 0.25, y = 0.25, z = 0.3 },
        textures = {
            "zw_creatures_bunny_top.png",
            "zw_creatures_bunny.png",
            "zw_creatures_bunny.png",
            "zw_creatures_bunny.png",
            "zw_creatures_bunny.png",
            "zw_creatures_bunny_face.png",
        },
        static_save = false,
        pointable = false,
    },

    _state = "idle",  -- idle, hopping, eating
    _timer = 0,
    _hop_dir_x = 0,
    _hop_dir_z = 0,
    _lifetime = 0,
}

function bunny_entity:on_activate()
    self._lifetime = 0
end

function bunny_entity:on_step(dtime)
    self._timer = self._timer + dtime
    self._lifetime = self._lifetime + dtime

    if self._lifetime > 300 then
        self.object:remove()
        return
    end

    local pos = self.object:get_pos()

    if self._state == "idle" then
        -- Sit still, occasionally decide to hop or eat
        if self._timer > math.random(2, 5) then
            self._timer = 0
            local choice = math.random(1, 3)
            if choice == 1 then
                self._state = "hopping"
                self._hop_dir_x = (math.random() - 0.5) * 3
                self._hop_dir_z = (math.random() - 0.5) * 3
            else
                self._state = "eating"
            end
        end
        self.object:set_pos(vector.new(pos.x, 0.7, pos.z))

    elseif self._state == "hopping" then
        -- Hop in a direction
        local hop_y = 0.7 + math.abs(math.sin(self._timer * 8)) * 0.3
        local new_pos = vector.new(
            pos.x + self._hop_dir_x * dtime,
            hop_y,
            pos.z + self._hop_dir_z * dtime
        )
        self.object:set_pos(new_pos)
        self.object:set_yaw(math.atan2(self._hop_dir_z, self._hop_dir_x))

        if self._timer > 1.5 then
            self._timer = 0
            self._state = "idle"
        end

    elseif self._state == "eating" then
        -- Bob head down
        local bob = 0.7 - math.abs(math.sin(self._timer * 3)) * 0.05
        self.object:set_pos(vector.new(pos.x, bob, pos.z))

        if self._timer > 3 then
            self._timer = 0
            self._state = "idle"
        end
    end
end

minetest.register_entity(MOD_NAME .. ":bunny", bunny_entity)

-------------------------------------------------------------------------------
-- Frog
-------------------------------------------------------------------------------

local frog_entity = {
    initial_properties = {
        physical = false,
        collisionbox = { -0.1, -0.08, -0.1, 0.1, 0.12, 0.1 },
        visual = "cube",
        visual_size = { x = 0.2, y = 0.15, z = 0.2 },
        textures = {
            "zw_creatures_frog.png",
            "zw_creatures_frog.png",
            "zw_creatures_frog.png",
            "zw_creatures_frog.png",
            "zw_creatures_frog.png",
            "zw_creatures_frog_face.png",
        },
        static_save = false,
        pointable = false,
    },

    _timer = 0,
    _state = "sitting",
    _hop_dir_x = 0,
    _hop_dir_z = 0,
    _lifetime = 0,
}

function frog_entity:on_activate()
    self._lifetime = 0
end

function frog_entity:on_step(dtime)
    self._timer = self._timer + dtime
    self._lifetime = self._lifetime + dtime

    if self._lifetime > 300 then
        self.object:remove()
        return
    end

    local pos = self.object:get_pos()

    if self._state == "sitting" then
        self.object:set_pos(vector.new(pos.x, 0.7, pos.z))
        -- Frogs hop less often
        if self._timer > math.random(4, 8) then
            self._timer = 0
            self._state = "hopping"
            self._hop_dir_x = (math.random() - 0.5) * 4
            self._hop_dir_z = (math.random() - 0.5) * 4
        end

    elseif self._state == "hopping" then
        -- Big hop arc
        local hop_y = 0.7 + math.sin(self._timer * 6) * 0.4
        local new_pos = vector.new(
            pos.x + self._hop_dir_x * dtime,
            math.max(0.7, hop_y),
            pos.z + self._hop_dir_z * dtime
        )
        self.object:set_pos(new_pos)
        self.object:set_yaw(math.atan2(self._hop_dir_z, self._hop_dir_x))

        if self._timer > 0.8 then
            self._timer = 0
            self._state = "sitting"
        end
    end
end

minetest.register_entity(MOD_NAME .. ":frog", frog_entity)

-------------------------------------------------------------------------------
-- Bird
-------------------------------------------------------------------------------

local bird_entity = {
    initial_properties = {
        physical = false,
        collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
        visual = "cube",
        visual_size = { x = 0.2, y = 0.15, z = 0.25 },
        textures = {
            "zw_creatures_bird.png",
            "zw_creatures_bird.png",
            "zw_creatures_bird.png",
            "zw_creatures_bird.png",
            "zw_creatures_bird.png",
            "zw_creatures_bird_face.png",
        },
        static_save = false,
        pointable = false,
    },

    _center_x = 0,
    _center_z = 0,
    _angle = 0,
    _radius = 5,
    _height = 8,
    _lifetime = 0,
}

function bird_entity:on_activate()
    local pos = self.object:get_pos()
    self._center_x = pos.x
    self._center_z = pos.z
    self._angle = math.random() * math.pi * 2
    self._radius = math.random(3, 7)
    self._height = pos.y
    self._lifetime = 0
end

function bird_entity:on_step(dtime)
    self._lifetime = self._lifetime + dtime

    if self._lifetime > 300 then
        self.object:remove()
        return
    end

    -- Circle around a point
    self._angle = self._angle + dtime * 1.2
    local new_x = self._center_x + math.cos(self._angle) * self._radius
    local new_z = self._center_z + math.sin(self._angle) * self._radius
    local bob = math.sin(self._angle * 3) * 0.3

    self.object:set_pos(vector.new(new_x, self._height + bob, new_z))
    -- Face direction of movement
    self.object:set_yaw(self._angle + math.pi / 2)
end

minetest.register_entity(MOD_NAME .. ":bird", bird_entity)

-------------------------------------------------------------------------------
-- Spawn creatures when world is generated
-------------------------------------------------------------------------------

local function spawn_creatures()
    minetest.after(5.0, function()
        local R = 70  -- Stay within map bounds

        -- Spawn butterflies (8)
        for _ = 1, 8 do
            local x = math.random(-R, R)
            local z = math.random(-R, R)
            minetest.add_entity(vector.new(x, 2.5, z), MOD_NAME .. ":butterfly")
        end

        -- Spawn bunnies (6)
        for _ = 1, 6 do
            local x = math.random(-R, R)
            local z = math.random(-R, R)
            minetest.add_entity(vector.new(x, 0.7, z), MOD_NAME .. ":bunny")
        end

        -- Spawn frogs near center (4) - they'd normally be near ponds
        for _ = 1, 4 do
            local x = math.random(-R / 2, R / 2)
            local z = math.random(-R / 2, R / 2)
            minetest.add_entity(vector.new(x, 0.7, z), MOD_NAME .. ":frog")
        end

        -- Spawn birds (5) - flying high
        for _ = 1, 5 do
            local x = math.random(-R, R)
            local z = math.random(-R, R)
            minetest.add_entity(vector.new(x, math.random(8, 14), z), MOD_NAME .. ":bird")
        end

        minetest.log("action", "[zw_creatures] Spawned ambient creatures")
    end)
end

-- Spawn on first player join
local creatures_spawned = false
minetest.register_on_joinplayer(function(player)
    if creatures_spawned then return end
    creatures_spawned = true
    spawn_creatures()
end)

minetest.log("action", "[zw_creatures] Creatures mod loaded")
