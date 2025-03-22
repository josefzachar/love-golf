-- CellBall.lua - A specialized ball that interacts with the cellular automaton
-- Inspired by the Godot implementation from https://github.com/josefzachar/golf-game/

local CellTypes = require("src.cells.CellTypes")

local CellBall = {}
CellBall.__index = CellBall

-- Create a new cell ball
function CellBall.new(ballManager)
    local self = setmetatable({}, CellBall)
    
    -- Reference to the ball manager
    self.ballManager = ballManager
    
    -- Grid tracking
    self.currentGridPos = {x = -1, y = -1}  -- Track current grid position for efficient updates
    
    -- Aiming state
    self.isAiming = false
    self.aimStartX = 0
    self.aimStartY = 0
    self.aimCurrentX = 0
    self.aimCurrentY = 0
    
    -- Shot properties
    self.maxPower = 200
    self.shotPower = 0
    self.shotAngle = 0
    
    -- Rotation properties
    self.rotation = 0
    self.rotationSpeed = 0
    self.lastPosition = {x = 0, y = 0}  -- Track last position for rotation calculation
    
    -- Visual properties - white color like in the Godot version
    self.color = {1, 1, 1, 1}  -- White cell ball
    
    -- Cell interaction properties
    self.cellInteractionRadius = 2  -- Radius for cell interaction
    self.cellInteractionTimer = 0   -- Timer for cell interaction effects
    self.cellInteractionRate = 0.1  -- How often to interact with cells (in seconds)
    
    -- Special ability properties
    self.abilityActive = false
    self.abilityDuration = 0
    self.abilityMaxDuration = 3.0  -- 3 seconds of ability duration
    
    return self
end

