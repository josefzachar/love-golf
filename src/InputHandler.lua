-- InputHandler.lua - Handles user input for the game
-- Simplified to only include the standard ball type

local InputHandler = {}
InputHandler.__index = InputHandler

-- Create a new input handler
function InputHandler.new(ballManager, camera)
    local self = setmetatable({}, InputHandler)
    
    -- References to other modules
    self.ballManager = ballManager or {}
    self.camera = camera or {}
    self.cellWorld = _G.cellWorld  -- Access the global cellWorld
    
    -- Input state
    self.mouseX = 0
    self.mouseY = 0
    self.mouseDown = false
    self.dragStartX = 0
    self.dragStartY = 0
    self.isDragging = false
    
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
    
    -- Material placement
    self.currentMaterial = 20  -- Default to sand (CellTypes.SAND)
    self.brushSize = 3
    self.isDrawing = false
    
    -- Mode switching
    self.mode = "shoot"  -- "spray" or "shoot" - Default to shoot mode
    
    -- Custom cursor
    self.showCustomCursor = true
    self.cursorSize = 16  -- Size of the cursor in pixels
    
    -- Material indicator
    self.materialIndicator = {
        x = 20,
        y = 150,
        width = 40,
        height = 40,
        padding = 5
    }
    
    -- Camera control
    self.cameraControl = {
        active = false,
        lastX = 0,
        lastY = 0
    }
    
    -- Key states
    self.keys = {}
    self.prevKeys = {} -- Track previous key states
    
    -- Touch support for mobile
    self.touches = {}
    self.multiTouch = false
    
    -- Hide the system cursor if we're using a custom one
    if self.showCustomCursor then
        love.mouse.setVisible(false)
    end
    
    -- Debug flag
    self.debug = true
    
    return self
end

-- Update input state
function InputHandler:update(dt)
    -- Store previous key states
    self.prevKeys = {}
    for k, v in pairs(self.keys) do
        self.prevKeys[k] = v
    end
    -- Update mouse position
    local oldMouseX, oldMouseY = self.mouseX, self.mouseY
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
    -- Handle edge scrolling if enabled and not actively dragging with middle mouse
    if self.edgeScrolling.enabled and not self.cameraControl.active and self.camera then
        self:handleEdgeScrolling(dt)
    end
    
    -- Handle normal mouse dragging for cell placement
    if self.mouseDown and not self.cameraControl.active and self.mode == "spray" then
        -- Convert screen coordinates to world coordinates
        if self.camera and self.camera.screenToWorld then
            local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)
            
            -- Place cells at the cursor position
            self:placeCells(worldX, worldY)
        end
    end
    
    -- Update aiming if in shoot mode and aiming
    if self.mode == "shoot" and self.ballManager and 
       self.ballManager.isCurrentlyAiming and self.ballManager.updateAim and
       self.ballManager:isCurrentlyAiming() then
        -- Update the aim with the current mouse position
        self.ballManager:updateAim(self.mouseX, self.mouseY)
        
        if self.debug then
            print("Aiming update: Mouse at " .. self.mouseX .. ", " .. self.mouseY)
        end
    end
    
    -- Note: Camera control is now handled directly in love.mousemoved
    -- to provide immediate response without smoothing
    
    -- Handle keyboard input
    self:handleKeyboardInput(dt)
end

