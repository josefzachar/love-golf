-- BallManager.lua - Manages the ball and its physics
-- Circle physics with cell-based visual representation

local BallTypes = require("src.balls.BallTypes")

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
    self.gravity = 0.5  -- Increased gravity for more noticeable effect
    self.friction = 0.98
    self.bounceFactor = 0.7
    self.maxVelocity = 20
    self.restThreshold = 0.1 -- Threshold for considering the ball at rest
    
    -- Shot properties
    self.shotPower = 0
    self.shotAngle = 0
    self.isAiming = false
    self.maxPower = 10
    
    -- Debug flag
    self.debug = true
    
    return self
end

-- Reset the ball to a starting position
function BallManager:reset(position, ballType, initialVelocity)
    self.position = {x = position.x, y = position.y}
    self.velocity = initialVelocity or {x = 0, y = 0}
    self.type = BallTypes.BALL  -- Always use BALL type
    self.active = true
    self.inHole = false
    
    if self.debug then
        print("Ball reset at position: " .. self.position.x .. ", " .. self.position.y)
    end
end

-- Start aiming a shot
function BallManager:startAiming()
    if not self.active or self.inHole then return end
    
    self.isAiming = true
    self.shotPower = 0
    self.shotAngle = 0
    
    if self.debug then
        print("Started aiming")
    end
end

-- Update the aim parameters
function BallManager:updateAim(mouseX, mouseY)
    if not self.isAiming then return end
    
    -- Calculate angle and power based on mouse position relative to ball
    local cellSize = self.cellWorld.cellSize
    local dx = mouseX - self.position.x * cellSize
    local dy = mouseY - self.position.y * cellSize
    
    -- Direction from ball to current mouse position
    self.shotAngle = math.atan2(dy, dx)
    
    -- Calculate power based on distance, with a maximum
    local distance = math.sqrt(dx*dx + dy*dy)
    self.shotPower = math.min(distance / 20, self.maxPower)
end

