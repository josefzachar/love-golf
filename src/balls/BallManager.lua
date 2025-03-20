-- BallManager.lua - Manages the golf balls and their physics

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
    self.type = BallTypes.STANDARD
    self.radius = 1.5  -- Ball radius in cells (smaller for better collision)
    self.active = false
    self.inHole = false
    
    -- Physics constants
    self.gravity = 0.2
    self.friction = 0.98
    self.bounceFactor = 0.7
    self.maxVelocity = 10
    
    -- Shot properties
    self.shotPower = 0
    self.shotAngle = 0
    self.isAiming = false
    self.maxPower = 20
    
    -- Special abilities cooldowns
    self.abilityCooldown = 0
    
    return self
end

-- Reset the ball to a starting position
function BallManager:reset(position, ballType)
    self.position = {x = position.x, y = position.y}
    self.velocity = {x = 0, y = 0}
    self.type = ballType or BallTypes.STANDARD
    self.active = true
    self.inHole = false
    self.abilityCooldown = 0
    
    -- Adjust physics based on ball type
    if self.type == BallTypes.STICKY then
        self.bounceFactor = 0.3
    elseif self.type == BallTypes.EXPLOSIVE then
        self.bounceFactor = 0.8
    elseif self.type == BallTypes.MINING then
        self.bounceFactor = 0.6
    else
        self.bounceFactor = 0.7
    end
end

-- Start aiming a shot
function BallManager:startAiming()
    if not self.active or self.inHole then return end
    
    self.isAiming = true
    self.shotPower = 0
    self.shotAngle = 0
end

-- Update the aim parameters
function BallManager:updateAim(mouseX, mouseY)
    if not self.isAiming then return end
    
    -- Calculate angle and power based on mouse position relative to ball
    local dx = mouseX - self.position.x * self.cellWorld.cellSize
    local dy = mouseY - self.position.y * self.cellWorld.cellSize
    
    self.shotAngle = math.atan2(dy, dx)
    
    -- Calculate power based on distance, with a maximum
    local distance = math.sqrt(dx*dx + dy*dy)
    self.shotPower = math.min(distance / 20, self.maxPower)
end

-- Execute the shot
function BallManager:shoot()
    if not self.isAiming or not self.active or self.inHole then return end
    
    -- Apply velocity based on shot power and angle
    self.velocity.x = -math.cos(self.shotAngle) * self.shotPower
    self.velocity.y = -math.sin(self.shotAngle) * self.shotPower
    
    self.isAiming = false
end

-- Cancel the current shot
function BallManager:cancelShot()
    self.isAiming = false
end

-- Use the ball's special ability
function BallManager:useAbility()
    if not self.active or self.inHole or self.abilityCooldown > 0 then return false end
    
    -- Different abilities based on ball type
    if self.type == BallTypes.EXPLOSIVE then
        -- Explosive ball creates an explosion
        self.cellWorld:explode(self.position.x, self.position.y, 15)
        self.abilityCooldown = 60  -- 1 second at 60 FPS
        return true
    elseif self.type == BallTypes.MINING then
        -- Mining ball can dig through materials
        local digRadius = 8
        self.cellWorld:drawCircle(self.position.x, self.position.y, digRadius, 0)  -- Clear cells
        self.abilityCooldown = 120  -- 2 seconds at 60 FPS
        return true
    elseif self.type == BallTypes.STICKY then
        -- Sticky ball can create a platform
        local platformRadius = 5
        for y = -1, 1 do
            for x = -platformRadius, platformRadius do
                self.cellWorld:setCell(
                    math.floor(self.position.x) + x,
                    math.floor(self.position.y) + y + 3,
                    10  -- Stone
                )
            end
        end
        self.cellWorld:updateCellDataImage()
        self.abilityCooldown = 180  -- 3 seconds at 60 FPS
        return true
    end
    
    return false
end