-- Handle keyboard input
function InputHandler:handleKeyboardInput(dt)
    -- Check if camera is available
    if self.camera and self.camera.zoomIn then
        -- Camera zoom
        if self.keys["="] or self.keys["+"] then
            -- Only print when key is first pressed
            if not (self.prevKeys["="] or self.prevKeys["+"]) then
                print("Zooming in")
            end
            self.camera:zoomIn(1.01)
        end
        if self.keys["-"] then
            -- Only print when key is first pressed
            if not self.prevKeys["-"] then
                print("Zooming out")
            end
            self.camera:zoomOut(1.01)
        end
        
        -- Camera movement with arrow keys
        local cameraScale = self.camera.scale or 1
        local cameraSpeed = 200 * dt / cameraScale
        
        if self.camera.setTarget and self.camera.targetX and self.camera.targetY then
            -- Check if any movement key is pressed
            local isMoving = self.keys["up"] or self.keys["w"] or 
                             self.keys["down"] or self.keys["s"] or
                             self.keys["left"] or self.keys["a"] or
                             self.keys["right"] or self.keys["d"]
            
            -- Disable camera target following when arrow keys are pressed
            if isMoving and self.camera.disableFollowTarget then
                self.camera:disableFollowTarget()
            end
            
            if self.keys["up"] or self.keys["w"] then
                -- Only print when key is first pressed
                if not (self.prevKeys["up"] or self.prevKeys["w"]) then
                    print("Moving up")
                end
                self.camera:setTarget(self.camera.targetX, self.camera.targetY - cameraSpeed)
            end
            if self.keys["down"] or self.keys["s"] then
                -- Only print when key is first pressed
                if not (self.prevKeys["down"] or self.prevKeys["s"]) then
                    print("Moving down")
                end
                self.camera:setTarget(self.camera.targetX, self.camera.targetY + cameraSpeed)
            end
            if self.keys["left"] or self.keys["a"] then
                -- Only print when key is first pressed
                if not (self.prevKeys["left"] or self.prevKeys["a"]) then
                    print("Moving left")
                end
                self.camera:setTarget(self.camera.targetX - cameraSpeed, self.camera.targetY)
            end
            if self.keys["right"] or self.keys["d"] then
                -- Only print when key is first pressed
                if not (self.prevKeys["right"] or self.prevKeys["d"]) then
                    print("Moving right")
                end
                self.camera:setTarget(self.camera.targetX + cameraSpeed, self.camera.targetY)
            end
        end
    end
    
    -- Reset camera
    if self.keys["c"] and self.camera and self.camera.focusOn and self.ballManager.getCurrentBall then
        self.keys["c"] = false  -- Reset key state
        local ball = self.ballManager:getCurrentBall()
        if ball and ball.active then
            self.camera:focusOn(ball.x, ball.y)
        end
    end
end

-- Handle edge scrolling based on mouse position
function InputHandler:handleEdgeScrolling(dt)
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
    local cameraScale = self.camera.scale or 1
    local speed = self.edgeScrolling.speed * dt / cameraScale
    
    -- Check if mouse is outside center box but inside screen
    local moveX, moveY = 0, 0
    
    -- Horizontal scrolling
    if self.mouseX < centerBoxLeft and self.mouseX > edgeSize then
        -- Left scroll zone (between edge and center box)
        local factor = (centerBoxLeft - self.mouseX) / (centerBoxLeft - edgeSize)
        moveX = -speed * factor
    elseif self.mouseX < edgeSize then
        -- Far left edge - maximum speed
        moveX = -speed
    elseif self.mouseX > centerBoxRight and self.mouseX < screenWidth - edgeSize then
        -- Right scroll zone
        local factor = (self.mouseX - centerBoxRight) / (screenWidth - edgeSize - centerBoxRight)
        moveX = speed * factor
    elseif self.mouseX > screenWidth - edgeSize then
        -- Far right edge - maximum speed
        moveX = speed
    end
    
    -- Vertical scrolling
    if self.mouseY < centerBoxTop and self.mouseY > edgeSize then
        -- Top scroll zone
        local factor = (centerBoxTop - self.mouseY) / (centerBoxTop - edgeSize)
        moveY = -speed * factor
    elseif self.mouseY < edgeSize then
        -- Far top edge - maximum speed
        moveY = -speed
    elseif self.mouseY > centerBoxBottom and self.mouseY < screenHeight - edgeSize then
        -- Bottom scroll zone
        local factor = (self.mouseY - centerBoxBottom) / (screenHeight - edgeSize - centerBoxBottom)
        moveY = speed * factor
    elseif self.mouseY > screenHeight - edgeSize then
        -- Far bottom edge - maximum speed
        moveY = speed
    end
    
    -- Apply camera movement if needed
    if moveX ~= 0 or moveY ~= 0 then
        -- Disable camera target following when edge scrolling
        if self.camera.disableFollowTarget then
            self.camera:disableFollowTarget()
        end
        
        -- Move camera
        self.camera:setTarget(self.camera.targetX + moveX, self.camera.targetY + moveY)
    end
end

