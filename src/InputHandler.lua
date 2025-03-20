-- InputHandler.lua - Handles user input for the game

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
    
    -- Material placement
    self.currentMaterial = 20  -- Default to sand (CellTypes.SAND)
    self.brushSize = 3
    self.isDrawing = false
    
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
    
    -- Touch support for mobile
    self.touches = {}
    self.multiTouch = false
    
    -- Hide the system cursor if we're using a custom one
    if self.showCustomCursor then
        love.mouse.setVisible(false)
    end
    
    return self
end

-- Update input state
function InputHandler:update(dt)
    -- Update mouse position
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
    -- Handle mouse dragging for cell placement
    if self.mouseDown and not self.cameraControl.active then
        -- Convert screen coordinates to world coordinates
        if self.camera and self.camera.screenToWorld then
            local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)
            
            -- Place cells at the cursor position
            self:placeCells(worldX, worldY)
        end
    end
    
    -- Handle camera control
    if self.cameraControl.active and self.camera then
        local dx = self.mouseX - self.cameraControl.lastX
        local dy = self.mouseY - self.cameraControl.lastY
        
        if dx ~= 0 or dy ~= 0 and self.camera.setTarget then
            -- Convert screen movement to world movement
            local scale = self.camera.scale or 1
            local worldDx = dx / scale
            local worldDy = dy / scale
            
            -- Move camera in opposite direction of drag
            if self.camera.targetX and self.camera.targetY then
                self.camera:setTarget(
                    self.camera.targetX - worldDx,
                    self.camera.targetY - worldDy
                )
            end
            
            self.cameraControl.lastX = self.mouseX
            self.cameraControl.lastY = self.mouseY
        end
    end
    
    -- Handle keyboard input
    self:handleKeyboardInput(dt)
end

-- Handle keyboard input
function InputHandler:handleKeyboardInput(dt)
    -- Check if camera is available
    if self.camera and self.camera.zoomIn then
        -- Camera zoom
        if self.keys["="] or self.keys["+"] then
            self.camera:zoomIn(1.01)
        end
        if self.keys["-"] then
            self.camera:zoomOut(1.01)
        end
        
        -- Camera movement with arrow keys
        local cameraScale = self.camera.scale or 1
        local cameraSpeed = 200 * dt / cameraScale
        
        if self.camera.setTarget and self.camera.targetX and self.camera.targetY then
            if self.keys["up"] or self.keys["w"] then
                self.camera:setTarget(self.camera.targetX, self.camera.targetY - cameraSpeed)
            end
            if self.keys["down"] or self.keys["s"] then
                self.camera:setTarget(self.camera.targetX, self.camera.targetY + cameraSpeed)
            end
            if self.keys["left"] or self.keys["a"] then
                self.camera:setTarget(self.camera.targetX - cameraSpeed, self.camera.targetY)
            end
            if self.keys["right"] or self.keys["d"] then
                self.camera:setTarget(self.camera.targetX + cameraSpeed, self.camera.targetY)
            end
        end
    end
    
    -- Check if ball manager is available
    if self.ballManager then
        -- Ball ability
        if self.keys["space"] and self.ballManager.useAbility then
            self.keys["space"] = false  -- Reset key state to prevent holding
            self.ballManager:useAbility()
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
end

-- Place cells at the given world coordinates
function InputHandler:placeCells(worldX, worldY)
    if not self.cellWorld then return end
    
    -- Debug output to help diagnose issues
    print("Placing cells at world coordinates:", worldX, worldY)
    
    -- Convert to cell coordinates
    local cellX = math.floor(worldX)
    local cellY = math.floor(worldY)
    
    print("Cell coordinates:", cellX, cellY)
    
    -- We'll use the mouse position directly for cell placement
    -- This is more intuitive for the user
    
    print("Using direct cell coordinates:", cellX, cellY)
    
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
    
    print("Cells placed:", cellsPlaced)
    
    -- Update the cell data image
    self.cellWorld:updateCellDataImage()
end

