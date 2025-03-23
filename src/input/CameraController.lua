-- CameraController.lua - Handles camera movement, zooming, and edge scrolling

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new(inputHandler)
    local self = setmetatable({}, CameraController)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    -- Edge scrolling settings
    self.edgeScrolling = {
        enabled = true,
        edgeSize = 50,  -- Pixels from edge that triggers scrolling
        speed = 300,    -- Base speed in pixels per second
        centerBox = {   -- Box in the center where no scrolling happens (percentage of screen)
            width = 0.5,
            height = 0.5
        }
    }
    
    -- Camera control
    self.cameraControl = {
        active = false,
        lastX = 0,
        lastY = 0
    }
    
    return self
end

-- Update camera controller
function CameraController:update(dt)
    -- Handle edge scrolling if enabled and not actively dragging with middle mouse
    if self.edgeScrolling.enabled and not self.cameraControl.active and self.inputHandler.camera then
        self:handleEdgeScrolling(dt)
    end
end

-- Handle edge scrolling based on mouse position
function CameraController:handleEdgeScrolling(dt)
    local camera = self.inputHandler.camera
    local mouseX, mouseY = self.inputHandler.mouseX, self.inputHandler.mouseY
    
    -- Get screen dimensions
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate center box dimensions
    local centerBoxWidth = screenWidth * self.edgeScrolling.centerBox.width
    local centerBoxHeight = screenHeight * self.edgeScrolling.centerBox.height
    local centerBoxLeft = (screenWidth - centerBoxWidth) / 2
    local centerBoxRight = centerBoxLeft + centerBoxWidth
    local centerBoxTop = (screenHeight - centerBoxHeight) / 2
    local centerBoxBottom = centerBoxTop + centerBoxHeight
    
    -- Calculate edge boundaries
    local edgeSize = self.edgeScrolling.edgeSize
    
    -- Base speed adjusted by camera zoom (move faster when zoomed out)
    local cameraScale = camera.scale or 1
    local speed = self.edgeScrolling.speed * dt / cameraScale
    
    -- Check if mouse is outside center box but inside screen
    local moveX, moveY = 0, 0
    
    -- Horizontal scrolling
    if mouseX < centerBoxLeft and mouseX > edgeSize then
        -- Left scroll zone (between edge and center box)
        local factor = (centerBoxLeft - mouseX) / (centerBoxLeft - edgeSize)
        moveX = -speed * factor
    elseif mouseX < edgeSize then
        -- Far left edge - maximum speed
        moveX = -speed
    elseif mouseX > centerBoxRight and mouseX < screenWidth - edgeSize then
        -- Right scroll zone
        local factor = (mouseX - centerBoxRight) / (screenWidth - edgeSize - centerBoxRight)
        moveX = speed * factor
    elseif mouseX > screenWidth - edgeSize then
        -- Far right edge - maximum speed
        moveX = speed
    end
    
    -- Vertical scrolling
    if mouseY < centerBoxTop and mouseY > edgeSize then
        -- Top scroll zone
        local factor = (centerBoxTop - mouseY) / (centerBoxTop - edgeSize)
        moveY = -speed * factor
    elseif mouseY < edgeSize then
        -- Far top edge - maximum speed
        moveY = -speed
    elseif mouseY > centerBoxBottom and mouseY < screenHeight - edgeSize then
        -- Bottom scroll zone
        local factor = (mouseY - centerBoxBottom) / (screenHeight - edgeSize - centerBoxBottom)
        moveY = speed * factor
    elseif mouseY > screenHeight - edgeSize then
        -- Far bottom edge - maximum speed
        moveY = speed
    end
    
    -- Apply camera movement if needed
    if moveX ~= 0 or moveY ~= 0 then
        -- Disable camera target following when edge scrolling
        if camera.disableFollowTarget then
            camera:disableFollowTarget()
        end
        
        -- Move camera
        camera:setTarget(camera.targetX + moveX, camera.targetY + moveY)
    end
end