-- Place cells at the given world coordinates
function InputHandler:placeCells(worldX, worldY)
    if not self.cellWorld or self.mode ~= "spray" then return end
    
    -- Convert world coordinates to cell coordinates
    -- Need to account for the fact that cell coordinates (1,1) correspond to world coordinates (0,0)
    local cellSize = self.cellWorld.cellSize
    local cellX = math.floor(worldX / cellSize) + 1
    local cellY = math.floor(worldY / cellSize) + 1
    
    -- Calculate the world position of the cell
    local worldCellX = (cellX - 1) * cellSize
    local worldCellY = (cellY - 1) * cellSize
    
    -- Place cells in a circle around the cursor
    local cellsPlaced = 0  -- Count how many cells we place
    
    for y = cellY - self.brushSize, cellY + self.brushSize do
        for x = cellX - self.brushSize, cellX + self.brushSize do
            local dx = x - cellX
            local dy = y - cellY
            local distSq = dx*dx + dy*dy
            
            if distSq <= self.brushSize * self.brushSize then
                -- Generate a unique color for each cell with subtle shade variations
                local color
                if self.currentMaterial == 20 then -- Sand
                    -- Subtle sand color variations (shades of tan)
                    local sandBase = 0.85  -- Base brightness
                    local variation = 0.15  -- Subtle variation
                    local shade = sandBase - variation/2 + math.random() * variation
                    color = {
                        shade + 0.1,  -- Red (slightly more)
                        shade,        -- Green (base)
                        shade - 0.4,  -- Blue (much less)
                        1
                    }
                elseif self.currentMaterial == 30 then -- Water
                    -- Subtle water color variations (shades of blue)
                    local waterBase = 0.7  -- Base brightness
                    local variation = 0.2  -- Subtle variation
                    local shade = waterBase - variation/2 + math.random() * variation
                    color = {
                        0.0,          -- Red (none)
                        shade - 0.3,  -- Green (some)
                        shade,        -- Blue (base)
                        0.8 + math.random() * 0.2  -- Alpha (slight variation)
                    }
                elseif self.currentMaterial == 40 then -- Fire
                    -- Subtle fire color variations (shades of orange/red)
                    local fireBase = 0.9  -- Base brightness
                    local variation = 0.1  -- Subtle variation
                    local shade = fireBase - variation/2 + math.random() * variation
                    color = {
                        shade,        -- Red (base)
                        shade - 0.6,  -- Green (much less)
                        0.0,          -- Blue (none)
                        1
                    }
                elseif self.currentMaterial == 10 then -- Stone
                    -- Subtle stone color variations (shades of gray)
                    local stoneBase = 0.5  -- Base brightness
                    local variation = 0.2  -- Subtle variation
                    local shade = stoneBase - variation/2 + math.random() * variation
                    color = {
                        shade,  -- Red
                        shade,  -- Green
                        shade,  -- Blue
                        1
                    }
                elseif self.currentMaterial == 11 then -- Dirt
                    -- Subtle dirt color variations (shades of brown)
                    local dirtBase = 0.6  -- Base brightness
                    local variation = 0.15  -- Subtle variation
                    local shade = dirtBase - variation/2 + math.random() * variation
                    color = {
                        shade,        -- Red (base)
                        shade - 0.3,  -- Green (less)
                        shade - 0.5,  -- Blue (much less)
                        1
                    }
                else
                    color = {1, 1, 1, 1}
                end
                
                -- Set the cell with its unique color
                -- Only if the cell is within bounds and not already occupied
                if x >= 1 and x <= self.cellWorld.width and 
                   y >= 1 and y <= self.cellWorld.height and
                   self.cellWorld:getCell(x, y) == 0 then
                    self.cellWorld:setCell(x, y, self.currentMaterial, color)
                    cellsPlaced = cellsPlaced + 1
                end
            end
        end
    end
    
    -- Update the cell data image
    self.cellWorld:updateCellDataImage()
end

-- Cycle through brush sizes
function InputHandler:cycleBrushSize()
    -- Define the three brush sizes
    local smallSize = 2
    local standardSize = 3
    local largeSize = 9
    
    -- Cycle through the sizes
    if self.brushSize == smallSize then
        self.brushSize = standardSize
    elseif self.brushSize == standardSize then
        self.brushSize = largeSize
    else
        self.brushSize = smallSize
    end
end

