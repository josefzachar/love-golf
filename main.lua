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
local CELL_SIZE = 8  -- Size of each cell in pixels
local WORLD_WIDTH = 200  -- Width in cells
local WORLD_HEIGHT = 150  -- Height in cells
local GRAVITY = 0.2  -- Gravity strength
local SIMULATION_SPEED = 0.5  -- Simulation speed multiplier (lower = slower)

-- Performance settings
local USE_VSYNC = false  -- Disable VSync for higher FPS
local LIMIT_FPS = false  -- Whether to limit FPS
local MAX_FPS = 120      -- Maximum FPS if limited
local lastTime = 0       -- For FPS limiting

-- Initialize the game
function love.load()
    -- Set default filter mode for crisp pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Disable VSync for higher performance
    love.window.setVSync(USE_VSYNC and 1 or 0)
    
    -- Seed the random number generator
    math.randomseed(os.time())
    
    -- Initialize modules in the correct order
    -- Disabled shader for better visibility of the helper grid
    cellShader = nil
    
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
    
    -- Calculate and set an appropriate camera scale to make the level fill more of the screen
    -- For level 2, the container is roughly 80x55 cells
    local levelWidth = 80 * CELL_SIZE
    local levelHeight = 55 * CELL_SIZE
    local scaleX = windowWidth / levelWidth
    local scaleY = windowHeight / levelHeight
    local scale = math.min(scaleX, scaleY) * 0.8  -- Use 80% of the calculated scale for some margin
    camera:setZoom(scale)
    
    -- Load level 2 for material debugging
    loadLevel(2)
    
end

-- Update game state
function love.update(dt)
    -- FPS limiting if enabled
    if LIMIT_FPS then
        local currentTime = love.timer.getTime()
        local targetDelta = 1 / MAX_FPS
        
        if currentTime - lastTime < targetDelta then
            -- Skip update to limit FPS
            return
        end
        
        lastTime = currentTime
    end
    
    -- Cap delta time to prevent physics issues on lag spikes
    local cappedDt = math.min(dt, 1/30)
    
    -- Apply simulation speed to cell world update
    local simulationDt = cappedDt * SIMULATION_SPEED
    
    -- Update modules in order of importance
    inputHandler:update(cappedDt)
    cellWorld:update(simulationDt, GRAVITY)  -- Slow down cell simulation
    ballManager:update(cappedDt)
    camera:update(cappedDt, ballManager:getCurrentBall())
    
    -- Initialize frame counter if it doesn't exist
    if not _G.frameCount then
        _G.frameCount = 0
    end
    
    -- Update less critical components less frequently when FPS is low
    local currentFPS = love.timer.getFPS()
    if currentFPS < 45 then
        -- Only update UI and game state every other frame when FPS is low
        if _G.frameCount % 2 == 0 then
            gameState:update(cappedDt * 2)  -- Compensate for less frequent updates
            ui:update(cappedDt * 2)         -- Compensate for less frequent updates
        end
    else
        -- Normal updates when FPS is good
        gameState:update(cappedDt)
        ui:update(cappedDt)
    end
    
    -- Check win condition
    if ballManager:isInHole() and not gameState:isTransitioning() then
        gameState:startLevelTransition()
    end
    
    -- Increment frame counter
    _G.frameCount = _G.frameCount + 1
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
    
    -- Always display FPS counter and performance info
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Always display active cell count and other info
    love.graphics.print("Cells: " .. cellWorld:getActiveCellCount(), 10, 30)
    love.graphics.print("Ball Type: " .. ballManager:getCurrentBallType(), 10, 50)
    love.graphics.print("Sim Speed: " .. SIMULATION_SPEED, 10, 70)
    love.graphics.print("VSync: " .. (USE_VSYNC and "ON" or "OFF"), 10, 90)
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

-- Add a direct mouse movement handler
function love.mousemoved(x, y, dx, dy, istouch)
    
    -- Directly handle camera movement if a button is held down
    if inputHandler.cameraControl and inputHandler.cameraControl.active then
        
        -- Update mouse position
        inputHandler.mouseX = x
        inputHandler.mouseY = y
        
        -- Calculate world movement
        local scale = inputHandler.camera.scale or 1
        local worldDx = dx / scale
        local worldDy = dy / scale
        
        -- Move camera in opposite direction of drag
        if inputHandler.camera.x ~= nil and inputHandler.camera.y ~= nil then
            -- Directly update camera position for immediate response
            inputHandler.camera.x = inputHandler.camera.x - worldDx
            inputHandler.camera.y = inputHandler.camera.y - worldDy
            
            -- Also update target position to match
            inputHandler.camera.targetX = inputHandler.camera.x
            inputHandler.camera.targetY = inputHandler.camera.y
            
        end
    end
