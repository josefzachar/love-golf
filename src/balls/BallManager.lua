-- BallManager.lua - Manages the ball and its physics
-- Circle physics with cell-based visual representation

local BallTypes = require("src.balls.BallTypes")
local CellTypes = require("src.cells.CellTypes")

local BallManager = {}
BallManager.__index = BallManager

-- Create a new ball manager
function BallManager.new(cellWorld)
    local self = setmetatable({}, BallManager)
    
    -- Reference to the cell world
    self.cellWorld = cellWorld
    
    -- Current ball properties
    self.position = {x = 0, y = 0}
    self.velocity = {x = 0, y = 0}
    self.type = BallTypes.BALL
    self.radius = 0.5  -- Ball radius in cells (half a cell)
    self.active = false
    self.inHole = false
    
    -- Physics constants
    self.gravity = 0.5  -- Gravity acceleration
    self.friction = 0.98  -- Default friction (air)
    self.bounceFactor = 0.7  -- Default bounce factor
    self.maxVelocity = 20  -- Maximum velocity cap
    self.restThreshold = 0.1 -- Threshold for considering the ball at rest
    
    -- Material properties
    self.materialProperties = {
        [CellTypes.STONE] = {
            solid = true,
            bounceFactor = 0.8,  -- Stone is more bouncy
            friction = 0.2,      -- Low friction
            strength = 5.0,      -- Very strong (hard to penetrate)
            elasticity = 1.2     -- Very elastic (bouncy)
        },
        [CellTypes.DIRT] = {
            solid = true,
            bounceFactor = 0.5,  -- Dirt absorbs more energy
            friction = 0.4,      -- Medium friction
            strength = 3.0,      -- Medium strength
            elasticity = 0.7     -- Less elastic than stone
        },
        [CellTypes.SAND] = {
            solid = false,
            bounceFactor = 0.2,  -- Sand absorbs most energy
            friction = 0.7,      -- High friction
            strength = 1.0,      -- Low strength (easy to penetrate)
            elasticity = 0.3,    -- Not very elastic
            displacement = 0.5   -- Can be displaced (crater formation)
        },
        [CellTypes.WATER] = {
            solid = false,
            liquid = true,
            bounceFactor = 0.1,  -- Almost no bounce
            friction = 0.3,      -- Medium-low friction
            viscosity = 0.6,     -- Medium viscosity
            buoyancy = 0.8,      -- High buoyancy
            displacement = 0.3   -- Can be displaced (splash effect)
        }
    }
    
    -- Shot properties
    self.isAiming = false
    self.clickPosition = {x = 0, y = 0}  -- Initial click position
    self.currentMousePosition = {x = 0, y = 0}  -- Current mouse position
    self.maxPower = 10
    self.powerMultiplier = 0.08  -- Multiplier for shot power
    
    -- Pixel art settings
    self.pixelSize = 2  -- Size of "pixels" for the pixel art effect
    
    -- Material interaction flags
    self.inSand = false
    self.inWater = false
    self.sinkingInWater = false
    self.sinkTimer = 0
    self.craterCreated = false
    
    -- Debug flag
    self.debug = true
    
    -- Force the ball to be active for testing
    self.active = true
    
    return self
end

-- Reset the ball to a starting position
function BallManager:reset(position, ballType, initialVelocity)
    -- Ensure the ball is positioned at the center of a cell
    self.position = {
        x = math.floor(position.x) + 0.5, 
        y = math.floor(position.y) + 0.5
    }
    self.velocity = initialVelocity or {x = 0, y = 0}
    self.type = BallTypes.BALL  -- Always use BALL type
    self.active = true
    self.inHole = false
    
    -- Reset aiming
    self.isAiming = false
    self.clickPosition = {x = 0, y = 0}
    self.currentMousePosition = {x = 0, y = 0}
    
    -- Reset material interaction flags
    self.inSand = false
    self.inWater = false
    self.sinkingInWater = false
    self.sinkTimer = 0
    self.craterCreated = false
    
    if self.debug then
        print("[BALL] Reset at position: " .. self.position.x .. ", " .. self.position.y)
    end