-- Mouse pressed callback
function InputHandler:mousepressed(x, y, button)
    self.mouseX = x
    self.mouseY = y
    
    if button == 1 then  -- Left mouse button
        self.mouseDown = true
        self.dragStartX = x
        self.dragStartY = y
        
        -- In shoot mode, start aiming with the standard ball
        if self.mode == "shoot" and self.ballManager then
            if self.debug then
                print("Mouse pressed in shoot mode at " .. x .. ", " .. y)
                print("Checking if ball can be shot...")
                if self.ballManager.canShoot then
                    print("Can shoot: " .. tostring(self.ballManager:canShoot()))
                else
                    print("canShoot method not found on ballManager")
                end
            end
            
            -- Always try to start aiming, even if the ball can't be shot yet
            -- This makes the aiming more responsive
            if self.ballManager.startAiming then
                self.ballManager:startAiming(x, y)
                if self.debug then
                    print("Started aiming at " .. x .. ", " .. y)
                end
                return
            else
                if self.debug then
                    print("startAiming method not found on ballManager")
                end
            end
        end
        
        -- In spray mode, place cells
        if self.mode == "spray" and self.camera and self.camera.screenToWorld then
            -- Convert screen coordinates to world coordinates
            local worldX, worldY = self.camera:screenToWorld(x, y)
            
            -- Place cells at the cursor position
            self:placeCells(worldX, worldY)
        end
    elseif button == 2 then  -- Right mouse button
        -- Cycle through brush sizes with right mouse button (only in spray mode)
        if self.mode == "spray" then
            self:cycleBrushSize()
        end
    elseif button == 3 then  -- Middle mouse button
        -- Activate camera control with middle mouse button
        self.cameraControl.active = true
        self.cameraControl.lastX = x
        self.cameraControl.lastY = y
        
        -- Disable camera target following when starting to drag
        if self.camera and self.camera.disableFollowTarget then
            self.camera:disableFollowTarget()
        end
    end
end

-- Mouse wheel moved callback
function InputHandler:wheelmoved(x, y)
    -- Only handle if camera is available
    if not self.camera then return end
    
    -- Zoom in/out based on wheel direction
    if y > 0 then
        -- Zoom in (wheel up)
        self.camera:zoomIn(1.1)
        if self.debug then
            print("Zooming in (wheel)")
        end
    elseif y < 0 then
        -- Zoom out (wheel down)
        self.camera:zoomOut(1.1)
        if self.debug then
            print("Zooming out (wheel)")
        end
    end
    
    -- Horizontal scrolling with wheel could be implemented here if needed
    if x ~= 0 and self.debug then
        print("Horizontal wheel: " .. x)
    end
end

-- Mouse released callback
function InputHandler:mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
        self.mouseDown = false
        
        -- In shoot mode, execute the shot if aiming
        if self.mode == "shoot" and self.ballManager and 
           self.ballManager.isCurrentlyAiming and self.ballManager.shoot and
           self.ballManager:isCurrentlyAiming() then
            -- Execute the shot
            local success = self.ballManager:shoot()
            
            if self.debug then
                print("Shot executed: " .. tostring(success))
            end
            
            -- Record the shot in game state if available
            if success and _G.gameState and _G.gameState.recordShot then
                _G.gameState:recordShot()
            end
        end
    elseif button == 3 then  -- Middle mouse button
        -- End camera control
        self.cameraControl.active = false
    end
    -- Right mouse button (2) doesn't need any special handling on release
    -- since it's just used for cycling brush sizes on press
end

