-- GameState.lua - Manages the game state

local GameState = {}
GameState.__index = GameState

-- Game states
local STATES = {
    MENU = "menu",
    PLAYING = "playing",
    PAUSED = "paused",
    LEVEL_COMPLETE = "level_complete",
    GAME_OVER = "game_over"
}

-- Create a new game state
function GameState.new()
    local self = setmetatable({}, GameState)
    
    -- Current state
    self.state = STATES.PLAYING  -- Start directly in playing state
    
    -- Level information
    self.currentLevel = 2  -- Start with level 2 for material debugging
    self.maxLevel = 5  -- Adjust based on number of levels
    self.shots = 0
    self.par = 3  -- Default par score
    
    -- Transition effects
    self.transitioning = false
    self.transitionTime = 0
    self.transitionDuration = 1.0  -- 1 second transition
    self.transitionCallback = nil
    
    
    -- Settings
    self.settings = {
        soundVolume = 0.7,
        musicVolume = 0.5,
        fullscreen = false,
        showTutorial = true
    }
    
    return self
end

-- Update game state
function GameState:update(dt)
    -- Update transition effect
    if self.transitioning then
        self.transitionTime = self.transitionTime + dt
        
        if self.transitionTime >= self.transitionDuration then
            self.transitioning = false
            
            -- Call transition callback if set
            if self.transitionCallback then
                self.transitionCallback()
                self.transitionCallback = nil
            end
        end
    end
end

-- Start a level transition
function GameState:startLevelTransition()
    if self.transitioning then return end
    
    self.transitioning = true
    self.transitionTime = 0
    
    -- Set callback to load next level
    self.transitionCallback = function()
        self:nextLevel()
    end
end

-- Set the current state
function GameState:setState(state)
    -- Convert to uppercase for consistency
    local upperState = string.upper(state)
    
    -- Check if it's a valid state
    if STATES[upperState] then
        self.state = STATES[upperState]
    else
        -- Try direct assignment if it matches a value
        for _, value in pairs(STATES) do
            if value == state then
                self.state = state
                return
            end
        end
        
    end
end

-- Get the current state
function GameState:getState()
    return self.state
end

-- Check if a specific state is active
function GameState:isState(state)
    return self.state == STATES[state]
end

-- Set the current level
function GameState:setCurrentLevel(level)
    self.currentLevel = level
    self.shots = 0
    
    -- Set par score based on level
    if level == 1 then
        self.par = 3
    elseif level == 2 then
        self.par = 4
    elseif level == 3 then
        self.par = 5
    elseif level == 4 then
        self.par = 6
    else
        self.par = 5
    end
end

-- Get the current level
function GameState:getCurrentLevel()
    return self.currentLevel
end

-- Move to the next level
function GameState:nextLevel()
    self.currentLevel = self.currentLevel + 1
    
    -- Check if we've completed all levels
    if self.currentLevel > self.maxLevel then
        self:setState(STATES.GAME_OVER)
        self.currentLevel = 1  -- Reset to first level
    else
        self:setCurrentLevel(self.currentLevel)
        self:setState(STATES.PLAYING)
    end
end

-- Record a shot
function GameState:recordShot()
    self.shots = self.shots + 1
end

-- Get the current shot count
function GameState:getShots()
    return self.shots
end

-- Get the par score for the current level
function GameState:getPar()
    return self.par
end


-- Check if a transition is in progress
function GameState:isTransitioning()
    return self.transitioning
end

-- Get transition progress (0-1)
function GameState:getTransitionProgress()
    if not self.transitioning then return 0 end
    return self.transitionTime / self.transitionDuration
end

-- Update a setting
function GameState:updateSetting(key, value)
    if self.settings[key] ~= nil then
        self.settings[key] = value
    end
end

-- Get a setting value
function GameState:getSetting(key)
    return self.settings[key]
end

-- Save game state to a file
function GameState:saveGame()
    local data = {
        currentLevel = self.currentLevel,
        settings = self.settings
    }
    
    local success, message = love.filesystem.write("savegame.dat", love.data.encode("string", "json", data))
    return success, message
end

-- Load game state from a file
function GameState:loadGame()
    if not love.filesystem.getInfo("savegame.dat") then
        return false, "No save file found"
    end
    
    local contents, size = love.filesystem.read("savegame.dat")
    if not contents then
        return false, "Could not read save file"
    end
    
    local success, data = pcall(function()
        return love.data.decode("string", "json", contents)
    end)
    
    if not success or not data then
        return false, "Invalid save file format"
    end
    
    -- Load data
    if data.currentLevel then
        self:setCurrentLevel(data.currentLevel)
    end
    
    if data.settings then
        for k, v in pairs(data.settings) do
            self.settings[k] = v
        end
    end
    
    return true
end

return GameState
