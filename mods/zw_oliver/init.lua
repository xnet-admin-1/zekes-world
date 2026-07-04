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
local SPEAK_COOLDOWN = 10.0

-------------------------------------------------------------------------------
-- LLM API
-------------------------------------------------------------------------------

local function query_llm(prompt, callback)
    if not minetest.request_http_api then
        callback("Mrrp! *stretches*")
        return
    end

    local http = minetest.request_http_api()
    if not http then
        callback("Mrrp! *stretches*")
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
        callback("Mrrp! *stretches*")
    end)
end

-------------------------------------------------------------------------------
-- Oliver Entity
-------------------------------------------------------------------------------

local oliver_entity = {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = { -0.3, 0.0, -0.3, 0.3, 0.6, 0.3 },
        visual = "mesh",
        -- TODO: Replace with actual cat mesh
        visual_size = { x = 1, y = 1, z = 1 },
        textures = { "zw_oliver_cat.png" },
        makes_footstep_sound = false,
        nametag = "Oliver",
        nametag_color = "#FF9933",
    },

    -- State
    _owner = nil,
    _last_speak_time = 0,
    _last_chunk = { x = 0, z = 0 },
    _greeted = false,
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
    local dist = vector.length(dir)

    -- Follow behavior
    if dist > FOLLOW_DISTANCE then
        dir = vector.normalize(dir)
        local vel = vector.multiply(dir, FOLLOW_SPEED)
        vel.y = 0 -- Stay on ground plane
        self.object:set_velocity(vel)
    else
        self.object:set_velocity({ x = 0, y = 0, z = 0 })
    end

    -- Teleport if too far (player flew/teleported)
    if dist > 30 then
        local offset = vector.new(2, 0, 2)
        self.object:set_pos(vector.add(player_pos, offset))
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

minetest.register_on_joinplayer(function(player)
    local pos = player:get_pos()
    local spawn_pos = vector.add(pos, vector.new(2, 0, 2))
    local obj = minetest.add_entity(spawn_pos, MOD_NAME .. ":oliver")
    if obj then
        local ent = obj:get_luaentity()
        ent._owner = player:get_player_name()
    end
end)

-- Clean up Oliver when player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    for _, obj in pairs(minetest.get_connected_players()) do
        -- Remove all Oliver entities owned by this player
    end
    -- Find and remove Oliver entities for this player
    local pos = player:get_pos()
    if pos then
        local objects = minetest.get_objects_inside_radius(pos, 50)
        for _, obj in ipairs(objects) do
            local ent = obj:get_luaentity()
            if ent and ent.name == MOD_NAME .. ":oliver" and ent._owner == name then
                obj:remove()
            end
        end
    end
end)

minetest.log("action", "[zw_oliver] Oliver the Cat loaded")
