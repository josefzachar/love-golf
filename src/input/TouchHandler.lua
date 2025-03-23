-- TouchHandler.lua - Handles touch input for mobile devices

local TouchHandler = {}
TouchHandler.__index = TouchHandler

function TouchHandler.new(inputHandler)
    local self = setmetatable({}, TouchHandler)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    -- Touch state
    self.touches = {}
    self.multiTouch = false
    
    return self
end

-- Touch pressed callback
function TouchHandler:touchpressed(id, x, y)
    self.touches[id] = {x = x, y = y}
    
    -- Check if we have multiple touches
    local touchCount = 0
    for _ in pairs(self.touches) do touchCount = touchCount + 1 end
    
    if touchCount > 1 then
        self.multiTouch = true
    else
        -- Single touch - similar to mouse press
        self.inputHandler.mouseHandler:mousepressed(x, y, 1)
    end
end

-- Touch moved callback
function TouchHandler:touchmoved(id, x, y)
    if not self.touches[id] then return end
    
    local oldX, oldY = self.touches[id].x, self.touches[id].y
    self.touches[id].x, self.touches[id].y = x, y
    
    if self.multiTouch then
        -- Handle pinch-to-zoom and two-finger pan
        -- This is a simplified implementation
        local touches = {}
        for id, pos in pairs(self.touches) do
            table.insert(touches, pos)
        end
        
        if #touches >= 2 then
            -- Calculate distance between touches
            local dx1 = touches[1].x - touches[2].x
            local dy1 = touches[1].y - touches[2].y
            local dist1 = math.sqrt(dx1*dx1 + dy1*dy1)
            
            -- TODO: Implement proper pinch-to-zoom
        end
    else
        -- Single touch movement - similar to mouse movement
        local dx = x - oldX
        local dy = y - oldY
        self.inputHandler.mouseX, self.inputHandler.mouseY = x, y
        self.inputHandler.mouseHandler:mousemoved(x, y, dx, dy)
    end
end

-- Touch released callback
function TouchHandler:touchreleased(id, x, y)
    self.touches[id] = nil
    
    -- Check if we still have multiple touches
    local touchCount = 0
    for _ in pairs(self.touches) do touchCount = touchCount + 1 end
    
    if touchCount <= 1 then
        self.multiTouch = false
    end
    
    -- If we released all touches, treat as mouse release
    if touchCount == 0 then
        self.inputHandler.mouseHandler:mousereleased(x, y, 1)
    end
end

return TouchHandler
