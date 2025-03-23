-- MouseHandler.lua - Handles mouse input

local MouseHandler = {}
MouseHandler.__index = MouseHandler

function MouseHandler.new(inputHandler)
    local self = setmetatable({}, MouseHandler)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    return self
end

-- Mouse pressed callback
function MouseHandler:mousepressed(x, y, button)
    if button == 1 then  -- Left mouse button
        self:handleLeftMousePressed(x, y)
    elseif button == 2 then  -- Right mouse button
        self:handleRightMousePressed(x, y)
    elseif button == 3 then  -- Middle mouse button
        self:handleMiddleMousePressed(x, y)
    end
end

-- Mouse moved callback
function MouseHandler:mousemoved(x, y, dx, dy)
    -- Handle camera dragging with middle mouse button
    self.inputHandler.cameraController:handleMouseDrag(x, y, dx, dy)
end

-- Mouse released callback
function MouseHandler:mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
        self:handleLeftMouseReleased(x, y)
    elseif button == 3 then  -- Middle mouse button
        self:handleMiddleMouseReleased(x, y)
    end
    -- Right mouse button (2) doesn't need any special handling on release
    -- since it's just used for cycling brush sizes on press
end

-- Mouse wheel moved callback
function MouseHandler:wheelmoved(x, y)
    -- Delegate to camera controller for zooming
    self.inputHandler.cameraController:handleWheelZoom(y)
    
    -- Horizontal scrolling with wheel could be implemented here if needed
    if x ~= 0 and self.inputHandler.debug then
        print("Horizontal wheel: " .. x)
    end
end

-- Handle left mouse button press
function MouseHandler:handleLeftMousePressed(x, y)
    local inputHandler = self.inputHandler
    
    inputHandler.mouseDown = true
    inputHandler.dragStartX = x
    inputHandler.dragStartY = y
    
    -- In shoot mode, start aiming with the standard ball
    if inputHandler.mode == "shoot" and inputHandler.ballManager then
        if inputHandler.debug then
            print("Mouse pressed in shoot mode at " .. x .. ", " .. y)
            print("Checking if ball can be shot...")
            if inputHandler.ballManager.canShoot then
                print("Can shoot: " .. tostring(inputHandler.ballManager:canShoot()))
            else
                print("canShoot method not found on ballManager")
            end
        end
        
        -- Always try to start aiming, even if the ball can't be shot yet
        -- This makes the aiming more responsive
        if inputHandler.ballManager.startAiming then
            inputHandler.ballManager:startAiming(x, y)
            if inputHandler.debug then
                print("Started aiming at " .. x .. ", " .. y)
            end
            return
        else
            if inputHandler.debug then
                print("startAiming method not found on ballManager")
            end
        end
    end
    
    -- In spray mode, place cells
    if inputHandler.mode == "spray" and inputHandler.camera and inputHandler.camera.screenToWorld then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = inputHandler.camera:screenToWorld(x, y)
        
        -- Place cells at the cursor position
        inputHandler.materialHandler:placeCells(worldX, worldY)
    end
end

-- Handle right mouse button press
function MouseHandler:handleRightMousePressed(x, y)
    local inputHandler = self.inputHandler
    
    -- Cycle through brush sizes with right mouse button (only in spray mode)
    if inputHandler.mode == "spray" then
        inputHandler.materialHandler:cycleBrushSize()
    end
end

-- Handle middle mouse button press
function MouseHandler:handleMiddleMousePressed(x, y)
    -- Activate camera control with middle mouse button
    self.inputHandler.cameraController:startDrag(x, y)
end

-- Handle left mouse button release
function MouseHandler:handleLeftMouseReleased(x, y)
    local inputHandler = self.inputHandler
    
    inputHandler.mouseDown = false
    
    -- In shoot mode, execute the shot if aiming
    if inputHandler.mode == "shoot" and inputHandler.ballManager and 
       inputHandler.ballManager.isCurrentlyAiming and inputHandler.ballManager.shoot and
       inputHandler.ballManager:isCurrentlyAiming() then
        -- Execute the shot
        local success = inputHandler.ballManager:shoot()
        
        if inputHandler.debug then
            print("Shot executed: " .. tostring(success))
        end
        
        -- Record the shot in game state if available
        if success and _G.gameState and _G.gameState.recordShot then
            _G.gameState:recordShot()
        end
    end
end

-- Handle middle mouse button release
function MouseHandler:handleMiddleMouseReleased(x, y)
    -- End camera control
    self.inputHandler.cameraController:endDrag()
end

return MouseHandler