-- Handle camera movement with keyboard
function CameraController:handleKeyboardMovement(dt)
    local camera = self.inputHandler.camera
    local keys = self.inputHandler.keys
    local prevKeys = self.inputHandler.prevKeys
    local debug = self.inputHandler.debug
    
    -- Camera movement with arrow keys
    local cameraScale = camera.scale or 1
    local cameraSpeed = 200 * dt / cameraScale
    
    if camera.setTarget and camera.targetX and camera.targetY then
        -- Check if any movement key is pressed
        local isMoving = keys["up"] or keys["w"] or 
                         keys["down"] or keys["s"] or
                         keys["left"] or keys["a"] or
                         keys["right"] or keys["d"]
        
        -- Disable camera target following when arrow keys are pressed
        if isMoving and camera.disableFollowTarget then
            camera:disableFollowTarget()
        end
        
        if keys["up"] or keys["w"] then
            -- Only print when key is first pressed
            if not (prevKeys["up"] or prevKeys["w"]) and debug then
                print("Moving up")
            end
            camera:setTarget(camera.targetX, camera.targetY - cameraSpeed)
        end
        if keys["down"] or keys["s"] then
            -- Only print when key is first pressed
            if not (prevKeys["down"] or prevKeys["s"]) and debug then
                print("Moving down")
            end
            camera:setTarget(camera.targetX, camera.targetY + cameraSpeed)
        end
        if keys["left"] or keys["a"] then
            -- Only print when key is first pressed
            if not (prevKeys["left"] or prevKeys["a"]) and debug then
                print("Moving left")
            end
            camera:setTarget(camera.targetX - cameraSpeed, camera.targetY)
        end
        if keys["right"] or keys["d"] then
            -- Only print when key is first pressed
            if not (prevKeys["right"] or prevKeys["d"]) and debug then
                print("Moving right")
            end
            camera:setTarget(camera.targetX + cameraSpeed, camera.targetY)
        end
    end
end

-- Handle camera zooming with keyboard
function CameraController:handleKeyboardZoom()
    local camera = self.inputHandler.camera
    local keys = self.inputHandler.keys
    local prevKeys = self.inputHandler.prevKeys
    local debug = self.inputHandler.debug
    
    if keys["="] or keys["+"] then
        -- Only print when key is first pressed
        if not (prevKeys["="] or prevKeys["+"]) and debug then
            print("Zooming in")
        end
        camera:zoomIn(1.01)
    end
    if keys["-"] then
        -- Only print when key is first pressed
        if not prevKeys["-"] and debug then
            print("Zooming out")
        end
        camera:zoomOut(1.01)
    end
end

-- Handle mouse wheel zooming
function CameraController:handleWheelZoom(y)
    local camera = self.inputHandler.camera
    local debug = self.inputHandler.debug
    
    if not camera then return end
    
    if y > 0 then
        -- Zoom in (wheel up)
        camera:zoomIn(1.1)
        if debug then
            print("Zooming in (wheel)")
        end
    elseif y < 0 then
        -- Zoom out (wheel down)
        camera:zoomOut(1.1)
        if debug then
            print("Zooming out (wheel)")
        end
    end
end

-- Handle camera dragging with middle mouse button
function CameraController:handleMouseDrag(x, y, dx, dy)
    local camera = self.inputHandler.camera
    
    if self.cameraControl.active and camera then
        -- Calculate the movement in world space (accounting for zoom)
        local worldDX = dx / camera.scale
        local worldDY = dy / camera.scale
        
        -- Move the camera in the opposite direction of the mouse movement
        camera:setTarget(camera.targetX - worldDX, camera.targetY - worldDY)
        
        -- Update last position
        self.cameraControl.lastX = x
        self.cameraControl.lastY = y
    end
end

-- Start camera dragging
function CameraController:startDrag(x, y)
    self.cameraControl.active = true
    self.cameraControl.lastX = x
    self.cameraControl.lastY = y
    
    -- Disable camera target following when starting to drag
    if self.inputHandler.camera and self.inputHandler.camera.disableFollowTarget then
        self.inputHandler.camera:disableFollowTarget()
    end
end

-- End camera dragging
function CameraController:endDrag()
    self.cameraControl.active = false
end

-- Reset camera to focus on current ball
function CameraController:resetCamera()
    local camera = self.inputHandler.camera
    local ballManager = self.inputHandler.ballManager
    
    if camera and camera.focusOn and ballManager.getCurrentBall then
        local ball = ballManager:getCurrentBall()
        if ball and ball.active then
            camera:focusOn(ball.x, ball.y)
        end
    end
end

-- Check if camera is being dragged
function CameraController:isDragging()
    return self.cameraControl.active
end

return CameraController