end

function love.keypressed(key)
    -- First pass the key to the input handler
    inputHandler:keypressed(key)
    
    -- Level reload
    if key == "r" then
        -- Reload level when R is pressed
        loadLevel(gameState:getCurrentLevel())
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
    elseif key == "pagedown" then
        -- Decrease simulation speed
        SIMULATION_SPEED = math.max(SIMULATION_SPEED - 0.1, 0.1)
    -- Performance controls
    elseif key == "v" then
        -- Toggle VSync
        USE_VSYNC = not USE_VSYNC
        love.window.setVSync(USE_VSYNC and 1 or 0)
    elseif key == "f" then
        -- Toggle FPS limiting
        LIMIT_FPS = not LIMIT_FPS
        lastTime = love.timer.getTime()
    -- Camera reset
    elseif key == "c" then
        -- Reset camera position and scale
        local windowWidth, windowHeight = love.graphics.getDimensions()
        
        -- For level 2, reset to center of the container
        if gameState:getCurrentLevel() == 2 then
            camera:setPosition(50, 40)
            
            -- Calculate and set an appropriate camera scale
            local levelWidth = 80 * CELL_SIZE  -- Level 2 container is roughly 80 cells wide
            local levelHeight = 55 * CELL_SIZE  -- Level 2 container is roughly 55 cells high
            local scaleX = windowWidth / levelWidth
            local scaleY = windowHeight / levelHeight
            local scale = math.min(scaleX, scaleY) * 0.8  -- Use 80% of the calculated scale for some margin
            camera:setZoom(scale)
        else
            -- For other levels, reset to the ball position
            local ball = ballManager:getCurrentBall()
            if ball then
                camera:setPosition(ball.x, ball.y)
            end
            camera:setZoom(2.0)  -- Default scale for other levels
        end
        
        -- Re-enable camera follow if it was disabled
        camera:enableFollowTarget()
    end
end

-- Create an empty canvas
function createEmptyCanvas()
    gameState:setCurrentLevel(0)  -- Special level number for empty canvas
    cellWorld:clear()
    
    -- Create a container with walls in the same position as level 2
    for x = 10, 90 do
        -- Subtle stone color variations (shades of gray)
        local stoneBase = 0.5  -- Base brightness
        local variation = 0.15  -- Subtle variation
        local shade1 = stoneBase - variation/2 + math.random() * variation
        local shade2 = stoneBase - variation/2 + math.random() * variation
        
        local stoneColor1 = {
            shade1,  -- Red
            shade1,  -- Green
            shade1,  -- Blue
            1
        }
        
        local stoneColor2 = {
            shade2,  -- Red
            shade2,  -- Green
            shade2,  -- Blue
            1
        }
        
        -- Top and bottom walls
        cellWorld:setCell(x, 10, 10, stoneColor1)  -- Stone (top)
        cellWorld:setCell(x, 65, 10, stoneColor2)  -- Stone (bottom)
    end
    
    for y = 10, 65 do
        -- Subtle stone color variations (shades of gray)
        local stoneBase = 0.5  -- Base brightness
        local variation = 0.15  -- Subtle variation
        local shade1 = stoneBase - variation/2 + math.random() * variation
        local shade2 = stoneBase - variation/2 + math.random() * variation
        
        local stoneColor1 = {
            shade1,  -- Red
            shade1,  -- Green
            shade1,  -- Blue
            1
        }
        
        local stoneColor2 = {
            shade2,  -- Red
            shade2,  -- Green
            shade2,  -- Blue
            1
        }
        
        -- Left and right walls
        cellWorld:setCell(10, y, 10, stoneColor1)  -- Stone (left)
        cellWorld:setCell(90, y, 10, stoneColor2)  -- Stone (right)
    end
    
    -- Set up a ball in the center of the container
    local startPosition = {x = 50, y = 40}
    ballManager:reset(startPosition, 1)  -- Standard ball
    
    -- Focus camera on the center of the visible area (same as level 2)
    camera:focusOn(50, 40)
    
    -- Set appropriate camera scale for the empty canvas (using the same dimensions as level 2)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local levelWidth = 80 * CELL_SIZE  -- Match level 2 container width
    local levelHeight = 55 * CELL_SIZE  -- Match level 2 container height
    local scaleX = windowWidth / levelWidth
    local scaleY = windowHeight / levelHeight
    local scale = math.min(scaleX, scaleY) * 0.8  -- Use 80% of the calculated scale for some margin
    camera:setZoom(scale)