-- Update the ball physics
function BallManager:update(dt)
    if not self.active or self.inHole then return end
    
    -- Update ability cooldown
    if self.abilityCooldown > 0 then
        self.abilityCooldown = self.abilityCooldown - 1
    end
    
    -- If aiming, don't update physics
    if self.isAiming then return end
    
    -- Apply gravity
    self.velocity.y = self.velocity.y + self.gravity
    
    -- Cap velocity
    local speed = math.sqrt(self.velocity.x^2 + self.velocity.y^2)
    if speed > self.maxVelocity then
        self.velocity.x = self.velocity.x * (self.maxVelocity / speed)
        self.velocity.y = self.velocity.y * (self.maxVelocity / speed)
    end
    
    -- Check for collisions and update position
    self:updatePosition(dt)
    
    -- Apply friction
    self.velocity.x = self.velocity.x * self.friction
    self.velocity.y = self.velocity.y * self.friction
    
    -- Check if ball is almost stopped
    if math.abs(self.velocity.x) < 0.01 and math.abs(self.velocity.y) < 0.01 then
        self.velocity.x = 0
        self.velocity.y = 0
    end
    
    -- Check if ball is in a hole
    if self:checkHole() then
        self.inHole = true
        self.active = false
    end
end

-- Update position with collision detection
function BallManager:updatePosition(dt)
    -- Calculate new position
    local newX = self.position.x + self.velocity.x * dt
    local newY = self.position.y + self.velocity.y * dt
    
    -- Check for collisions with solid cells
    local collided = false
    
    -- More thorough collision detection - check the entire ball area
    local steps = 8  -- Check in 8 directions around the ball
    local radius = self.radius
    
    -- First check if the new position would be inside a solid cell
    for angle = 0, math.pi * 2, math.pi * 2 / steps do
        local checkX = newX + math.cos(angle) * radius
        local checkY = newY + math.sin(angle) * radius
        
        if self.cellWorld:isSolid(checkX, checkY) then
            -- Find the normal vector for the collision
            local normalX = checkX - newX
            local normalY = checkY - newY
            local normalLength = math.sqrt(normalX * normalX + normalY * normalY)
            
            if normalLength > 0 then
                normalX = normalX / normalLength
                normalY = normalY / normalLength
                
                -- Calculate reflection vector
                local dotProduct = self.velocity.x * normalX + self.velocity.y * normalY
                
                -- Apply bounce
                self.velocity.x = self.velocity.x - 2 * dotProduct * normalX
                self.velocity.y = self.velocity.y - 2 * dotProduct * normalY
                
                -- Apply bounce factor
                self.velocity.x = self.velocity.x * self.bounceFactor
                self.velocity.y = self.velocity.y * self.bounceFactor
                
                -- Adjust position to prevent getting stuck
                newX = self.position.x
                newY = self.position.y
                
                collided = true
                break
            end
        end
    end
    
    -- If no collision was detected with the full check, do a simpler check for horizontal and vertical movement
    if not collided then
        -- Check horizontal movement
        if self.velocity.x ~= 0 then
            local checkX = newX + (self.velocity.x > 0 and radius or -radius)
            
            -- Check for solid cells in the path
            if self.cellWorld:isSolid(checkX, self.position.y) then
                -- Collision with solid cell
                collided = true
                
                -- Bounce horizontally
                self.velocity.x = -self.velocity.x * self.bounceFactor
                
                -- Adjust position to prevent getting stuck
                if self.velocity.x > 0 then
                    newX = math.floor(checkX) - radius
                else
                    newX = math.ceil(checkX) + radius
                end
            end
        end
        
        -- Check vertical movement
        if self.velocity.y ~= 0 then
            local checkY = newY + (self.velocity.y > 0 and radius or -radius)
            
            -- Check for solid cells in the path
            if self.cellWorld:isSolid(self.position.x, checkY) then
                -- Collision with solid cell
                collided = true
                
                -- Bounce vertically
                self.velocity.y = -self.velocity.y * self.bounceFactor
                
                -- Adjust position to prevent getting stuck
                if self.velocity.y > 0 then
                    newY = math.floor(checkY) - radius
                else
                    newY = math.ceil(checkY) + radius
                end
            end
        end
    end
    
    -- Check for liquid effects
    local isInLiquid = false
    for y = newY - self.radius/2, newY + self.radius/2, 1 do
        for x = newX - self.radius/2, newX + self.radius/2, 1 do
            if self.cellWorld:isLiquid(x, y) then
                isInLiquid = true
                break
            end
        end
        if isInLiquid then break end
    end
    
    if isInLiquid then
        -- Apply additional drag in liquids
        self.velocity.x = self.velocity.x * 0.95
        self.velocity.y = self.velocity.y * 0.95
        
        -- Buoyancy effect
        self.velocity.y = self.velocity.y - 0.1
    end
    
    -- Special behavior for sticky ball
    if self.type == BallTypes.STICKY and collided then
        -- Sticky ball loses more energy on collision
        self.velocity.x = self.velocity.x * 0.7
        self.velocity.y = self.velocity.y * 0.7
    end
    
    -- Special behavior for explosive ball
    if self.type == BallTypes.EXPLOSIVE and collided and 
       math.sqrt(self.velocity.x^2 + self.velocity.y^2) > 10 then
        -- Hard collision triggers explosion
        self:useAbility()
    end
    
    -- Update position
    self.position.x = newX
    self.position.y = newY
    
    -- Boundary checking
    local worldWidth = self.cellWorld.width
    local worldHeight = self.cellWorld.height
    
    if self.position.x < self.radius then
        self.position.x = self.radius
        self.velocity.x = -self.velocity.x * self.bounceFactor
    elseif self.position.x > worldWidth - self.radius then
        self.position.x = worldWidth - self.radius
        self.velocity.x = -self.velocity.x * self.bounceFactor
    end
    
    if self.position.y < self.radius then
        self.position.y = self.radius
        self.velocity.y = -self.velocity.y * self.bounceFactor
    elseif self.position.y > worldHeight - self.radius then
        self.position.y = worldHeight - self.radius
        self.velocity.y = -self.velocity.y * self.bounceFactor
    end