-- Execute the shot
function BallManager:shoot()
    if not self.isAiming or not self.active or self.inHole then return false end
    
    -- Apply velocity based on shot power and angle
    self.velocity.x = -math.cos(self.shotAngle) * self.shotPower
    self.velocity.y = -math.sin(self.shotAngle) * self.shotPower
    
    self.isAiming = false
    
    if self.debug then
        print("Shot executed with velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
    end
    
    return true
end

-- Cancel the current shot
function BallManager:cancelShot()
    self.isAiming = false
end

-- Update the ball physics
function BallManager:update(dt)
    if not self.active or self.inHole then return end
    
    -- If aiming, don't update physics
    if self.isAiming then return end
    
    -- Apply gravity
    self.velocity.y = self.velocity.y + self.gravity
    
    if self.debug then
        print("Ball velocity after gravity: " .. self.velocity.x .. ", " .. self.velocity.y)
    end
    
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
    
    -- Apply friction
    self.velocity.x = self.velocity.x * self.friction
    self.velocity.y = self.velocity.y * self.friction
    
    -- Check if ball is almost stopped
    if speed < self.restThreshold then
        self.velocity.x = 0
        self.velocity.y = 0
    end
    
    -- Check if ball is in a hole
    if self:checkHole() then
        self.inHole = true
        self.active = false
    end
    
    if self.debug then
        print("Ball position after update: " .. self.position.x .. ", " .. self.position.y)
    end
end

-- Handle collisions with solid cells and boundaries
function BallManager:handleCollisions(oldX, oldY, dt)
    -- Check for collisions with solid cells
    local newCellX = math.floor(self.position.x)
    local newCellY = math.floor(self.position.y)
    
    -- Check if the new position would be inside a solid cell
    if self.cellWorld:isSolid(newCellX, newCellY) then
        if self.debug then
            print("Collision detected with solid cell at: " .. newCellX .. ", " .. newCellY)
        end
        
        -- Find which direction to bounce
        local oldCellX = math.floor(oldX)
        local oldCellY = math.floor(oldY)
        
        -- Horizontal collision
        if oldCellX ~= newCellX and self.cellWorld:isSolid(newCellX, oldCellY) then
            self.velocity.x = -self.velocity.x * self.bounceFactor
            self.position.x = oldX  -- Revert to old position
            
            if self.debug then
                print("Horizontal collision, new velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
            end
        -- Vertical collision
        elseif oldCellY ~= newCellY and self.cellWorld:isSolid(oldCellX, newCellY) then
            self.velocity.y = -self.velocity.y * self.bounceFactor
            self.position.y = oldY  -- Revert to old position
            
            if self.debug then
                print("Vertical collision, new velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
            end
        -- Diagonal collision
        else
            self.velocity.x = -self.velocity.x * self.bounceFactor
            self.velocity.y = -self.velocity.y * self.bounceFactor
            self.position.x = oldX  -- Revert to old position
            self.position.y = oldY  -- Revert to old position
            
            if self.debug then
                print("Diagonal collision, new velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
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
        
        if self.debug then
            print("In liquid, new velocity: " .. self.velocity.x .. ", " .. self.velocity.y)
        end
    end
    
    -- Boundary checking
    local worldWidth = self.cellWorld.width
    local worldHeight = self.cellWorld.height
    
    if self.position.x < 1 then
        self.position.x = 1
        self.velocity.x = -self.velocity.x * self.bounceFactor
        
        if self.debug then
            print("Hit left boundary")
        end
    elseif self.position.x > worldWidth - 1 then
        self.position.x = worldWidth - 1
        self.velocity.x = -self.velocity.x * self.bounceFactor
        
        if self.debug then
            print("Hit right boundary")
        end
    end
    
    if self.position.y < 1 then
        self.position.y = 1
        self.velocity.y = -self.velocity.y * self.bounceFactor
        
        if self.debug then
            print("Hit top boundary")
        end
    elseif self.position.y > worldHeight - 1 then
        self.position.y = worldHeight - 1
        self.velocity.y = -self.velocity.y * self.bounceFactor
        
        if self.debug then
            print("Hit bottom boundary")
        end
    end
end

-- Check if the ball is in a hole
function BallManager:checkHole()
    -- Check if the current cell is a hole
    local cellX = math.floor(self.position.x)
    local cellY = math.floor(self.position.y)
    
    local cellType = self.cellWorld:getCell(cellX, cellY)
    return cellType == 90  -- Hole cell type
end

-- Draw the ball and aiming line
function BallManager:draw()
    if not self.active then return end
    
    -- Draw the ball as a square cell
    local cellSize = self.cellWorld.cellSize
    local screenX = self.position.x * cellSize
    local screenY = self.position.y * cellSize
    
    -- Draw a white square at the ball's position
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 
                           math.floor(screenX - cellSize/2), 
                           math.floor(screenY - cellSize/2), 
                           cellSize, 
                           cellSize)
    
    -- Draw aiming line if aiming
    if self.isAiming then
        love.graphics.setColor(1, 1, 1, 0.7)
        local lineLength = self.shotPower * 20
        local endX = screenX - math.cos(self.shotAngle) * lineLength
        local endY = screenY - math.sin(self.shotAngle) * lineLength
        
        -- Draw dashed line
        local dashLength = 5
        local gapLength = 3
        local totalLength = dashLength + gapLength
        local dx = endX - screenX
        local dy = endY - screenY
        local distance = math.sqrt(dx*dx + dy*dy)
        local numDashes = math.floor(distance / totalLength)
        
        for i = 0, numDashes do
            local startFraction = i * totalLength / distance
            local endFraction = math.min((i * totalLength + dashLength) / distance, 1)
            
            local dashStartX = screenX + dx * startFraction
            local dashStartY = screenY + dy * startFraction
            local dashEndX = screenX + dx * endFraction
            local dashEndY = screenY + dy * endFraction
            
            love.graphics.setLineWidth(2)
            love.graphics.line(dashStartX, dashStartY, dashEndX, dashEndY)
        end
        
        -- Draw power indicator
        local powerPercentage = self.shotPower / self.maxPower
        love.graphics.setColor(1, 1 - powerPercentage, 0, 0.8)
        love.graphics.print(string.format("Power: %.0f%%", powerPercentage * 100), 10, 70)
    end
    
    -- Draw velocity vector for debugging
    if self.debug then
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.line(screenX, screenY, 
                          screenX + self.velocity.x * 5, 
                          screenY + self.velocity.y * 5)
    end
end

-- Get the current ball
function BallManager:getCurrentBall()
    return {
        x = self.position.x,
        y = self.position.y,
        type = self.type,
        active = self.active
    }
end

-- Get the current ball type name
function BallManager:getCurrentBallType()
    return BallTypes.getName(self.type)
end

-- Check if the ball is in a hole
function BallManager:isInHole()
    return self.inHole
end

-- Check if the ball is moving
function BallManager:isMoving()
    -- Use the rest threshold to consider the ball stopped
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    return speed > self.restThreshold
end

-- Check if the ball can be shot
function BallManager:canShoot()
    -- Don't allow shooting if in a hole
    if self.inHole then
        return false
    end
    
    -- Special case: if at bottom edge allow shooting regardless of velocity
    if self.position.y >= self.cellWorld.height - 1.5 then
        return true
    end
    
    -- Use the rest threshold to determine if the ball can be shot
    return not self:isMoving()
end

-- Check if the ball is currently aiming
function BallManager:isCurrentlyAiming()
    return self.isAiming
end

return BallManager