end

-- Generate a random level with terrain
function generateRandomLevel()
    gameState:setCurrentLevel(99)  -- Special level number for generated level
    cellWorld:clear()
    
    local CellTypes = require("src.cells.CellTypes")
    
    -- Create a container with walls in the same position as level 2
    for x = 10, 90 do
        -- Subtle stone color variations (shades of gray)
        local stoneBase = 0.5  -- Base brightness
        local variation = 0.15  -- Subtle variation
        local shade1 = stoneBase - variation/2 + math.random() * variation
        local shade2 = stoneBase - variation/2 + math.random() * variation
        
        local stoneColor1 = {
            shade1,  -- Red
            shade1,  -- Green
            shade1,  -- Blue
            1
        }
        
        local stoneColor2 = {
            shade2,  -- Red
            shade2,  -- Green
            shade2,  -- Blue
            1
        }
        
        -- Top and bottom walls
        cellWorld:setCell(x, 10, CellTypes.STONE, stoneColor1)
        cellWorld:setCell(x, 65, CellTypes.STONE, stoneColor2)
    end
    
    for y = 10, 65 do
        -- Subtle stone color variations (shades of gray)
        local stoneBase = 0.5  -- Base brightness
        local variation = 0.15  -- Subtle variation
        local shade1 = stoneBase - variation/2 + math.random() * variation
        local shade2 = stoneBase - variation/2 + math.random() * variation
        
        local stoneColor1 = {
            shade1,  -- Red
            shade1,  -- Green
            shade1,  -- Blue
            1
        }
        
        local stoneColor2 = {
            shade2,  -- Red
            shade2,  -- Green
            shade2,  -- Blue
            1
        }
        
        -- Left and right walls
        cellWorld:setCell(10, y, CellTypes.STONE, stoneColor1)
        cellWorld:setCell(90, y, CellTypes.STONE, stoneColor2)
    end
    
    -- Generate terrain
    -- Ground layer
    local groundHeight = 55  -- Lower than before to fit in the container
    for x = 11, 89 do
        -- Vary the ground height to create hills and valleys
        local heightVariation = math.floor(math.sin(x / 10) * 5)
        local currentGroundHeight = groundHeight + heightVariation
        
        -- Create dirt with grass on top
        for y = currentGroundHeight, 64 do
            -- Subtle dirt color variations (shades of brown)
            local dirtBase = 0.6  -- Base brightness
            local variation = 0.15  -- Subtle variation
            local shade = dirtBase - variation/2 + math.random() * variation
            local dirtColor = {
                shade,        -- Red (base)
                shade - 0.3,  -- Green (less)
                shade - 0.5,  -- Blue (much less)
                1
            }
            
            -- Grass color with subtle variations
            local grassBase = 0.3  -- Base green brightness
            local grassVariation = 0.1  -- Subtle variation
            local grassShade = grassBase - grassVariation/2 + math.random() * grassVariation
            local grassColor = {
                0.2 + math.random() * 0.1,  -- Red (low)
                grassShade + 0.4,           -- Green (high)
                0.1 + math.random() * 0.1,  -- Blue (low)
                1
            }
            
            if y == currentGroundHeight then
                -- Top layer is grass
                cellWorld:setCell(x, y, CellTypes.GRASS, grassColor)
            else
                -- Lower layers are dirt
                cellWorld:setCell(x, y, CellTypes.DIRT, dirtColor)
            end
        end
    end
    
    -- Add some random stone formations
    for i = 1, 5 do
        local centerX = math.random(20, 80)
        local centerY = math.random(groundHeight - 10, groundHeight - 5)
        local radius = math.random(3, 8)
        
        for y = centerY - radius, centerY + radius do
            for x = centerX - radius, centerX + radius do
                local dx = x - centerX
                local dy = y - centerY
                if dx*dx + dy*dy <= radius*radius and 
                   x > 10 and x < 90 and y > 10 and y < 65 then
                    -- Subtle stone color variations (shades of gray)
                    local stoneBase = 0.5  -- Base brightness
                    local variation = 0.2  -- Subtle variation
                    local shade = stoneBase - variation/2 + math.random() * variation
                    local stoneColor = {
                        shade,  -- Red
                        shade,  -- Green
                        shade,  -- Blue
                        1
                    }
                    
                    cellWorld:setCell(x, y, CellTypes.STONE, stoneColor)
                end
            end
        end
    end
    
    -- Add some water pools
    for i = 1, 3 do
        local poolWidth = math.random(10, 20)
        local poolX = math.random(15, 85 - poolWidth)
        local poolDepth = math.random(3, 6)
        local poolY = groundHeight - poolDepth
        
        -- Dig out the pool
        for y = poolY, groundHeight do
            for x = poolX, poolX + poolWidth do
                if cellWorld:getCell(x, y) ~= CellTypes.STONE then
                    cellWorld:setCell(x, y, CellTypes.EMPTY)
                end
            end
        end
        
        -- Fill with water
        for y = poolY, groundHeight do
            for x = poolX, poolX + poolWidth do
                if cellWorld:getCell(x, y) == CellTypes.EMPTY then
                    -- Subtle water color variations (shades of blue)
                    local waterBase = 0.7  -- Base brightness
                    local variation = 0.2  -- Subtle variation
                    local shade = waterBase - variation/2 + math.random() * variation
                    local waterColor = {
                        0.0,          -- Red (none)
                        shade - 0.3,  -- Green (some)
                        shade,        -- Blue (base)
                        0.8 + math.random() * 0.2  -- Alpha (slight variation)
                    }
                    
                    cellWorld:setCell(x, y, CellTypes.WATER, waterColor)
                end
            end
        end
    end
    
    -- Add some sand piles
    for i = 1, 4 do
        local pileX = math.random(15, 85)
        local pileY = groundHeight - math.random(1, 3)
        local pileSize = math.random(5, 10)
        
        for j = 1, 50 do
            local x = pileX + math.random(-pileSize, pileSize)
            local y = pileY + math.random(-pileSize/2, pileSize/2)
            
            if x > 10 and x < 90 and y > 10 and y < 65 and
               cellWorld:getCell(x, y) == CellTypes.EMPTY then
                -- Subtle sand color variations (shades of tan)
                local sandBase = 0.85  -- Base brightness
                local variation = 0.15  -- Subtle variation
                local shade = sandBase - variation/2 + math.random() * variation
                local sandColor = {
                    shade + 0.1,  -- Red (slightly more)
                    shade,        -- Green (base)
                    shade - 0.4,  -- Blue (much less)
                    1
                }
                
                cellWorld:setCell(x, y, CellTypes.SAND, sandColor)
            end
        end
    end
    
    -- Set up a ball at a good starting position
    local startX = math.random(20, 80)
    local startY = 20  -- Start high up but within the container
    local startPosition = {x = startX, y = startY}
    ballManager:reset(startPosition, 1)  -- Standard ball
    
    -- Focus camera on the center of the visible area (same as level 2)
    camera:focusOn(50, 40)
    
    -- Set appropriate camera scale for the random level (using the same dimensions as level 2)
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local levelWidth = 80 * CELL_SIZE  -- Match level 2 container width
    local levelHeight = 55 * CELL_SIZE  -- Match level 2 container height
    local scaleX = windowWidth / levelWidth
    local scaleY = windowHeight / levelHeight
    local scale = math.min(scaleX, scaleY) * 0.8  -- Use 80% of the calculated scale for some margin
    camera:setZoom(scale)
