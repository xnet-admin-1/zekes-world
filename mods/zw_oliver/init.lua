-- zw_oliver: Oliver the AI Cat Companion
-- An orange tabby cat that follows the player and speaks via LLM

local MOD_NAME = minetest.get_current_modname()
local MOD_PATH = minetest.get_modpath(MOD_NAME)

-- Settings
local API_URL = minetest.settings:get("zw_oliver_api_url") or "https://inf.xnet.ngo/v1/chat/completions"
local API_KEY = minetest.settings:get("zw_oliver_api_key") or ""
local MODEL = "pollinations-pollen/gemini-fast"
local SYSTEM_PROMPT = "You are Oliver, a 1-year-old orange tabby cat. You speak simply so a 5-year-old can understand. You mix in cat sounds like meow, purr, mrrp. Keep responses to 1-2 short sentences."

-- Follow parameters
local FOLLOW_DISTANCE = 3.0
local FOLLOW_SPEED = 4.0
local SPEAK_COOLDOWN = 45.0

-------------------------------------------------------------------------------
-- LLM API
-------------------------------------------------------------------------------

local function query_llm(prompt, callback)
    -- Varied fallback phrases when LLM is unavailable
    local fallbacks = {
        "Meow! This place is fun!",
        "Mrrp! *stretches* I like it here!",
        "Purrrr... what should we build?",
        "*bats at a butterfly* Meow!",
        "Mew! Let's explore over there!",
        "*rubs against your leg* Purrrr",
        "Meow meow! I see something cool!",
        "*yawns* This is a nice spot!",
        "Mrrp! *wiggles tail* Adventure time!",
        "*pounces on nothing* Hehe! Meow!",
        "Purr purr... you're doing great!",
        "*sits and tilts head* Mew?",
        "Meow! Can we go up high?",
        "*rolls over* Belly rubs? No? Ok meow!",
        "Mrrp! That block looks tasty... just kidding!",
    }
    local fallback = fallbacks[math.random(#fallbacks)]

    if not minetest.request_http_api then
        callback(fallback)
        return
    end

    local http = minetest.request_http_api()
    if not http then
        callback(fallback)
        return
    end

    local body = minetest.write_json({
        model = MODEL,
        messages = {
            { role = "system", content = SYSTEM_PROMPT },
            { role = "user", content = prompt },
        },
        max_tokens = 60,
    })

    http.fetch({
        url = API_URL,
        method = "POST",
        data = body,
        extra_headers = {
            "Content-Type: application/json",
            "Authorization: Bearer " .. API_KEY,
        },
        timeout = 10,
    }, function(response)
        if response.succeeded then
            local data = minetest.parse_json(response.data)
            if data and data.choices and data.choices[1] then
                callback(data.choices[1].message.content)
                return
            end
        end
        callback(fallback)
    end)
end

-------------------------------------------------------------------------------
-- Oliver Entity
-------------------------------------------------------------------------------

local oliver_entity = {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        collisionbox = { -0.2, 0.0, -0.2, 0.2, 0.5, 0.2 },
        visual = "cube",
        visual_size = { x = 0.3, y = 0.3, z = 0.4 },
        textures = {
            "zw_oliver_top.png",   -- top
            "zw_oliver_top.png",   -- bottom
            "zw_oliver_side.png",  -- right
            "zw_oliver_side.png",  -- left
            "zw_oliver_cat.png",   -- front (face)
            "zw_oliver_back.png",  -- back
        },
        makes_footstep_sound = false,
        nametag = "Oliver",
        nametag_color = "#FF9933",
        static_save = false,
        infotext = "",
        pointable = false,
    },

    -- State
    _owner = nil,
    _last_speak_time = 0,
    _last_chunk = { x = 0, z = 0 },
    _greeted = false,
    _idle_timer = 0,
}

function oliver_entity:on_activate(staticdata)
    self.object:set_armor_groups({ immortal = 1 })
end

function oliver_entity:on_step(dtime)
    if not self._owner then return end

    local player = minetest.get_player_by_name(self._owner)
    if not player then return end

    local pos = self.object:get_pos()
    local player_pos = player:get_pos()
    local dir = vector.subtract(player_pos, pos)
    dir.y = 0 -- Ignore vertical for horizontal distance
    local dist = vector.length(dir)

    -- Face the player
    if dist > 0.5 then
        local yaw = math.atan2(dir.z, dir.x) - math.pi / 2
        self.object:set_yaw(yaw)
    end

    -- Move toward player using set_pos (no physics bouncing)
    local target = vector.copy(pos)

    if dist > FOLLOW_DISTANCE then
        local norm_dir = vector.normalize(dir)
        local speed = FOLLOW_SPEED * dtime
        target.x = pos.x + norm_dir.x * speed
        target.z = pos.z + norm_dir.z * speed
    elseif dist < 1.5 then
        -- Too close, stay put
    end

    -- Always sit at ground level (y = 1)
    target.y = 1.0

    self.object:set_pos(target)
    self.object:set_velocity({ x = 0, y = 0, z = 0 })

    -- Teleport if too far (player flew/teleported)
    if dist > 30 then
        self.object:set_pos(vector.new(player_pos.x + 3, 1.0, player_pos.z + 3))
    end

    -- Initial greeting
    if not self._greeted then
        self._greeted = true
        self:speak("Zeek just started exploring! Greet him warmly.")
    end

    -- New chunk detection
    local chunk_x = math.floor(player_pos.x / 16)
    local chunk_z = math.floor(player_pos.z / 16)
    if chunk_x ~= self._last_chunk.x or chunk_z ~= self._last_chunk.z then
        self._last_chunk = { x = chunk_x, z = chunk_z }
        self:speak("Zeek found a new area! Comment on what you see.")
    end

    -- Idle chatter every 90 seconds
    self._idle_timer = self._idle_timer + dtime
    if self._idle_timer > 90 then
        self._idle_timer = 0
        self:speak("Zeek is playing! Say something fun or encouraging.")
    end
end

function oliver_entity:speak(prompt)
    local now = minetest.get_gametime()
    if now - self._last_speak_time < SPEAK_COOLDOWN then return end
    self._last_speak_time = now

    if not self._owner then return end

    query_llm(prompt, function(response)
        local player = minetest.get_player_by_name(self._owner)
        if player then
            minetest.chat_send_player(self._owner, "[Oliver] " .. response)
            -- TODO: Show as HUD speech bubble instead of chat
        end
    end)
end

minetest.register_entity(MOD_NAME .. ":oliver", oliver_entity)

-------------------------------------------------------------------------------
-- Spawn Oliver when player joins
-------------------------------------------------------------------------------

local oliver_objects = {}

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    -- Spawn Oliver after a short delay to ensure world is loaded
    minetest.after(2.0, function()
        local p = minetest.get_player_by_name(name)
        if not p then return end

        -- Remove any existing Oliver for this player
        if oliver_objects[name] and oliver_objects[name]:get_pos() then
            oliver_objects[name]:remove()
        end

        local pos = p:get_pos()
        local spawn_pos = vector.new(pos.x + 3, 1.0, pos.z + 3)
        local obj = minetest.add_entity(spawn_pos, MOD_NAME .. ":oliver")
        if obj then
            local ent = obj:get_luaentity()
            ent._owner = name
            oliver_objects[name] = obj
        end
    end)
end)

-- Clean up tracking on leave (entity removes itself via static_save=false)
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if oliver_objects[name] then
        if oliver_objects[name]:get_pos() then
            oliver_objects[name]:remove()
        end
        oliver_objects[name] = nil
    end
end)

minetest.log("action", "[zw_oliver] Oliver the Cat loaded")
