-- GolfBall.lua - Specialized ball for golf mechanics
-- Inspired by the Godot implementation from https://github.com/josefzachar/golf-game/

local GolfBall = {}
GolfBall.__index = GolfBall

-- Create a new golf ball
function GolfBall.new(ballManager)
    local self = setmetatable({}, GolfBall)
    
    -- Reference to the ball manager
    self.ballManager = ballManager
    
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
    
    -- Visual properties
    self.color = {1, 1, 1, 1}  -- White golf ball
    self.pattern = {  -- Golf ball pattern (dimples)
        {0, 1, 1, 1, 0},
        {1, 0, 1, 0, 1},
        {1, 1, 0, 1, 1},
        {1, 0, 1, 0, 1},
        {0, 1, 1, 1, 0}
    }
    
    -- Ball pixels for more detailed rendering
    self.ballPixels = {}
    self:initializeBallPixels()
    
    return self
end

-- Initialize the pixels that make up our larger ball (for detailed rendering)
function GolfBall:initializeBallPixels()
    self.ballPixels = {}
    
    -- Create a circular pattern of pixels
    local pixelSize = 2  -- Size of each component pixel
    local visualRadius = 5  -- Visual radius in pixels
    
    -- Create the ball pixel pattern
    for x = -visualRadius-1, visualRadius+1 do
        for y = -visualRadius-1, visualRadius+1 do
            local dist = math.sqrt(x*x + y*y)
            if dist <= visualRadius then
                -- Determine pattern based on position (create some pattern)
                local pattern = ((x + y) % 2 == 0)  -- Checkerboard pattern
                
                -- Add this pixel to our ball
                table.insert(self.ballPixels, {
                    offset = {x = x * pixelSize, y = y * pixelSize},
                    size = pixelSize,
                    pattern = pattern
                })
            end
        end
    end
end

-- Start aiming the golf ball
function GolfBall:startAim(x, y)
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
function GolfBall:updateAim(x, y)
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
    -- math.atan2 returns angles in the range of -π to π, which covers the full circle
    self.shotAngle = math.atan2(dy, dx)
    
    -- Calculate power based on distance from ball to current mouse position
    -- This ensures power is based on actual distance from ball, not just drag distance
    local distanceFromBall = math.sqrt(dx*dx + dy*dy)
    
    -- Power increases as you move further from the ball
    self.shotPower = math.min(distanceFromBall / 2, self.maxPower)
end

-- Execute the golf shot
function GolfBall:shoot()
    if not self.isAiming then return false end
    
    -- Apply velocity in the opposite direction of the aim line with much higher power multiplier
    self.ballManager.velocity.x = -math.cos(self.shotAngle) * self.shotPower * 200 -- Dramatically increased power multiplier
    self.ballManager.velocity.y = -math.sin(self.shotAngle) * self.shotPower * 200 -- Dramatically increased power multiplier
    
    -- Set rotation speed based on horizontal velocity
    self.rotationSpeed = -self.ballManager.velocity.x * 0.1
    
    -- Reset aiming state
    self.isAiming = false
    
    return true
end

-- Cancel the current aim
function GolfBall:cancelAim()
    self.isAiming = false
    return true
end

-- Check if aiming is active
function GolfBall:isAimActive()
    return self.isAiming
end

-- Update the golf ball
function GolfBall:update(dt)
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
    
    -- Always apply gravity to the golf ball, even when it's not moving much
    -- This ensures the ball reacts to gravity properly
    if not self.isAiming then
        -- Apply stronger gravity for more realistic physics
        self.ballManager.velocity.y = self.ballManager.velocity.y + self.ballManager.gravity * 1.5
    end
end

-- Draw the golf ball
function GolfBall:draw()
    local cellSize = self.ballManager.cellWorld.cellSize
    local screenX = self.ballManager.position.x * cellSize
    local screenY = self.ballManager.position.y * cellSize
    local screenRadius = self.ballManager.radius * cellSize
    
    -- Draw ball shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", screenX + 2, screenY + 2, screenRadius)
    
    -- Draw the larger pixelated rotating ball
    self:drawLargeRotatingBall(screenX, screenY, screenRadius)
    
    -- Draw aiming line if aiming
    if self.isAiming then
        self:drawAimingLine(screenX, screenY)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw larger ball made of pixels that rotates as a cohesive unit
function GolfBall:drawLargeRotatingBall(position_x, position_y, radius)
    -- Main ball color
    local mainColor = {1, 1, 1, 1}  -- White
    
    -- Create a slightly darker variant for pattern
    local patternColor = {0.7, 0.7, 0.7, 1}
    
    -- Create a lighter variant for highlights
    local highlightColor = {1, 1, 1, 1}
    
    -- Center of the ball in world coordinates
    local center = {
        x = position_x,
        y = position_y
    }
    
    -- Save the current transform
    love.graphics.push()
    
    -- Translate to the ball's position
    love.graphics.translate(center.x, center.y)
    
    -- Rotate the ball
    love.graphics.rotate(self.rotation)
    
    -- Draw each pixel of the large ball
    for _, pixel in ipairs(self.ballPixels) do
        -- Calculate pixel position after rotation (rotation is already applied by the transform)
        local pixel_pos = {
            x = pixel.offset.x,
            y = pixel.offset.y
        }
        
        -- Determine color based on pattern
        local pixelColor
        if pixel.pattern then
            pixelColor = mainColor
        else
            pixelColor = patternColor
        end
        
        -- Create a small 3D effect with highlight - top-left quadrant gets highlight
        local normalizedOffset = {
            x = pixel.offset.x / radius,
            y = pixel.offset.y / radius
        }
        if normalizedOffset.x < -0.3 and normalizedOffset.y < -0.3 then
            pixelColor = highlightColor
        end
        
        -- Draw pixel as a rectangle
        love.graphics.setColor(pixelColor)
        love.graphics.rectangle(
            "fill",
            pixel_pos.x - pixel.size/2,
            pixel_pos.y - pixel.size/2,
            pixel.size,
            pixel.size
        )
    end
    
    -- Restore the transform
    love.graphics.pop()
