-- KeyboardHandler.lua - Handles keyboard input

local KeyboardHandler = {}
KeyboardHandler.__index = KeyboardHandler

function KeyboardHandler.new(inputHandler)
    local self = setmetatable({}, KeyboardHandler)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    return self
end

-- Update keyboard handler
function KeyboardHandler:update(dt)
    -- Handle camera movement and zoom
    self:handleCameraControls(dt)
end

-- Handle camera controls via keyboard
function KeyboardHandler:handleCameraControls(dt)
    local camera = self.inputHandler.camera
    
    -- Check if camera is available
    if camera and camera.zoomIn then
        -- Handle camera zoom
        self.inputHandler.cameraController:handleKeyboardZoom()
        
        -- Handle camera movement
        self.inputHandler.cameraController:handleKeyboardMovement(dt)
    end
end

-- Key pressed callback
function KeyboardHandler:keypressed(key)
    -- Toggle between spray and shoot modes with space
    if key == "space" then
        self:toggleMode()
        return
    end
    
    -- Cancel shot with escape
    if key == "escape" then
        self:cancelShot()
    end
    
    -- Material selection (only in spray mode)
    if self.inputHandler.mode == "spray" then
        self:handleMaterialSelection(key)
    end
    
    -- Brush size (only in spray mode)
    if self.inputHandler.mode == "spray" then
        self:handleBrushSizeChange(key)
    end
    
    -- Reset camera with 'c' key
    if key == "c" and not love.keyboard.isDown("lctrl") then
        self.inputHandler.cameraController:resetCamera()
        self.inputHandler.keys["c"] = false  -- Reset key state
    end
    
    -- Clear all cells with 'c' key + ctrl
    if key == "c" and love.keyboard.isDown("lctrl") then
        self:clearCells()
    end
end

-- Key released callback
function KeyboardHandler:keyreleased(key)
    -- Nothing special to do here, key state is already updated in InputHandler
end

-- Toggle between spray and shoot modes
function KeyboardHandler:toggleMode()
    if self.inputHandler.mode == "spray" then
        self.inputHandler.mode = "shoot"
        if self.inputHandler.debug then
            print("Switched to SHOOT mode")
        end
    else
        self.inputHandler.mode = "spray"
        if self.inputHandler.debug then
            print("Switched to SPRAY mode")
        end
    end
end

-- Cancel the current shot
function KeyboardHandler:cancelShot()
    local ballManager = self.inputHandler.ballManager
    
    -- Cancel regular ball aim
    if ballManager and ballManager.isCurrentlyAiming and 
       ballManager.cancelShot and ballManager:isCurrentlyAiming() then
        ballManager:cancelShot()
        if self.inputHandler.debug then
            print("Shot cancelled")
        end
    end
end

-- Handle material selection
function KeyboardHandler:handleMaterialSelection(key)
    -- Direct number key selection
    if key == "1" then
        self.inputHandler.materialHandler:setMaterial(20)  -- Sand
    elseif key == "2" then
        self.inputHandler.materialHandler:setMaterial(30)  -- Water
    elseif key == "3" then
        self.inputHandler.materialHandler:setMaterial(40)  -- Fire
    elseif key == "4" then
        self.inputHandler.materialHandler:setMaterial(10)  -- Stone
    elseif key == "5" then
        self.inputHandler.materialHandler:setMaterial(11)  -- Dirt
    elseif key == "tab" then
        -- Cycle through materials
        self.inputHandler.materialHandler:cycleMaterial()
    end
end

-- Handle brush size changes
function KeyboardHandler:handleBrushSizeChange(key)
    if key == "[" then
        self.inputHandler.materialHandler:decreaseBrushSize()
    elseif key == "]" then
        self.inputHandler.materialHandler:increaseBrushSize()
    end
end

-- Clear all cells
function KeyboardHandler:clearCells()
    local cellWorld = self.inputHandler.cellWorld
    
    if cellWorld and cellWorld.clear then
        cellWorld:clear()
        if self.inputHandler.debug then
            print("Cleared all cells")
        end
    end
end

return KeyboardHandler