end

-- Check if the ball is in a hole
function BallManager:checkHole()
    -- Check cells under the ball for a hole
    for y = self.position.y - 1, self.position.y + 1 do
        for x = self.position.x - 1, self.position.x + 1 do
            local cellType = self.cellWorld:getCell(x, y)
            if cellType == 90 then  -- Hole cell type
                return true
            end
        end
    end
    
    return false
end

-- Draw the ball and aiming line
function BallManager:draw()
    if not self.active then return end
    
    local cellSize = self.cellWorld.cellSize
    local screenX = self.position.x * cellSize
    local screenY = self.position.y * cellSize
    local screenRadius = self.radius * cellSize
    
    -- Draw ball shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", screenX + 2, screenY + 2, screenRadius)
    
    -- Draw ball based on type
    if self.type == BallTypes.STANDARD then
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.type == BallTypes.EXPLOSIVE then
        love.graphics.setColor(1, 0.2, 0.2, 1)
    elseif self.type == BallTypes.STICKY then
        love.graphics.setColor(0.2, 1, 0.2, 1)
    elseif self.type == BallTypes.MINING then
        love.graphics.setColor(0.8, 0.8, 0.2, 1)
    end
    
    love.graphics.circle("fill", screenX, screenY, screenRadius)
    
    -- Draw ball highlight
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle("fill", screenX - screenRadius/3, screenY - screenRadius/3, screenRadius/4)
    
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
    
    -- Draw ability cooldown indicator
    if self.abilityCooldown > 0 then
        love.graphics.setColor(1, 0.5, 0, 0.8)
        love.graphics.print(string.format("Ability: %.1fs", self.abilityCooldown / 60), 10, 90)
    else
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.print("Ability: Ready", 10, 90)
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
    return math.abs(self.velocity.x) > 0.01 or math.abs(self.velocity.y) > 0.01
end

-- Check if the ball is currently aiming
function BallManager:isCurrentlyAiming()
    return self.isAiming
end

return BallManager
