-- Camera.lua - Handles camera movement and transformations

local Camera = {}
Camera.__index = Camera

-- Create a new camera
function Camera.new()
    local self = setmetatable({}, Camera)
    
    -- Camera position
    self.x = 0
    self.y = 0
    
    -- Target position (for smooth following)
    self.targetX = 0
    self.targetY = 0
    
    -- Camera zoom
    self.scale = 1.0
    self.targetScale = 1.0
    
    -- Camera movement settings
    self.smoothness = 0.1  -- Lower = smoother (0-1)
    self.zoomSmoothness = 0.1
    self.bounds = nil  -- Camera bounds (if nil, no bounds)
    
    -- Shake effect
    self.shakeAmount = 0
    self.shakeDuration = 0
    self.shakeFrequency = 0.5
    self.shakeTime = 0
    
    return self
end

-- Set camera position
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
    self.targetX = x
    self.targetY = y
end

-- Set camera offset (for centering in window)
function Camera:setOffset(offsetX, offsetY)
    self.offsetX = offsetX
    self.offsetY = offsetY
end

-- Set camera target position (for smooth following)
function Camera:setTarget(x, y)
    self.targetX = x
    self.targetY = y
end

-- Focus camera on a position
function Camera:focusOn(x, y)
    self:setTarget(x, y)
end

-- Set camera zoom
function Camera:setZoom(scale)
    self.scale = scale
    self.targetScale = scale
end

-- Set camera target zoom (for smooth zooming)
function Camera:setTargetZoom(scale)
    self.targetScale = math.max(0.1, scale)  -- Prevent negative or zero zoom
end

-- Set camera bounds
function Camera:setBounds(left, top, right, bottom)
    self.bounds = {
        left = left,
        top = top,
        right = right,
        bottom = bottom
    }
end

-- Apply camera shake effect
function Camera:shake(amount, duration)
    self.shakeAmount = amount
    self.shakeDuration = duration
    self.shakeTime = 0
end

-- Flag to control automatic following
local followTarget = true

-- Update camera position and effects
function Camera:update(dt, target)
    -- Update shake effect
    if self.shakeDuration > 0 then
        self.shakeTime = self.shakeTime + dt
        self.shakeDuration = self.shakeDuration - dt
        if self.shakeDuration <= 0 then
            self.shakeAmount = 0
        end
    end
    
    -- Update target position if a target is provided AND followTarget is true
    if target and followTarget then
        self:setTarget(target.x, target.y)
    end
    
    -- Smooth camera movement
    self.x = self.x + (self.targetX - self.x) * self.smoothness
    self.y = self.y + (self.targetY - self.y) * self.smoothness
    
    -- Smooth camera zoom
    self.scale = self.scale + (self.targetScale - self.scale) * self.zoomSmoothness
    
    -- Apply camera bounds if set
    if self.bounds then
        local halfScreenWidth = love.graphics.getWidth() / (2 * self.scale)
        local halfScreenHeight = love.graphics.getHeight() / (2 * self.scale)
        
        -- Adjust for screen size and zoom
        self.x = math.max(self.bounds.left + halfScreenWidth, 
                          math.min(self.bounds.right - halfScreenWidth, self.x))
        self.y = math.max(self.bounds.top + halfScreenHeight, 
                          math.min(self.bounds.bottom - halfScreenHeight, self.y))
    end
end

-- Toggle target following
function Camera:toggleFollowTarget()
    followTarget = not followTarget
    print("Camera follow target:", followTarget)
    return followTarget
end

-- Disable target following
function Camera:disableFollowTarget()
    followTarget = false
    print("Camera follow target disabled")
end

-- Enable target following
function Camera:enableFollowTarget()
    followTarget = true
    print("Camera follow target enabled")
end

-- Start camera transformation
function Camera:set()
    love.graphics.push()
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate shake offset
    local shakeOffsetX = 0
    local shakeOffsetY = 0
    
    if self.shakeAmount > 0 then
        local shakeAngle = self.shakeTime * self.shakeFrequency
        shakeOffsetX = math.sin(shakeAngle * 17) * self.shakeAmount
        shakeOffsetY = math.cos(shakeAngle * 13) * self.shakeAmount
    end
    
    -- Use offset if available, otherwise use screen center
    local offsetX = self.offsetX or screenWidth / 2
    local offsetY = self.offsetY or screenHeight / 2
    
    -- Apply transformations
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(self.scale)
    love.graphics.translate(-self.x + shakeOffsetX, -self.y + shakeOffsetY)
end

-- End camera transformation
function Camera:unset()
    love.graphics.pop()
end

-- Convert screen coordinates to world coordinates
function Camera:screenToWorld(screenX, screenY)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Use offset if available, otherwise use screen center
    local offsetX = self.offsetX or screenWidth / 2
    local offsetY = self.offsetY or screenHeight / 2
    
    local worldX = (screenX - offsetX) / self.scale + self.x
    local worldY = (screenY - offsetY) / self.scale + self.y
    
    -- Debug output
    print("screenToWorld:", screenX, screenY, "->", worldX, worldY)
    print("Camera:", self.x, self.y, "Scale:", self.scale, "Offset:", offsetX, offsetY)
    
    return worldX, worldY
end

-- Convert world coordinates to screen coordinates
function Camera:worldToScreen(worldX, worldY)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Use offset if available, otherwise use screen center
    local offsetX = self.offsetX or screenWidth / 2
    local offsetY = self.offsetY or screenHeight / 2
    
    local screenX = (worldX - self.x) * self.scale + offsetX
    local screenY = (worldY - self.y) * self.scale + offsetY
    
    -- Debug output
    print("worldToScreen:", worldX, worldY, "->", screenX, screenY)
    
    return screenX, screenY
end

-- Zoom in by a factor
function Camera:zoomIn(factor)
    self:setTargetZoom(self.targetScale * factor)
end

-- Zoom out by a factor
function Camera:zoomOut(factor)
    self:setTargetZoom(self.targetScale / factor)
end

return Camera