-- Key pressed callback
function InputHandler:keypressed(key)
    self.keys[key] = true
    
    -- Toggle between spray and shoot modes with space
    if key == "space" then
        if self.mode == "spray" then
            self.mode = "shoot"
            if self.debug then
                print("Switched to SHOOT mode")
            end
        else
            self.mode = "spray"
            if self.debug then
                print("Switched to SPRAY mode")
            end
        end
        return
    end
    
    -- Cancel shot with escape
    if key == "escape" then
        -- Cancel regular ball aim
        if self.ballManager and self.ballManager.isCurrentlyAiming and 
           self.ballManager.cancelShot and self.ballManager:isCurrentlyAiming() then
            self.ballManager:cancelShot()
            if self.debug then
                print("Shot cancelled")
            end
        end
    end
    
    -- Material selection (only in spray mode)
    if self.mode == "spray" then
        if key == "1" then
            self.currentMaterial = 20  -- Sand
        elseif key == "2" then
            self.currentMaterial = 30  -- Water
        elseif key == "3" then
            self.currentMaterial = 40  -- Fire
        elseif key == "4" then
            self.currentMaterial = 10  -- Stone
        elseif key == "5" then
            self.currentMaterial = 11  -- Dirt
        elseif key == "tab" then
            -- Cycle through materials (since middle mouse button now pans the camera)
            if self.currentMaterial == 20 then -- Sand -> Water
                self.currentMaterial = 30
            elseif self.currentMaterial == 30 then -- Water -> Fire
                self.currentMaterial = 40
            elseif self.currentMaterial == 40 then -- Fire -> Stone
                self.currentMaterial = 10
            elseif self.currentMaterial == 10 then -- Stone -> Dirt
                self.currentMaterial = 11
            elseif self.currentMaterial == 11 then -- Dirt -> Sand
                self.currentMaterial = 20
            else
                self.currentMaterial = 20
            end
        end
    end
    
    -- Brush size (only in spray mode)
    if self.mode == "spray" then
        if key == "[" and self.brushSize > 1 then
            self.brushSize = self.brushSize - 1
        elseif key == "]" and self.brushSize < 10 then
            self.brushSize = self.brushSize + 1
        end
    end
    
    -- Clear all cells with 'c' key
    if key == "c" and love.keyboard.isDown("lctrl") then
        if self.cellWorld then
            self.cellWorld:clear()
        end
    end
end

-- Key released callback
function InputHandler:keyreleased(key)
    self.keys[key] = false
end

-- Touch pressed callback (for mobile)
function InputHandler:touchpressed(id, x, y)
    self.touches[id] = {x = x, y = y}
    
    -- Check if we have multiple touches
    local touchCount = 0
    for _ in pairs(self.touches) do touchCount = touchCount + 1 end
    
    if touchCount > 1 then
        self.multiTouch = true
    else
        -- Single touch - similar to mouse press
        self.mousepressed(x, y, 1)
    end
end

-- Mouse moved callback
function InputHandler:mousemoved(x, y, dx, dy)
    -- Update mouse position
    self.mouseX = x
    self.mouseY = y
    
    -- Handle camera dragging with middle mouse button
    if self.cameraControl.active and self.camera then
        -- Calculate the movement in world space (accounting for zoom)
        local worldDX = dx / self.camera.scale
        local worldDY = dy / self.camera.scale
        
        -- Move the camera in the opposite direction of the mouse movement
        self.camera:setTarget(self.camera.targetX - worldDX, self.camera.targetY - worldDY)
        
        -- Update last position
        self.cameraControl.lastX = x
        self.cameraControl.lastY = y
    end
end

-- Touch moved callback (for mobile)
function InputHandler:touchmoved(id, x, y)
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
        self.mouseX, self.mouseY = x, y
    end
end

-- Touch released callback (for mobile)
function InputHandler:touchreleased(id, x, y)
    self.touches[id] = nil
    
    -- Check if we still have multiple touches
    local touchCount = 0
    for _ in pairs(self.touches) do touchCount = touchCount + 1 end
    
    if touchCount <= 1 then
        self.multiTouch = false
    end
    
    -- If we released all touches, treat as mouse release
    if touchCount == 0 then
        self.mousereleased(x, y, 1)
    end
end

-- Draw the custom cursor and material indicator
function InputHandler:draw()
    -- Only draw if we're showing the custom cursor
    if not self.showCustomCursor then return end
    
    -- Draw the material indicator
    self:drawMaterialIndicator()
    
    -- Draw the custom cursor
    self:drawCustomCursor()
    
    -- Draw the current mode
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Mode: " .. (self.mode == "spray" and "Spray (Space to toggle)" or "Shoot (Space to toggle)"), 10, 130)
end

