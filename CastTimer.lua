-------------------------------------------------------------------------------------
-- Title: CastTimer
-------------------------------------------------------------------------------------

-- Create "namespace."
CastTimer                               = {};

-------------------------------------------------------------------------------------
-- Public constants.
-------------------------------------------------------------------------------------

-- Event types.
CastTimer.EVENTTYPE_DAMAGE              = 1;
CastTimer.EVENTTYPE_HEAL                = 2;
CastTimer.EVENTTYPE_NOTIFICATION        = 3;

-- Direction types.
CastTimer.DIRECTIONTYPE_PLAYER_INCOMING = 1;
CastTimer.DIRECTIONTYPE_PLAYER_OUTGOING = 2;
CastTimer.DIRECTIONTYPE_PET_OUTGOING    = 3;
CastTimer.DIRECTIONTYPE_PET_INCOMING    = 4;

-- Action types.
CastTimer.ACTIONTYPE_HIT                = 1;
CastTimer.ACTIONTYPE_MISS               = 2;
CastTimer.ACTIONTYPE_DODGE              = 3;
CastTimer.ACTIONTYPE_PARRY              = 4;
CastTimer.ACTIONTYPE_BLOCK              = 5;
CastTimer.ACTIONTYPE_RESIST             = 6;
CastTimer.ACTIONTYPE_ABSORB             = 7;
CastTimer.ACTIONTYPE_IMMUNE             = 8;
CastTimer.ACTIONTYPE_EVADE              = 9;
CastTimer.ACTIONTYPE_REFLECT            = 10;
CastTimer.ACTIONTYPE_DROWNING           = 11;
CastTimer.ACTIONTYPE_FALLING            = 12;
CastTimer.ACTIONTYPE_FATIGUE            = 13;
CastTimer.ACTIONTYPE_FIRE               = 14;
CastTimer.ACTIONTYPE_LAVA               = 15;
CastTimer.ACTIONTYPE_SLIME              = 16;


-- Hit types.
CastTimer.HITTYPE_NORMAL                    = 1;
CastTimer.HITTYPE_CRIT                      = 2;
CastTimer.HITTYPE_OVER_TIME                 = 3;

-- Damage types.
CastTimer.DAMAGETYPE_PHYSICAL               = 1;
CastTimer.DAMAGETYPE_HOLY                   = 2;
CastTimer.DAMAGETYPE_NATURE                 = 3;
CastTimer.DAMAGETYPE_FIRE                   = 4;
CastTimer.DAMAGETYPE_FROST                  = 5;
CastTimer.DAMAGETYPE_SHADOW                 = 6;
CastTimer.DAMAGETYPE_ARCANE                 = 7;
CastTimer.DAMAGETYPE_UNKNOWN                = 999;

-- Partial action types.
CastTimer.PARTIALACTIONTYPE_ABSORB          = 1;
CastTimer.PARTIALACTIONTYPE_BLOCK           = 2;
CastTimer.PARTIALACTIONTYPE_RESIST          = 3;
CastTimer.PARTIALACTIONTYPE_VULNERABLE      = 4;
CastTimer.PARTIALACTIONTYPE_CRUSHING        = 5;
CastTimer.PARTIALACTIONTYPE_GLANCING        = 6;
CastTimer.PARTIALACTIONTYPE_OVERHEAL        = 7;

-- Heal types.
CastTimer.HEALTYPE_NORMAL                   = 1;
CastTimer.HEALTYPE_CRIT                     = 2;
CastTimer.HEALTYPE_OVER_TIME                = 3;

-- Notification types.
CastTimer.NOTIFICATIONTYPE_DEBUFF           = 1;
CastTimer.NOTIFICATIONTYPE_BUFF             = 2;
CastTimer.NOTIFICATIONTYPE_ITEM_BUFF        = 3;
CastTimer.NOTIFICATIONTYPE_BUFF_FADE        = 4;
CastTimer.NOTIFICATIONTYPE_COMBAT_ENTER     = 5;
CastTimer.NOTIFICATIONTYPE_COMBAT_LEAVE     = 6;
CastTimer.NOTIFICATIONTYPE_POWER_GAIN       = 7;
CastTimer.NOTIFICATIONTYPE_POWER_LOSS       = 8;
CastTimer.NOTIFICATIONTYPE_CP_GAIN          = 9;
CastTimer.NOTIFICATIONTYPE_HONOR_GAIN       = 10;
CastTimer.NOTIFICATIONTYPE_REP_GAIN         = 11;
CastTimer.NOTIFICATIONTYPE_REP_LOSS         = 12;
CastTimer.NOTIFICATIONTYPE_SKILL_GAIN       = 13;
CastTimer.NOTIFICATIONTYPE_EXPERIENCE_GAIN  = 14;
CastTimer.NOTIFICATIONTYPE_PC_KILLING_BLOW  = 15;
CastTimer.NOTIFICATIONTYPE_NPC_KILLING_BLOW = 16;


-- Trigger types.
CastTimer.TRIGGERTYPE_SELF_HEALTH     = 1;
CastTimer.TRIGGERTYPE_SELF_MANA       = 2;
CastTimer.TRIGGERTYPE_PET_HEALTH      = 3;
CastTimer.TRIGGERTYPE_ENEMY_HEALTH    = 4;
CastTimer.TRIGGERTYPE_FRIENDLY_HEALTH = 5;
CastTimer.TRIGGERTYPE_SEARCH_PATTERN  = 6;


-------------------------------------------------------------------------------------
-- Private constants.
-------------------------------------------------------------------------------------