end

-- Start aiming a shot
function BallManager:startAiming(mouseX, mouseY)
    if not self.active then 
        if self.debug then
            print("[AIM] Cannot start aiming - ball inactive (active=" .. tostring(self.active) .. ")")
        end
        return 
    end
    
    if self.inHole then
        if self.debug then
            print("[AIM] Cannot start aiming - ball in hole")
        end
        return
    end
    
    -- Don't allow aiming if the ball is sinking in water
    if self.sinkingInWater then
        if self.debug then
            print("[AIM] Cannot start aiming - ball is sinking in water")
        end
        return
    end
    
    self.isAiming = true
    self.clickPosition = {x = mouseX, y = mouseY}
    self.currentMousePosition = {x = mouseX, y = mouseY}
    
    if self.debug then
        print("[AIM] Started aiming at: " .. mouseX .. ", " .. mouseY)
        print("[AIM] Ball position: " .. self.position.x .. ", " .. self.position.y)
        print("[AIM] Ball active: " .. tostring(self.active))
        print("[AIM] Ball in hole: " .. tostring(self.inHole))
        print("[AIM] Ball can be shot: " .. tostring(self:canShoot()))
        if not self:canShoot() then
            print("[AIM] Ball is moving: " .. tostring(self:isMoving()))
            print("[AIM] Ball velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
        end
    end
end

-- Update the aim parameters
function BallManager:updateAim(mouseX, mouseY)
    if not self.isAiming then 
        if self.debug then
            print("[AIM] Cannot update aim - not currently aiming")
        end
        return 
    end
    
    self.currentMousePosition = {x = mouseX, y = mouseY}
    
    -- Calculate drag distance for debugging
    local dx = self.currentMousePosition.x - self.clickPosition.x
    local dy = self.currentMousePosition.y - self.clickPosition.y
    local distance = math.sqrt(dx*dx + dy*dy)
    
    if self.debug then
        print("[AIM] Updated aim - drag distance: " .. distance)
    end
end

-- Execute the shot
function BallManager:shoot()
    if not self.isAiming then
        if self.debug then
            print("[SHOT] Cannot shoot - not aiming")
        end
        return false 
    end
    
    if not self.active then
        if self.debug then
            print("[SHOT] Cannot shoot - ball inactive (active=" .. tostring(self.active) .. ")")
        end
        return false
    end
    
    if self.inHole then
        if self.debug then
            print("[SHOT] Cannot shoot - ball in hole")
        end
        return false
    end
    
    -- Don't allow shooting if the ball is sinking in water
    if self.sinkingInWater then
        if self.debug then
            print("[SHOT] Cannot shoot - ball is sinking in water")
        end
        return false
    end
    
    -- Only apply force if the ball can actually be shot
    -- TEMPORARILY ALWAYS RETURN TRUE FOR TESTING
    -- if self:canShoot() then
    if true then  -- Force to true for testing
        -- Calculate the force vector from the click position to the current mouse position
        local dx = self.clickPosition.x - self.currentMousePosition.x
        local dy = self.clickPosition.y - self.currentMousePosition.y
        
        -- Convert screen coordinates to world coordinates
        local cellSize = self.cellWorld.cellSize
        dx = dx / cellSize
        dy = dy / cellSize
        
        -- Apply the force to the ball with a multiplier
        self.velocity.x = dx * self.powerMultiplier
        self.velocity.y = dy * self.powerMultiplier
        
        -- If the ball is in sand, reduce the initial velocity
        if self.inSand then
            self.velocity.x = self.velocity.x * 0.5
            self.velocity.y = self.velocity.y * 0.5
            
            -- Reset the sand crater flag
            self.craterCreated = false
            
            if self.debug then
                print("[SHOT] Shot power reduced due to sand")
            end
        end
        
        if self.debug then
            print("[SHOT] Executed with velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
        end
    else
        if self.debug then
            print("[SHOT] Cannot shoot - ball cannot be shot right now")
            print("[SHOT] Ball is moving: " .. tostring(self:isMoving()))
            print("[SHOT] Ball velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
            print("[SHOT] Ball position: " .. self.position.x .. ", " .. self.position.y)
            print("[SHOT] Ball active: " .. tostring(self.active))
            print("[SHOT] Ball in hole: " .. tostring(self.inHole))
        end
    end
    
    -- Reset aiming state
    self.isAiming = false
    
    return true
end

-- Cancel the current shot
function BallManager:cancelShot()
    self.isAiming = false
    
    if self.debug then
        print("[AIM] Cancelled aiming")
    end
end

-- Update the ball physics
function BallManager:update(dt)
    if not self.active or self.inHole then return end
    
    -- If aiming, don't update physics
    if self.isAiming then return end
    
    -- Check the current cell type the ball is in
    local cellX = math.floor(self.position.x)
    local cellY = math.floor(self.position.y)
    local currentCellType = self.cellWorld:getCell(cellX, cellY)
    
    -- Handle special material interactions
    self:handleMaterialInteractions(currentCellType, dt)
    
    -- If the ball is sinking in water, handle that separately
    if self.sinkingInWater then
        self:handleWaterSinking(dt)
        return
    end
    
    -- Apply gravity (reduced in water)
    local gravityModifier = 1.0
    if self.inWater then
        -- Apply buoyancy in water
        gravityModifier = 0.3  -- 70% reduction in gravity due to buoyancy
    end
    self.velocity.y = self.velocity.y + self.gravity * gravityModifier * dt
    
    -- Cap velocity
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    if speed > self.maxVelocity then
        self.velocity.x = self.velocity.x * (self.maxVelocity / speed)
        self.velocity.y = self.velocity.y * (self.maxVelocity / speed)
    end
    
    -- Store old position for collision detection
    local oldX = self.position.x
    local oldY = self.position.y
    
    -- Update position
    self.position.x = self.position.x + self.velocity.x * dt
    self.position.y = self.position.y + self.velocity.y * dt
    
    -- Check for collisions
    self:handleCollisions(oldX, oldY, dt)
    
    -- Apply friction based on material
    local frictionFactor = self.friction  -- Default air friction
    
    if self.inSand then
        frictionFactor = 0.9  -- High friction in sand
    elseif self.inWater then
        frictionFactor = 0.95  -- Medium friction in water
    end
    
    self.velocity.x = self.velocity.x * frictionFactor
    self.velocity.y = self.velocity.y * frictionFactor
    
    -- Check if ball is almost stopped
    if speed < self.restThreshold then
        self.velocity.x = 0
        self.velocity.y = 0
        
        -- If the ball stops in sand, create a small depression
        if currentCellType == CellTypes.SAND and not self.craterCreated then
            self:createSandDepression()
        end
    end
    
    -- Check if ball is in a hole
    if self:checkHole() then
        self.inHole = true
        self.active = false
        
        if self.debug then
            print("[BALL] Ball in hole!")
        end
    end
end

-- Handle material-specific interactions
function BallManager:handleMaterialInteractions(cellType, dt)
    -- Update material flags
    self.inSand = (cellType == CellTypes.SAND)
    self.inWater = (cellType == CellTypes.WATER)
    
    -- Handle water interaction
    if self.inWater and not self.sinkingInWater then
        -- Start sinking if the ball is moving slowly
        local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
        if speed < 3.0 then
            self.sinkingInWater = true
            self.sinkTimer = 0
            
            if self.debug then
                print("[BALL] Ball started sinking in water")
            end
        end
    end
    
    -- Apply material-specific effects
    if cellType == CellTypes.WATER then
        -- Apply water resistance and buoyancy
        self:applyWaterPhysics(dt)
    elseif cellType == CellTypes.SAND then
        -- Apply sand physics
        self:applySandPhysics(dt)
    end
end

-- Apply water physics effects
function BallManager:applyWaterPhysics(dt)
    -- Apply water resistance (based on velocity)
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    local resistanceFactor = 0.95 - (speed * 0.01)  -- More resistance at higher speeds
    resistanceFactor = math.max(0.8, resistanceFactor)  -- Cap minimum resistance
    
    self.velocity.x = self.velocity.x * resistanceFactor
    self.velocity.y = self.velocity.y * resistanceFactor
    
    -- Apply buoyancy effect (upward force)
    local buoyancyForce = 0.2
    self.velocity.y = self.velocity.y - buoyancyForce * dt
    
    -- Create ripple effect for fast-moving ball
    if speed > 5.0 and math.random() < 0.1 then
        -- TODO: Add visual ripple effect
    end
end

-- Apply sand physics effects
function BallManager:applySandPhysics(dt)
    -- Apply increased friction in sand
    local frictionFactor = 0.9
    self.velocity.x = self.velocity.x * frictionFactor
    self.velocity.y = self.velocity.y * frictionFactor
    
    -- Slow down vertical movement more in sand
    self.velocity.y = self.velocity.y * 0.95
    
    -- Create small sand displacement effects for fast-moving ball
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    if speed > 5.0 and math.random() < 0.1 then
        -- TODO: Add visual sand displacement effect
    end
end

-- Handle the ball sinking in water
function BallManager:handleWaterSinking(dt)
    -- Increment the sink timer
    self.sinkTimer = self.sinkTimer + dt
    
    -- Gradually sink the ball
    local sinkDuration = 3.0  -- Time in seconds to fully sink
    local sinkProgress = math.min(self.sinkTimer / sinkDuration, 1.0)
    
    -- Apply a small random movement to simulate water ripples
    local rippleStrength = 0.01 * (1.0 - sinkProgress)
    self.position.x = self.position.x + (math.random() * 2 - 1) * rippleStrength
    self.position.y = self.position.y + (math.random() * 2 - 1) * rippleStrength
    
    -- If the ball has fully sunk, deactivate it
    if sinkProgress >= 1.0 then
        self.active = false
        
        if self.debug then
            print("[BALL] Ball has fully sunk in water")
        end
    end
end

-- Create a depression in sand when the ball stops
function BallManager:createSandDepression()
    local cellX = math.floor(self.position.x)
    local cellY = math.floor(self.position.y)
    
    -- Check if we're actually on sand
    if self.cellWorld:getCell(cellX, cellY) == CellTypes.SAND then
        -- Mark that we're now in a sand depression
        self.inSand = true
        self.craterCreated = true
        
        -- TODO: Add visual sand depression effect
        -- For now, we'll just mark it with a flag
        
        if self.debug then
            print("[BALL] Created depression in sand at: " .. cellX .. ", " .. cellY)
        end
    end
end

-- Handle collisions with solid cells and boundaries
function BallManager:handleCollisions(oldX, oldY, dt)
    -- Check for collisions with solid cells
    local newCellX = math.floor(self.position.x)
    local newCellY = math.floor(self.position.y)
    
    -- Get the cell type at the new position
    local cellType = self.cellWorld:getCell(newCellX, newCellY)
    
    -- Check if the new position would be inside a solid cell
    if cellType == CellTypes.STONE or cellType == CellTypes.DIRT or cellType == CellTypes.BOUNDARY then
        -- Find which direction to bounce
        local oldCellX = math.floor(oldX)
        local oldCellY = math.floor(oldY)
        
        -- Get the old cell type
        local oldCellType = self.cellWorld:getCell(oldCellX, oldCellY)
        
        -- Calculate impact force for potential crater formation
        local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
        local impactForce = speed * 0.5  -- Simple impact force calculation
        
        -- Horizontal collision
        if oldCellX ~= newCellX then
            local sideCell = self.cellWorld:getCell(newCellX, oldCellY)
            if sideCell == CellTypes.STONE or sideCell == CellTypes.DIRT or sideCell == CellTypes.BOUNDARY then
                -- Bounce with appropriate factor based on material
                local bounceFactor = self:getMaterialBounceFactor(sideCell)
                self.velocity.x = -self.velocity.x * bounceFactor
                self.position.x = oldX  -- Revert to old position
                
                -- Create impact effect if hitting with enough force
                if impactForce > 3.0 then
                    self:createImpactEffect(newCellX, oldCellY, sideCell, impactForce)
                end
                
                if self.debug then
                    print("[COLLISION] Horizontal collision with " .. self:getMaterialName(sideCell))
                end
            end
        end
        
        -- Vertical collision
        if oldCellY ~= newCellY then
            local floorCell = self.cellWorld:getCell(oldCellX, newCellY)
            if floorCell == CellTypes.STONE or floorCell == CellTypes.DIRT or floorCell == CellTypes.BOUNDARY then
                -- Bounce with appropriate factor based on material
                local bounceFactor = self:getMaterialBounceFactor(floorCell)
                self.velocity.y = -self.velocity.y * bounceFactor
                self.position.y = oldY  -- Revert to old position
                
                -- Create impact effect if hitting with enough force
                if impactForce > 3.0 then
                    self:createImpactEffect(oldCellX, newCellY, floorCell, impactForce)
                end
                
                if self.debug then
                    print("[COLLISION] Vertical collision with " .. self:getMaterialName(floorCell))
                end
            end
        end
        
        -- Diagonal collision
        if oldCellX ~= newCellX and oldCellY ~= newCellY then
            -- Bounce with appropriate factor based on material
            local bounceFactor = self:getMaterialBounceFactor(cellType)
            self.velocity.x = -self.velocity.x * bounceFactor
            self.velocity.y = -self.velocity.y * bounceFactor
            self.position.x = oldX  -- Revert to old position
            self.position.y = oldY  -- Revert to old position
            
            -- Create impact effect if hitting with enough force
            if impactForce > 3.0 then
                self:createImpactEffect(newCellX, newCellY, cellType, impactForce)
            end
            
            if self.debug then
                print("[COLLISION] Diagonal collision with " .. self:getMaterialName(cellType))
            end
        end
    end
    
    -- Check for liquid effects
    if self.cellWorld:isLiquid(newCellX, newCellY) then
        -- Standard liquid physics
        self.velocity.x = self.velocity.x * 0.95
        self.velocity.y = self.velocity.y * 0.95
        
        -- Buoyancy effect
        self.velocity.y = self.velocity.y - 0.1
    end
    
    -- Boundary checking
    local worldWidth = self.cellWorld.width
    local worldHeight = self.cellWorld.height
    
    if self.position.x < 1 then
        self.position.x = 1
        self.velocity.x = -self.velocity.x * self.bounceFactor
        
        if self.debug then
            print("[COLLISION] Hit left boundary")
        end
    elseif self.position.x > worldWidth - 1 then
        self.position.x = worldWidth - 1
        self.velocity.x = -self.velocity.x * self.bounceFactor
        
        if self.debug then
            print("[COLLISION] Hit right boundary")
        end
    end
    
    if self.position.y < 1 then
        self.position.y = 1
        self.velocity.y = -self.velocity.y * self.bounceFactor
        
        if self.debug then
            print("[COLLISION] Hit top boundary")
        end
    elseif self.position.y > worldHeight - 1 then
        self.position.y = worldHeight - 1
        self.velocity.y = -self.velocity.y * self.bounceFactor
        
        if self.debug then
            print("[COLLISION] Hit bottom boundary")
        end
    end
end

-- Create impact effect based on material and force
function BallManager:createImpactEffect(cellX, cellY, cellType, impactForce)
    -- Check adjacent cells for sand to create crater
    local directions = {
        {x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1},
        {x = 1, y = 1}, {x = -1, y = 1}, {x = 1, y = -1}, {x = -1, y = -1}
    }
    
    for _, dir in ipairs(directions) do
        local checkX = cellX + dir.x
        local checkY = cellY + dir.y
        
        -- Check if the cell is within bounds
        if checkX >= 1 and checkX <= self.cellWorld.width and
           checkY >= 1 and checkY <= self.cellWorld.height then
            
            local checkCellType = self.cellWorld:getCell(checkX, checkY)
            
            -- Only create craters in sand
            if checkCellType == CellTypes.SAND then
                -- TODO: Create visual crater effect
                -- For now, just log it
                if self.debug then
                    print("[IMPACT] Created crater in sand at: " .. checkX .. ", " .. checkY)
                end
                break  -- Only create one crater per impact
            end
        end
    end
end

-- Get the bounce factor for a specific material
function BallManager:getMaterialBounceFactor(cellType)
    local materialProps = self.materialProperties[cellType]
    if materialProps and materialProps.bounceFactor then
        return materialProps.bounceFactor
    end
    
    -- Default bounce factors for common materials
    if cellType == CellTypes.STONE then
        return 0.8  -- Stone is more bouncy
    elseif cellType == CellTypes.DIRT then
        return 0.5  -- Dirt absorbs more energy
    elseif cellType == CellTypes.BOUNDARY then
        return 0.7  -- Default bounce factor
    else
        return self.bounceFactor
    end
end

-- Get a human-readable name for a material
function BallManager:getMaterialName(cellType)
    if cellType == CellTypes.STONE then
        return "Stone"
    elseif cellType == CellTypes.DIRT then
        return "Dirt"
    elseif cellType == CellTypes.SAND then
        return "Sand"
    elseif cellType == CellTypes.WATER then
        return "Water"
    elseif cellType == CellTypes.BOUNDARY then
        return "Boundary"
    else
        return "Unknown (" .. cellType .. ")"
    end
end

-- Check if the ball is in a hole
function BallManager:checkHole()
    -- Check if the current cell is a hole
    local cellX = math.floor(self.position.x)
    local cellY = math.floor(self.position.y)
    
    local cellType = self.cellWorld:getCell(cellX, cellY)
    return cellType == CellTypes.HOLE  -- Hole cell type
end

-- Draw a pixelated dotted line
function BallManager:drawPixelatedDottedLine(startX, startY, endX, endY, color, dashLength, gapLength, thickness)
    -- Calculate direction vector
    local dx = endX - startX
    local dy = endY - startY
    local distance = math.sqrt(dx*dx + dy*dy)
    
    if distance == 0 then return end
    
    local dirX = dx / distance
    local dirY = dy / distance
    
    -- Default values
    dashLength = dashLength or 8
    gapLength = gapLength or 12
    thickness = thickness or 4
    
    -- Draw individual square "dots"
    local currentDistance = 0
    while currentDistance < distance do
        local dotX = startX + dirX * currentDistance
        local dotY = startY + dirY * currentDistance
        
        -- Round to pixel grid for pixelated look
        dotX = math.floor(dotX / self.pixelSize) * self.pixelSize
        dotY = math.floor(dotY / self.pixelSize) * self.pixelSize
        
        -- Draw a single square "dot"
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", 
                               dotX - thickness/2, 
                               dotY - thickness/2, 
                               thickness, 
                               thickness)
        
        -- Move to next dot position
        currentDistance = currentDistance + dashLength + gapLength
    end
end

-- Draw a pixelated arrowhead
function BallManager:drawPixelatedArrowhead(x, y, dirX, dirY, color, size)
    -- Default size
    size = size or 10
    
    -- Calculate points for a pixelated arrow
    local backDirX = -dirX
    local backDirY = -dirY
    
    -- Rotate back direction by 45 degrees for right point
    local rightDirX = backDirX * math.cos(math.pi/4) - backDirY * math.sin(math.pi/4)
    local rightDirY = backDirX * math.sin(math.pi/4) + backDirY * math.cos(math.pi/4)
    
    -- Rotate back direction by -45 degrees for left point
    local leftDirX = backDirX * math.cos(-math.pi/4) - backDirY * math.sin(-math.pi/4)
    local leftDirY = backDirX * math.sin(-math.pi/4) + backDirY * math.cos(-math.pi/4)
    
    -- Calculate the three points of the triangle
    local rightX = x + rightDirX * size
    local rightY = y + rightDirY * size
    
    local leftX = x + leftDirX * size
    local leftY = y + leftDirY * size
    
    -- Draw the filled triangle
    love.graphics.setColor(color)
    love.graphics.polygon("fill", x, y, rightX, rightY, leftX, leftY)
end

-- Draw the ball and aiming line
function BallManager:draw()
    if not self.active then return end
    
    -- Draw the ball as a square cell
    local cellSize = self.cellWorld.cellSize
    
    -- Calculate screen position - center of the cell
    local cellX = math.floor(self.position.x)
    local cellY = math.floor(self.position.y)
    local screenX = cellX * cellSize
    local screenY = cellY * cellSize
    
    -- Draw a white square at the ball's position
    love.graphics.setColor(1, 1, 1, 1)
    
    -- If the ball is sinking in water, adjust the opacity
    if self.sinkingInWater then
        local sinkDuration = 3.0
        local sinkProgress = math.min(self.sinkTimer / sinkDuration, 1.0)
        love.graphics.setColor(1, 1, 1, 1.0 - sinkProgress)
    end
    
    -- Draw the ball with a slight offset if in a sand depression
    local yOffset = 0
    if self.inSand and self.craterCreated then
        yOffset = cellSize * 0.1  -- Slight downward offset to show depression
    end
    
    love.graphics.rectangle("fill", screenX, screenY + yOffset, cellSize, cellSize)
    
    -- Draw aiming line if aiming
    if self.isAiming then
        -- Use the actual position for the aiming line
        local actualScreenX = self.position.x * cellSize
        local actualScreenY = self.position.y * cellSize
        
        -- Calculate the direction vectors
        local dx = self.currentMousePosition.x - self.clickPosition.x
        local dy = self.currentMousePosition.y - self.clickPosition.y
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 0 then
            local dragDirX = dx / distance
            local dragDirY = dy / distance
            
            -- Calculate the power based on drag distance
            local power = math.min(distance / 100, 1.0)
            
            -- Draw the aiming line
            self:drawPixelatedDottedLine(
                actualScreenX, 
                actualScreenY, 
                actualScreenX - dragDirX * 100 * power, 
                actualScreenY - dragDirY * 100 * power, 
                {1, 1, 0, 0.8},  -- Yellow color
                8, 12, 4
            )
            
            -- Draw the arrowhead at the end of the line
            self:drawPixelatedArrowhead(
                actualScreenX - dragDirX * 100 * power, 
                actualScreenY - dragDirY * 100 * power, 
                -dragDirX, -dragDirY, 
                {1, 1, 0, 0.8},  -- Yellow color
                10
            )
        end
    end
end

-- Check if the ball is moving
function BallManager:isMoving()
    -- Calculate the ball's speed
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    
    -- Ball is considered moving if its speed is above the rest threshold
    return speed > self.restThreshold
end

-- Check if the ball can be shot
function BallManager:canShoot()
    -- Ball can be shot if it's active, not in a hole, not moving, and not sinking in water
    return self.active and not self.inHole and not self:isMoving() and not self.sinkingInWater
end

-- Get the current ball position
function BallManager:getCurrentBall()
    -- Return the ball position as a table with x and y coordinates
    return {
        x = self.position.x,
        y = self.position.y
    }
end

-- Get the current ball type
function BallManager:getCurrentBallType()
    -- Return the ball type as a string
    if self.type == BallTypes.BALL then
        return "Ball"
    else
        return "Unknown"
    end
end

-- Check if the ball is in a hole
function BallManager:isInHole()
    return self.inHole
end

-- Return the module
return BallManager