-- Draw the custom cursor
function InputHandler:drawCustomCursor()
    -- Get the current material color
    local color
    if self.currentMaterial == 20 then -- Sand
        color = {0.95, 0.85, 0.45, 1}
    elseif self.currentMaterial == 30 then -- Water
        color = {0.2, 0.4, 0.9, 0.8}
    elseif self.currentMaterial == 40 then -- Fire
        color = {1.0, 0.4, 0.0, 1}
    elseif self.currentMaterial == 10 then -- Stone
        color = {0.5, 0.5, 0.5, 1}
    elseif self.currentMaterial == 11 then -- Dirt
        color = {0.6, 0.4, 0.2, 1}
    else
        color = {1, 1, 1, 1}
    end
    
    -- In spray mode, draw a spray can cursor
    if self.mode == "spray" then
        love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Dark gray for the can
        
        -- Can body
        love.graphics.rectangle("fill", self.mouseX - 8, self.mouseY - 4, 16, 20)
        
        -- Can top
        love.graphics.rectangle("fill", self.mouseX - 6, self.mouseY - 10, 12, 6)
        
        -- Spray nozzle
        love.graphics.rectangle("fill", self.mouseX - 2, self.mouseY - 14, 4, 4)
        
        -- Material color indicator on the can
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", self.mouseX - 6, self.mouseY, 12, 12)
        
        -- Draw spray particles if mouse is down
        if self.mouseDown and not self.cameraControl.active then
            -- Draw some spray particles
            for i = 1, 5 do
                local angle = math.random() * math.pi * 0.5 - math.pi * 0.25  -- -45 to 45 degrees
                local distance = math.random(10, 20)
                local x = self.mouseX + math.cos(angle) * distance
                local y = self.mouseY - 16 + math.sin(angle) * distance  -- From the nozzle
                
                -- Particle size varies
                local size = math.random(2, 4)
                
                -- Draw the particle
                love.graphics.setColor(color[1], color[2], color[3], 0.7)
                love.graphics.rectangle("fill", x - size/2, y - size/2, size, size)
            end
        end
    else
        -- In shoot mode, draw a target cursor
        love.graphics.setColor(1, 0.2, 0.2, 0.8)
        
        -- Outer circle
        love.graphics.circle("line", self.mouseX, self.mouseY, 12)
        
        -- Inner circle
        love.graphics.circle("line", self.mouseX, self.mouseY, 6)
        
        -- Crosshair lines
        love.graphics.line(self.mouseX - 16, self.mouseY, self.mouseX - 8, self.mouseY)
        love.graphics.line(self.mouseX + 8, self.mouseY, self.mouseX + 16, self.mouseY)
        love.graphics.line(self.mouseX, self.mouseY - 16, self.mouseX, self.mouseY - 8)
        love.graphics.line(self.mouseX, self.mouseY + 8, self.mouseX, self.mouseY + 16)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the material indicator
function InputHandler:drawMaterialIndicator()
    -- Only show material indicator in spray mode
    if self.mode ~= "spray" then return end
    
    local x = self.materialIndicator.x
    local y = self.materialIndicator.y
    local width = self.materialIndicator.width
    local height = self.materialIndicator.height
    local padding = self.materialIndicator.padding
    
    -- Draw background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
    
    -- Draw material sample
    local materialColor
    local materialName
    
    if self.currentMaterial == 20 then -- Sand
        materialColor = {0.95, 0.85, 0.45, 1}
        materialName = "Sand"
    elseif self.currentMaterial == 30 then -- Water
        materialColor = {0.2, 0.4, 0.9, 0.8}
        materialName = "Water"
    elseif self.currentMaterial == 40 then -- Fire
        materialColor = {1.0, 0.4, 0.0, 1}
        materialName = "Fire"
    elseif self.currentMaterial == 10 then -- Stone
        materialColor = {0.5, 0.5, 0.5, 1}
        materialName = "Stone"
    elseif self.currentMaterial == 11 then -- Dirt
        materialColor = {0.6, 0.4, 0.2, 1}
        materialName = "Dirt"
    else
        materialColor = {1, 1, 1, 1}
        materialName = "Unknown"
    end
    
    -- Draw material sample
    love.graphics.setColor(materialColor)
    love.graphics.rectangle("fill", 
                           x + padding, 
                           y + padding, 
                           width - padding * 2, 
                           height - padding * 2)
    
    -- Draw material name
    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    love.graphics.print(materialName, x + width + 10, y + height/2 - font:getHeight()/2)
    
    -- Draw brush size indicator
    love.graphics.print("Brush: " .. self.brushSize, x + width + 10, y + height/2 + font:getHeight())
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return InputHandler