-- Amount of time to delay between selected player list updates and how long
-- to hold a recently selected player in cache.
local RECENTLY_SELECTED_PLAYERS_UPDATE_INTERVAL = 1;
local RECENTLY_SELECTED_PLAYERS_HOLD_TIME = 45;

-------------------------------------------------------------------------------------
-- Public variables.
-------------------------------------------------------------------------------------

-- Hold combat event data.
CastTimer.CombatEventData = {};

-- Hold trigger event data.
CastTimer.TriggerEventData = {};


-------------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------------

-- Holds the events the helper is interested in receiving.
local listenEvents = {};

-- Holds a list of recently selected hostile players.
local recentlySelectedPlayers = {};
local elapsedTime = 0;

-- Used for debugging cast times
local firstCastTime = 0;
local totalCasts = 0;
local duration = 0;
local castStartTime = 0;
local averageClientCastTime = 0;
local numCastsInClientAverage = 0;

-------------------------------------------------------------------------------------
-- Core event handlers.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Registers all of the events the helper is interested in.
-- **********************************************************************************
function CastTimer.RegisterEvents()
    -- Register the events we are interested in receiving.
    for k, v in listenEvents do
        CastTimerEventFrame:RegisterEvent(v);
    end
end

-- **********************************************************************************
-- Called when the helper's event frame is loaded.
-- **********************************************************************************
function CastTimer.OnLoad()
    table.insert(listenEvents, "SPELLCAST_START");            -- Start casting
    table.insert(listenEvents, "SPELLCAST_STOP");             -- Stop  casting
    table.insert(listenEvents, "SPELLCAST_FAILED");           -- Failed  casting
    table.insert(listenEvents, "SPELLCAST_INTERRUPTED");      -- Failed  casting
    table.insert(listenEvents, "CHAT_MSG_SPELL_SELF_DAMAGE"); -- Failed  casting

    -- Register for the ADDON_LOADED event.
    CastTimerEventFrame:RegisterEvent("ADDON_LOADED");
end

function clearStats()
    if (firstCastTime > 0) then
        local avg = duration / totalCasts
        CastTimer.Print(
            "[CastTimer]  Total casts since end of 1st cast: " ..
            totalCasts ..
            " Total duration: " .. string.format("%.3f", duration) .. " Average: " .. string.format("%.3f", avg), 1, 1,
            1)
    end

    CastTimer.Print("Clearing stats")
    castStartTime = 0;
    averageClientCastTime = 0;
    numCastsInClientAverage = 0;
    firstCastTime = 0;
    totalCasts = 0;
end

-------------------------------------------------------------------------------------
-- Printing functions.
-------------------------------------------------------------------------------------

-- **********************************************************************************
-- Prints out the passed message to the default chat frame.
-- **********************************************************************************
function CastTimer.Print(msg, r, g, b)
    -- Add the message to the default chat frame.
    DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
end

-- **********************************************************************************
-- Called when the events the helper registered for occur.
-- **********************************************************************************
function CastTimer.OnEvent()
    -- When an addon is loaded.
    if (event == "ADDON_LOADED") then
        -- Make sure it's the right addon.
        if (arg1 == "CastTimer") then
            -- Don't get notification for other addons being loaded.
            this:UnregisterEvent("ADDON_LOADED");

            -- Register for the events the helper is interested in receiving.
            CastTimer.RegisterEvents();

            -- Initialize the helper object.
            CastTimer.Init();
        end
    elseif (event == "CHAT_MSG_SPELL_SELF_DAMAGE") then
        local currentTime = GetTime(); -- get current time
        -- if more than 10 seconds have passed since last cast, reset average cast time
        if (currentTime - castStartTime > 10) then
            clearStats()
            firstCastTime = currentTime
        end

        if (castStartTime > 0) then
            totalCasts = totalCasts + 1
            duration = currentTime - firstCastTime
            local castTime = currentTime - castStartTime;          -- calculate client cast time
            averageClientCastTime = (averageClientCastTime * numCastsInClientAverage + castTime) /
                (numCastsInClientAverage + 1);                     -- calculate average cast time
            numCastsInClientAverage = numCastsInClientAverage + 1; -- increment number of casts in average
            CastTimer.Print(
            "Client cast time: " ..
            string.format("%.3f", castTime) .. " Average: " .. string.format("%.3f", averageClientCastTime), 1, 1, 1)
        end
        castStartTime = currentTime; -- track start time
    elseif (event == "SPELLCAST_INTERRUPTED") then
        clearStats()
        CastTimer.Print("Cast interrupted", 1, 1, 1)
    end
end

-- **********************************************************************************
-- This function parses the chat message combat events.
-- **********************************************************************************
function CastTimer.OnUpdate()
    -- Increment the amount of time passed since the last update.
    elapsedTime = elapsedTime + arg1;

    -- Check if it's time for an update.
    if (elapsedTime >= RECENTLY_SELECTED_PLAYERS_UPDATE_INTERVAL) then
        -- Loop through all of the recently selected players.
        for playerName, lastSeen in recentlySelectedPlayers do
            -- Increment the amount of time since the player was last seen.
            recentlySelectedPlayers[playerName] = lastSeen + elapsedTime;

            -- Check if enough time has passed and remove the player from the list.
            if (lastSeen + elapsedTime >= RECENTLY_SELECTED_PLAYERS_HOLD_TIME) then
                recentlySelectedPlayers[playerName] = nil;
            end
        end

        -- Reset the elapsed time.
        elapsedTime = 0;
    end
end

-- **********************************************************************************
-- Called when the helper is fully loaded.
-- **********************************************************************************
function CastTimer.Init()
    -- Get the name of the player and the player's class.
    playerName = UnitName("player");
    _, playerClass = UnitClass("player");
end
