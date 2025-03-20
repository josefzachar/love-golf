-- Main entry point for Cellular Golf game

-- Import modules
local CellWorld = require("src.cells.CellWorld")
local GameState = require("src.GameState")
local BallManager = require("src.balls.BallManager")
local InputHandler = require("src.InputHandler")
local Camera = require("src.Camera")
local UI = require("src.UI")

-- Global variables
_G.cellWorld = nil  -- Make cellWorld globally accessible
_G.inputHandler = nil  -- Make inputHandler globally accessible
local gameState
local ballManager
local inputHandler
local camera
local ui

-- Shaders
local cellShader

-- Constants
local CELL_SIZE = 8  -- Size of each cell in pixels (4x larger)
local WORLD_WIDTH = 100  -- Width in cells (adjusted for larger cell size)
local WORLD_HEIGHT = 75  -- Height in cells (adjusted for larger cell size)
local GRAVITY = 0.2  -- Gravity strength
local SIMULATION_SPEED = 0.5  -- Simulation speed multiplier (lower = slower)

-- Initialize the game
function love.load()
    -- Set default filter mode for crisp pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Seed the random number generator
    math.randomseed(os.time())
    
    -- Initialize modules in the correct order
    cellShader = love.graphics.newShader("src/shaders/cell.glsl")
    
    cellWorld = CellWorld.new(WORLD_WIDTH, WORLD_HEIGHT, CELL_SIZE, cellShader)
    _G.cellWorld = cellWorld  -- Set the global reference
    gameState = GameState.new()
    camera = Camera.new()  -- Initialize camera before ballManager and inputHandler
    ballManager = BallManager.new(cellWorld)
    inputHandler = InputHandler.new(ballManager, camera)
    _G.inputHandler = inputHandler  -- Set the global reference
    ui = UI.new(gameState, ballManager)
    
    -- Set initial camera position to center of the level
    camera:setPosition(50, 40)  -- Center of our container in level2
    
    -- Center the camera view in the window
    local windowWidth, windowHeight = love.graphics.getDimensions()
    camera:setOffset(windowWidth / 2, windowHeight / 2)
    
    -- Load level 2 for material debugging
    loadLevel(2)
    
    -- Debug: Print some info
    print("Game initialized")
    print("World dimensions:", WORLD_WIDTH, "x", WORLD_HEIGHT)
    print("Cell size:", CELL_SIZE)
end

-- Update game state
function love.update(dt)
    -- Cap delta time to prevent physics issues on lag spikes
    local cappedDt = math.min(dt, 1/30)
    
    -- Apply simulation speed to cell world update
    local simulationDt = cappedDt * SIMULATION_SPEED
    
    -- Update modules
    inputHandler:update(cappedDt)
    cellWorld:update(simulationDt, GRAVITY)  -- Slow down cell simulation
    ballManager:update(cappedDt)
    camera:update(cappedDt, ballManager:getCurrentBall())
    gameState:update(cappedDt)
    ui:update(cappedDt)
    
    -- Check win condition
    if ballManager:isInHole() and not gameState:isTransitioning() then
        gameState:startLevelTransition()
    end
end

-- Draw the game
function love.draw()
    -- Start camera transformation
    camera:set()
    
    -- Draw the cell world (using GPU-accelerated shader)
    cellWorld:draw()
    
    -- Draw game objects
    ballManager:draw()
    
    -- End camera transformation
    camera:unset()
    
    -- Draw UI (not affected by camera)
    ui:draw()
    
    -- Draw input handler elements (cursor and material indicator)
    inputHandler:draw()
    
    -- Always display FPS counter
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Additional debug info
    if gameState:isDebugMode() then
        love.graphics.print("Cells: " .. cellWorld:getActiveCellCount(), 10, 30)
        love.graphics.print("Ball Type: " .. ballManager:getCurrentBallType(), 10, 50)
        love.graphics.print("Sim Speed: " .. SIMULATION_SPEED, 10, 70)
    end
end

-- Input callbacks
function love.mousepressed(x, y, button)
    -- First check if UI handled the click
    if ui:mousepressed(x, y, button) then
        return -- UI handled the click
    end
    
    -- Otherwise pass to input handler
    inputHandler:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    inputHandler:mousereleased(x, y, button)
end

function love.keypressed(key)
    -- First pass the key to the input handler
    inputHandler:keypressed(key)
    
    -- Quick debug toggles
    if key == "f3" then
        gameState:toggleDebugMode()
    elseif key == "r" then
        -- Reload level when R is pressed
        loadLevel(gameState:getCurrentLevel())
        print("Level reloaded manually")
    elseif key == "escape" then
        if gameState:getState() == "playing" then
            gameState:setState("PAUSED")
        elseif gameState:getState() == "paused" then
            gameState:setState("PLAYING")
        else
            love.event.quit()
        end
    -- Simulation speed controls
    elseif key == "pageup" then
        -- Increase simulation speed
        SIMULATION_SPEED = math.min(SIMULATION_SPEED + 0.1, 2.0)
        print("Simulation speed: " .. SIMULATION_SPEED)
    elseif key == "pagedown" then
        -- Decrease simulation speed
        SIMULATION_SPEED = math.max(SIMULATION_SPEED - 0.1, 0.1)
        print("Simulation speed: " .. SIMULATION_SPEED)
    end
end

-- Load a specific level
function loadLevel(levelNum)
    print("Loading level", levelNum)
    gameState:setCurrentLevel(levelNum)
    cellWorld:clear()
    
    -- Load level data
    local levelData = require("src.levels.level" .. levelNum)
    print("Level data loaded, cell count:", #levelData.cells)
    
    -- Debug: Print some cells
    for i = 1, math.min(5, #levelData.cells) do
        local cell = levelData.cells[i]
        print("Sample cell", i, ":", cell.x, cell.y, cell.type)
    end
    
    cellWorld:loadFromData(levelData.cells)
    print("Cells loaded into world")
    
    ballManager:reset(levelData.startPosition, levelData.ballType)
    print("Ball reset at", levelData.startPosition.x, levelData.startPosition.y)
    
    -- For level 2 (debug level), focus on the center of the container
    if levelNum == 2 then
        camera:focusOn(50, 40)
        print("Camera focused on level center")
    else
        camera:focusOn(levelData.startPosition.x, levelData.startPosition.y)
        print("Camera focused on ball")
    end
end