end

-- Load a specific level
function loadLevel(levelNum)
    gameState:setCurrentLevel(levelNum)
    cellWorld:clear()
    
    -- Load level data
    local levelData = require("src.levels.level" .. levelNum)
    
    
    cellWorld:loadFromData(levelData.cells)
    
    ballManager:reset(levelData.startPosition, levelData.ballType)
    
    -- For level 2 (debug level), focus on the center of the container
    if levelNum == 2 then
        camera:focusOn(50, 40)
        
        -- Calculate and set an appropriate camera scale for level 2
        local windowWidth, windowHeight = love.graphics.getDimensions()
        local levelWidth = 80 * CELL_SIZE  -- Level 2 container is roughly 80 cells wide
        local levelHeight = 55 * CELL_SIZE  -- Level 2 container is roughly 55 cells high
        local scaleX = windowWidth / levelWidth
        local scaleY = windowHeight / levelHeight
        local scale = math.min(scaleX, scaleY) * 0.8  -- Use 80% of the calculated scale for some margin
        camera:setZoom(scale)
    else
        camera:focusOn(levelData.startPosition.x, levelData.startPosition.y)
        
        -- For other levels, set a reasonable default scale
        -- This can be adjusted based on the specific level's size
        camera:setZoom(2.0)  -- A larger scale value makes the view more zoomed in
    end
end