-- Mouse pressed callback
function InputHandler:mousepressed(x, y, button)
    self.mouseX = x
    self.mouseY = y
    
    if button == 1 then  -- Left mouse button
        self.mouseDown = true
        self.dragStartX = x
        self.dragStartY = y
        
        -- Check if camera and ball manager are available
        if self.camera and self.camera.screenToWorld then
            -- Convert screen coordinates to world coordinates
            local worldX, worldY = self.camera:screenToWorld(x, y)
            
            -- Place cells at the cursor position
            self:placeCells(worldX, worldY)
        end
    elseif button == 2 then  -- Right mouse button
        -- Always activate camera control with right mouse
        self.cameraControl.active = true
        self.cameraControl.lastX = x
        self.cameraControl.lastY = y
    elseif button == 3 then  -- Middle mouse button
        -- Cycle through materials
        if self.currentMaterial == 20 then -- Sand -> Water
            self.currentMaterial = 30
            print("Material: Water")
        elseif self.currentMaterial == 30 then -- Water -> Fire
            self.currentMaterial = 40
            print("Material: Fire")
        elseif self.currentMaterial == 40 then -- Fire -> Sand
            self.currentMaterial = 20
            print("Material: Sand")
        else
            self.currentMaterial = 20
            print("Material: Sand")
        end
    end
end

-- Mouse released callback
function InputHandler:mousereleased(x, y, button)
    if button == 1 then  -- Left mouse button
        self.mouseDown = false
        
        -- Check if we were aiming
        if self.ballManager and self.ballManager.isCurrentlyAiming and self.ballManager.shoot and
           self.ballManager:isCurrentlyAiming() then
            -- Execute the shot
            self.ballManager:shoot()
        end
        
        -- End camera control
        self.cameraControl.active = false
    elseif button == 2 then  -- Right mouse button
        -- End camera control
        self.cameraControl.active = false
    end
end

-- Key pressed callback
function InputHandler:keypressed(key)
    self.keys[key] = true
    
    -- Cancel shot with escape
    if key == "escape" and self.ballManager and self.ballManager.isCurrentlyAiming and 
       self.ballManager.cancelShot and self.ballManager:isCurrentlyAiming() then
        self.ballManager:cancelShot()
    end
    
    -- Material selection
    if key == "1" then
        self.currentMaterial = 20  -- Sand
        print("Material: Sand")
    elseif key == "2" then
        self.currentMaterial = 30  -- Water
        print("Material: Water")
    elseif key == "3" then
        self.currentMaterial = 40  -- Fire
        print("Material: Fire")
    elseif key == "4" then
        self.currentMaterial = 10  -- Stone
        print("Material: Stone")
    elseif key == "5" then
        self.currentMaterial = 11  -- Dirt
        print("Material: Dirt")
    end
    
    -- Brush size
    if key == "[" and self.brushSize > 1 then
        self.brushSize = self.brushSize - 1
        print("Brush size:", self.brushSize)
    elseif key == "]" and self.brushSize < 10 then
        self.brushSize = self.brushSize + 1
        print("Brush size:", self.brushSize)
    end
    
    -- Clear all cells with 'c' key
    if key == "c" and love.keyboard.isDown("lctrl") then
        if self.cellWorld then
            self.cellWorld:clear()
            print("Cleared all cells")
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
    
    -- Draw debugging information
    self:drawDebugInfo()
end

-- Draw debugging information
function InputHandler:drawDebugInfo()
    -- Only draw if we have camera and cellWorld
    if not self.camera or not self.cellWorld then return end
    
    -- Get mouse position in world coordinates
    local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)
    
    -- Convert to cell coordinates
    local cellX = math.floor(worldX)
    local cellY = math.floor(worldY)
    
    -- Draw a visual indicator at the target cell position
    love.graphics.setColor(1, 0, 0, 0.7)  -- Red with transparency
    
    -- Convert cell coordinates back to screen coordinates for visualization
    local targetScreenX, targetScreenY = self.camera:worldToScreen(cellX, cellY)
    
    -- Draw a crosshair at the target position
    local crosshairSize = 10
    love.graphics.setLineWidth(2)
    love.graphics.line(
        targetScreenX - crosshairSize, targetScreenY,
        targetScreenX + crosshairSize, targetScreenY
    )
    love.graphics.line(
        targetScreenX, targetScreenY - crosshairSize,
        targetScreenX, targetScreenY + crosshairSize
    )
    
    -- Draw the brush area
    love.graphics.setColor(1, 1, 0, 0.3)  -- Yellow with transparency
    local brushRadius = self.brushSize * self.cellWorld.cellSize * self.camera.scale
    love.graphics.circle("line", targetScreenX, targetScreenY, brushRadius)
    
    -- Draw text with coordinates
    love.graphics.setColor(1, 1, 1, 1)
    local debugText = string.format(
        "Mouse: %.1f, %.1f\nWorld: %.1f, %.1f\nCell: %d, %d\nBrush: %d",
        self.mouseX, self.mouseY,
        worldX, worldY,
        cellX, cellY,
        self.brushSize
    )
    love.graphics.print(debugText, 10, 100)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
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
    
    -- Draw a spray can cursor
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
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the material indicator
function InputHandler:drawMaterialIndicator()
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