end

-- Draw the aiming line and arrow
function GolfBall:drawAimingLine(screenX, screenY)
    -- Draw the power/direction indicator
    love.graphics.setColor(1, 0.5, 0, 0.8)
    love.graphics.setLineWidth(2)
    
    -- Calculate the end point of the shot (in the opposite direction)
    local lineLength = self.shotPower * 20
    local endX = screenX - math.cos(self.shotAngle) * lineLength
    local endY = screenY - math.sin(self.shotAngle) * lineLength
    
    -- Draw pixelated dotted line for the shot direction
    self:drawPixelatedDottedLine(
        screenX, screenY,
        endX, endY,
        {1, 0, 0, 0.8},  -- Red color
        8, 12, 4         -- Dash length, gap length, thickness
    )
    
    -- Draw shot prediction line in white
    local oppositeEndX = screenX + math.cos(self.shotAngle) * lineLength
    local oppositeEndY = screenY + math.sin(self.shotAngle) * lineLength
    self:drawPixelatedDottedLine(
        screenX, screenY,
        oppositeEndX, oppositeEndY,
        {1, 1, 1, 0.9},  -- White color
        8, 12, 4         -- Dash length, gap length, thickness
    )
    
    -- Draw pixelated arrowhead at the end
    self:drawPixelatedArrowhead(
        endX, endY,
        {x = -math.cos(self.shotAngle), y = -math.sin(self.shotAngle)},
        {1, 1, 1, 0.8},  -- White color
        8                -- Size
    )
    
    -- Draw power indicator
    local powerPercentage = self.shotPower / self.maxPower
    love.graphics.setColor(1, 1 - powerPercentage, 0, 0.8)
    love.graphics.print(string.format("Power: %.0f%%", powerPercentage * 100), 10, 70)
end

-- Draw a pixelated dotted line
function GolfBall:drawPixelatedDottedLine(startX, startY, endX, endY, color, dashLength, gapLength, thickness)
    love.graphics.setColor(color)
    
    local direction = {
        x = endX - startX,
        y = endY - startY
    }
    local distance = math.sqrt(direction.x^2 + direction.y^2)
    
    if distance > 0 then
        direction.x = direction.x / distance
        direction.y = direction.y / distance
    else
        return
    end
    
    local currentDistance = 0
    
    -- Use larger pixel sizes for more pronounced pixelated look
    local pixelSizeLarge = 4
    dashLength = math.max(pixelSizeLarge, dashLength * 2)  -- Make dashes larger
    gapLength = math.max(pixelSizeLarge, gapLength * 2)    -- Make gaps larger
    
    -- Draw individual square "dots" for a chunkier look
    while currentDistance < distance do
        local dotPosX = startX + direction.x * currentDistance
        local dotPosY = startY + direction.y * currentDistance
        
        -- Round to pixel grid
        dotPosX = math.floor(dotPosX / pixelSizeLarge) * pixelSizeLarge
        dotPosY = math.floor(dotPosY / pixelSizeLarge) * pixelSizeLarge
        
        -- Draw a single large square "dot"
        local dotSize = math.max(thickness * 3, 6)  -- Significantly larger dots
        love.graphics.rectangle(
            "fill",
            dotPosX - dotSize/2,
            dotPosY - dotSize/2,
            dotSize,
            dotSize
        )
        
        -- Move to next dot position
        currentDistance = currentDistance + dashLength + gapLength
    end
end

-- Draw a pixelated arrowhead
function GolfBall:drawPixelatedArrowhead(posX, posY, direction, color, size)
    love.graphics.setColor(color)
    
    -- Calculate points for a pixelated arrow
    local backDirection = {
        x = -direction.x,
        y = -direction.y
    }
    
    -- Rotate back direction by 45 degrees for right point
    local rightDirection = {
        x = backDirection.x * math.cos(math.pi/4) - backDirection.y * math.sin(math.pi/4),
        y = backDirection.x * math.sin(math.pi/4) + backDirection.y * math.cos(math.pi/4)
    }
    
    -- Rotate back direction by -45 degrees for left point
    local leftDirection = {
        x = backDirection.x * math.cos(-math.pi/4) - backDirection.y * math.sin(-math.pi/4),
        y = backDirection.x * math.sin(-math.pi/4) + backDirection.y * math.cos(-math.pi/4)
    }
    
    -- Scale based on pixel size
    size = math.max(3, size * 2)
    
    local rightPoint = {
        x = posX + rightDirection.x * size,
        y = posY + rightDirection.y * size
    }
    
    local leftPoint = {
        x = posX + leftDirection.x * size,
        y = posY + leftDirection.y * size
    }
    
    -- Draw the triangle
    love.graphics.polygon(
        "fill",
        posX, posY,
        rightPoint.x, rightPoint.y,
        leftPoint.x, leftPoint.y
    )
end

return GolfBall