-- Start aiming the cell ball
function CellBall:startAim(x, y)
    -- Can only start aiming if the ball is not already aiming
    if self.isAiming then return false end
    
    -- Store the starting position of the aim (ball's screen position)
    self.aimStartX = x
    self.aimStartY = y
    self.aimCurrentX = x
    self.aimCurrentY = y
    
    -- Set aiming state
    self.isAiming = true
    
    -- Store current position for rotation calculation
    self.lastPosition.x = self.ballManager.position.x
    self.lastPosition.y = self.ballManager.position.y
    
    return true
end

-- Update the aim with current mouse position
function CellBall:updateAim(x, y)
    if not self.isAiming then return end
    
    -- Update current aim position
    self.aimCurrentX = x
    self.aimCurrentY = y
    
    -- Calculate shot parameters
    local cellSize = self.ballManager.cellWorld.cellSize
    local ballScreenX = self.ballManager.position.x * cellSize
    local ballScreenY = self.ballManager.position.y * cellSize
    
    -- Calculate angle based on current mouse position relative to ball
    local dx = x - ballScreenX
    local dy = y - ballScreenY
    
    -- Direction from ball to current mouse position
    self.shotAngle = math.atan2(dy, dx)
    
    -- Calculate power based on distance from ball to current mouse position
    local distanceFromBall = math.sqrt(dx*dx + dy*dy)
    
    -- Power increases as you move further from the ball
    self.shotPower = math.min(distanceFromBall / 2, self.maxPower)
end

-- Execute the cell ball shot
function CellBall:shoot()
    if not self.isAiming then return false end
    
    -- Apply velocity in the opposite direction of the aim line
    self.ballManager.velocity.x = -math.cos(self.shotAngle) * self.shotPower * 180
    self.ballManager.velocity.y = -math.sin(self.shotAngle) * self.shotPower * 180
    
    -- Set rotation speed based on horizontal velocity
    self.rotationSpeed = -self.ballManager.velocity.x * 0.1
    
    -- Reset aiming state
    self.isAiming = false
    
    return true
end

-- Cancel the current aim
function CellBall:cancelAim()
    self.isAiming = false
    return true
end

-- Check if aiming is active
function CellBall:isAimActive()
    return self.isAiming
end

-- Activate the special ability - create/manipulate cells around the ball
function CellBall:activateAbility()
    if self.abilityActive then return false end
    
    self.abilityActive = true
    self.abilityDuration = self.abilityMaxDuration
    
    return true
end

-- Update the cell ball
function CellBall:update(dt)
    -- Update rotation based on movement
    if not self.isAiming then
        -- Calculate movement since last frame
        local movement = {
            x = self.ballManager.position.x - self.lastPosition.x,
            y = self.ballManager.position.y - self.lastPosition.y
        }
        
        -- Update rotation based on horizontal movement
        local rollFactor = 8.0  -- Controls how fast the ball rotates
        
        -- Simplified calculation for rotation
        local rotationAmount = movement.x * rollFactor / (self.ballManager.radius * 8.0)
        
        -- Check if the ball is on the ground
        local isOnGround = false
        local checkY = self.ballManager.position.y + self.ballManager.radius + 0.1
        if self.ballManager.cellWorld:isSolid(self.ballManager.position.x, checkY) then
            isOnGround = true
        end
        
        if isOnGround then
            -- Ball is rolling on the ground, rotate based on horizontal velocity
            self.rotationSpeed = -self.ballManager.velocity.x * 0.5
        else
            -- Ball is in the air, adjust rotation based on speed
            self.rotation = self.rotation + rotationAmount
            
            -- Maintain current rotation with slight damping
            self.rotationSpeed = self.rotationSpeed * 0.99
        end
        
        -- Apply rotation
        self.rotation = self.rotation + self.rotationSpeed * dt
        
        -- Keep rotation in the range [0, 2π]
        self.rotation = self.rotation % (2 * math.pi)
    end
    
    -- Store current position for next frame
    self.lastPosition.x = self.ballManager.position.x
    self.lastPosition.y = self.ballManager.position.y
    
    -- Update cell interaction timer
    self.cellInteractionTimer = self.cellInteractionTimer + dt
    
    -- Interact with cells at regular intervals
    if self.cellInteractionTimer >= self.cellInteractionRate then
        self:interactWithCells()
        self.cellInteractionTimer = 0
    end
    
    -- Update ability duration if active
    if self.abilityActive then
        self.abilityDuration = self.abilityDuration - dt
        
        -- Apply ability effects
        self:applyAbilityEffects(dt)
        
        -- Deactivate ability when duration expires
        if self.abilityDuration <= 0 then
            self.abilityActive = false
        end
    end
    
    -- Update grid position tracking
    local gridX = math.floor(self.ballManager.position.x)
    local gridY = math.floor(self.ballManager.position.y)
    
    -- Only update if position has changed
    if gridX ~= self.currentGridPos.x or gridY ~= self.currentGridPos.y then
        -- Clear previous ball position if valid
        if self.currentGridPos.x >= 0 and self.currentGridPos.y >= 0 then
            -- Only clear if the cell is of type BALL
            local cellType = self.ballManager.cellWorld:getCell(self.currentGridPos.x, self.currentGridPos.y)
            if cellType == CellTypes.BALL then
                self.ballManager.cellWorld:setCell(self.currentGridPos.x, self.currentGridPos.y, CellTypes.EMPTY)
            end
        end
        
        -- Update current grid position
        self.currentGridPos.x = gridX
        self.currentGridPos.y = gridY
        
        -- Update ball in grid
        self:updateBallInGrid()
    end
end

-- Interact with cells around the ball
function CellBall:interactWithCells()
    local cellWorld = self.ballManager.cellWorld
    local ballX = self.ballManager.position.x
    local ballY = self.ballManager.position.y
    local radius = self.cellInteractionRadius
    
    -- Scan cells around the ball
    for y = math.floor(ballY - radius), math.ceil(ballY + radius) do
        for x = math.floor(ballX - radius), math.ceil(ballX + radius) do
            local dx = x - ballX
            local dy = y - ballY
            local distSq = dx*dx + dy*dy
            
            -- Only interact with cells within the radius
            if distSq <= radius*radius then
                local cellType = cellWorld:getCell(x, y)
                
                -- Different interactions based on cell type
                if cellType == CellTypes.WATER then
                    -- Slow down in water
                    local dragFactor = 0.95
                    self.ballManager.velocity.x = self.ballManager.velocity.x * dragFactor
                    self.ballManager.velocity.y = self.ballManager.velocity.y * dragFactor
                    
                    -- Create small water ripples (visual effect)
                    if math.random() < 0.1 then
                        -- Get the water color
                        local waterColor = cellWorld.cellColors[y][x]
                        -- Create a lighter variant for ripple
                        local rippleColor = {
                            waterColor[1] * 1.2,
                            waterColor[2] * 1.2,
                            waterColor[3] * 1.2,
                            waterColor[4] * 0.8
                        }
                        -- Update the cell color
                        cellWorld.cellColors[y][x] = rippleColor
                    end
                elseif cellType == CellTypes.SAND then
                    -- Slow down more in sand
                    local dragFactor = 0.9
                    self.ballManager.velocity.x = self.ballManager.velocity.x * dragFactor
                    self.ballManager.velocity.y = self.ballManager.velocity.y * dragFactor
                    
                    -- Displace sand slightly
                    if math.random() < 0.2 and math.abs(self.ballManager.velocity.x) + math.abs(self.ballManager.velocity.y) > 1.0 then
                        -- Get the sand color
                        local sandColor = cellWorld.cellColors[y][x]
                        
                        -- Find an empty adjacent cell
                        local directions = {{0,1}, {1,0}, {0,-1}, {-1,0}}
                        local dir = directions[math.random(#directions)]
                        local nx, ny = x + dir[1], y + dir[2]
                        
                        if cellWorld:getCell(nx, ny) == CellTypes.EMPTY then
                            cellWorld:setCell(x, y, CellTypes.EMPTY)
                            cellWorld:setCell(nx, ny, CellTypes.SAND, sandColor)
                        end
                    end
                elseif cellType == CellTypes.FIRE then
                    -- Apply a small upward force when near fire (heat rising)
                    self.ballManager.velocity.y = self.ballManager.velocity.y - 0.05
                    
                    -- Add a small random horizontal force for turbulence
                    self.ballManager.velocity.x = self.ballManager.velocity.x + (math.random() * 2 - 1) * 0.03
                end
            end
        end
    end
end

-- Apply special ability effects
function CellBall:applyAbilityEffects(dt)
    local cellWorld = self.ballManager.cellWorld
    local ballX = self.ballManager.position.x
    local ballY = self.ballManager.position.y
    
    -- Enhanced radius during ability
    local radius = self.cellInteractionRadius * 2
    
    -- Create a cellular field around the ball
    for y = math.floor(ballY - radius), math.ceil(ballY + radius) do
        for x = math.floor(ballX - radius), math.ceil(ballX + radius) do
            local dx = x - ballX
            local dy = y - ballY
            local distSq = dx*dx + dy*dy
            
            -- Only affect cells within the radius
            if distSq <= radius*radius then
                local cellType = cellWorld:getCell(x, y)
                
                -- Calculate effect strength based on distance (stronger closer to ball)
                local strength = 1.0 - math.sqrt(distSq) / radius
                
                -- Different effects based on cell type
                if cellType == CellTypes.EMPTY and math.random() < 0.05 * strength then
                    -- Create water cells with a blue tint
                    local waterColor = {
                        0.2 + math.random() * 0.2,
                        0.4 + math.random() * 0.2,
                        0.8 + math.random() * 0.2,
                        0.7 + math.random() * 0.3
                    }
                    cellWorld:setCell(x, y, CellTypes.WATER, waterColor)
                elseif cellType == CellTypes.WATER then
                    -- Energize water - make it more vibrant
                    local waterColor = cellWorld.cellColors[y][x]
                    local energizedColor = {
                        waterColor[1] * 0.8,
                        waterColor[2] * 1.1,
                        waterColor[3] * 1.2,
                        waterColor[4]
                    }
                    cellWorld.cellColors[y][x] = energizedColor
                elseif cellType == CellTypes.SAND and math.random() < 0.1 * strength then
                    -- Convert some sand to water
                    local sandColor = cellWorld.cellColors[y][x]
                    local waterColor = {
                        sandColor[1] * 0.5,
                        sandColor[2] * 0.8,
                        sandColor[3] * 1.5,
                        0.8
                    }
                    cellWorld:setCell(x, y, CellTypes.WATER, waterColor)
                elseif cellType == CellTypes.FIRE and math.random() < 0.2 * strength then
                    -- Extinguish fire and create steam
                    local fireColor = cellWorld.cellColors[y][x]
                    local steamColor = {
                        0.8,
                        0.8,
                        0.8,
                        0.7
                    }
                    cellWorld:setCell(x, y, CellTypes.STEAM, steamColor)
                end
            end
        end
    end
    
    -- Update the cell data image to reflect changes
    if math.random() < 0.2 then  -- Only update occasionally for performance
        cellWorld:updateCellDataImage()
    end
end

-- Update the ball's position in the grid
function CellBall:updateBallInGrid()
    -- Only set the ball cell if it's within bounds
    local x = math.floor(self.ballManager.position.x)
    local y = math.floor(self.ballManager.position.y)
    local cellWorld = self.ballManager.cellWorld
    
    -- Check if position is valid
    if x >= 1 and x <= cellWorld.width and y >= 1 and y <= cellWorld.height then
        -- Only set the ball cell if the current cell is empty
        if cellWorld:getCell(x, y) == CellTypes.EMPTY then
            -- Use the ball's color
            cellWorld:setCell(x, y, CellTypes.BALL, self.color)
        end
        
        -- Update current grid position
        self.currentGridPos.x = x
        self.currentGridPos.y = y
    else
        -- Invalid position, reset tracking
        self.currentGridPos.x = -1
        self.currentGridPos.y = -1
    end
end

-- Draw the cell ball
function CellBall:draw()
    local cellSize = self.ballManager.cellWorld.cellSize
    local screenX = self.ballManager.position.x * cellSize
    local screenY = self.ballManager.position.y * cellSize
    local screenRadius = self.ballManager.radius * cellSize
    
    -- Draw the simple cross pattern ball (Godot style)
    self:drawSimpleCrossBall(screenX, screenY, screenRadius)
    
    -- Draw aiming line if aiming
    if self.isAiming then
        self:drawAimingLine(screenX, screenY)
    end
    
    -- Draw ability indicator if active
    if self.abilityActive then
        self:drawAbilityEffect(screenX, screenY, screenRadius)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a simple cross pattern ball (Godot style)
function CellBall:drawSimpleCrossBall(x, y, radius)
    -- Save the current transform
    love.graphics.push()
    
    -- Translate to the ball's position
    love.graphics.translate(x, y)
    
    -- Rotate the ball
    love.graphics.rotate(self.rotation)
    
    -- Set color to white
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Size of each cell in the cross
    local cellSize = 6
    
    -- Draw center cell
    love.graphics.rectangle("fill", -cellSize/2, -cellSize/2, cellSize, cellSize)
    
    -- Draw cross pattern (4 cells in cardinal directions)
    love.graphics.rectangle("fill", -cellSize/2, -cellSize/2 - cellSize, cellSize, cellSize) -- Top
    love.graphics.rectangle("fill", -cellSize/2 + cellSize, -cellSize/2, cellSize, cellSize) -- Right
    love.graphics.rectangle("fill", -cellSize/2, -cellSize/2 + cellSize, cellSize, cellSize) -- Bottom
    love.graphics.rectangle("fill", -cellSize/2 - cellSize, -cellSize/2, cellSize, cellSize) -- Left
    
    -- Draw diagonal cells
    love.graphics.rectangle("fill", -cellSize/2 - cellSize, -cellSize/2 - cellSize, cellSize, cellSize) -- Top-left
    love.graphics.rectangle("fill", -cellSize/2 + cellSize, -cellSize/2 - cellSize, cellSize, cellSize) -- Top-right
    love.graphics.rectangle("fill", -cellSize/2 + cellSize, -cellSize/2 + cellSize, cellSize, cellSize) -- Bottom-right
    love.graphics.rectangle("fill", -cellSize/2 - cellSize, -cellSize/2 + cellSize, cellSize, cellSize) -- Bottom-left
    
    -- Restore the transform
    love.graphics.pop()
end

-- Draw the aiming line and arrow
function CellBall:drawAimingLine(screenX, screenY)
    -- Draw the power/direction indicator
    love.graphics.setColor(1, 1, 1, 0.8)  -- White color for cell ball
    love.graphics.setLineWidth(2)
    
    -- Calculate the end point of the shot (in the opposite direction)
    local lineLength = self.shotPower * 20
    local endX = screenX - math.cos(self.shotAngle) * lineLength
    local endY = screenY - math.sin(self.shotAngle) * lineLength
    
    -- Draw a simple line for the shot direction
    love.graphics.line(screenX, screenY, endX, endY)
    
    -- Draw power indicator
    local powerPercentage = self.shotPower / self.maxPower
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(string.format("Power: %.0f%%", powerPercentage * 100), 10, 70)
end

-- Draw ability effect
function CellBall:drawAbilityEffect(screenX, screenY, screenRadius)
    -- Draw pulsating circle around the ball
    local pulseRadius = screenRadius * (1.5 + 0.5 * math.sin(love.timer.getTime() * 5))
    
    -- Draw outer glow
    for i = 1, 3 do
        local alpha = 0.3 - (i * 0.1)
        local radius = pulseRadius + (i * 5)
        love.graphics.setColor(1, 1, 1, alpha)  -- White glow
        love.graphics.circle("line", screenX, screenY, radius)
    end
    
    -- Draw ability duration indicator
    local durationPercentage = self.abilityDuration / self.abilityMaxDuration
    love.graphics.setColor(1, 1, 1, 0.8)  -- White color
    love.graphics.print(string.format("Ability: %.1fs", self.abilityDuration), 10, 90)
    
    -- Draw duration bar
    love.graphics.setColor(1, 1, 1, 0.5)  -- White color
    love.graphics.rectangle("fill", 10, 110, 100 * durationPercentage, 10)
    love.graphics.setColor(1, 1, 1, 0.8)  -- White color
    love.graphics.rectangle("line", 10, 110, 100, 10)
end

return CellBall
