-- MaterialHandler.lua - Handles material selection and cell placement

local MaterialHandler = {}
MaterialHandler.__index = MaterialHandler

function MaterialHandler.new(inputHandler)
    local self = setmetatable({}, MaterialHandler)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    -- Material placement
    self.currentMaterial = 20  -- Default to sand (CellTypes.SAND)
    self.brushSize = 3
    self.isDrawing = false
    
    return self
end

-- Update material handler
function MaterialHandler:update(dt)
    -- Handle continuous cell placement while mouse is down
    self:handleContinuousCellPlacement()
end

-- Handle continuous cell placement while mouse is down
function MaterialHandler:handleContinuousCellPlacement()
    local inputHandler = self.inputHandler
    
    -- Handle normal mouse dragging for cell placement
    if inputHandler.mouseDown and 
       not inputHandler.cameraController:isDragging() and 
       inputHandler.mode == "spray" then
        -- Convert screen coordinates to world coordinates
        if inputHandler.camera and inputHandler.camera.screenToWorld then
            local worldX, worldY = inputHandler.camera:screenToWorld(inputHandler.mouseX, inputHandler.mouseY)
            
            -- Place cells at the cursor position
            self:placeCells(worldX, worldY)
        end
    end
end

-- Place cells at the given world coordinates
function MaterialHandler:placeCells(worldX, worldY)
    local cellWorld = self.inputHandler.cellWorld
    
    if not cellWorld or self.inputHandler.mode ~= "spray" then return end
    
    -- Convert world coordinates to cell coordinates
    -- Need to account for the fact that cell coordinates (1,1) correspond to world coordinates (0,0)
    local cellSize = cellWorld.cellSize
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
                local color = self:generateCellColor()
                
                -- Set the cell with its unique color
                -- Only if the cell is within bounds and not already occupied
                if x >= 1 and x <= cellWorld.width and 
                   y >= 1 and y <= cellWorld.height and
                   cellWorld:getCell(x, y) == 0 then
                    cellWorld:setCell(x, y, self.currentMaterial, color)
                    cellsPlaced = cellsPlaced + 1
                end
            end
        end
    end
    
    -- Update the cell data image
    cellWorld:updateCellDataImage()
end

-- Generate a color for a cell based on its material type
function MaterialHandler:generateCellColor()
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
    
    return color
end

-- Set the current material
function MaterialHandler:setMaterial(materialType)
    self.currentMaterial = materialType
    
    if self.inputHandler.debug then
        local materialName = self:getMaterialName(materialType)
        print("Selected material: " .. materialName)
    end
end

-- Get the name of a material type
function MaterialHandler:getMaterialName(materialType)
    if materialType == 20 then
        return "Sand"
    elseif materialType == 30 then
        return "Water"
    elseif materialType == 40 then
        return "Fire"
    elseif materialType == 10 then
        return "Stone"
    elseif materialType == 11 then
        return "Dirt"
    else
        return "Unknown"
    end
end

-- Cycle through materials
function MaterialHandler:cycleMaterial()
    if self.currentMaterial == 20 then -- Sand -> Water
        self:setMaterial(30)
    elseif self.currentMaterial == 30 then -- Water -> Fire
        self:setMaterial(40)
    elseif self.currentMaterial == 40 then -- Fire -> Stone
        self:setMaterial(10)
    elseif self.currentMaterial == 10 then -- Stone -> Dirt
        self:setMaterial(11)
    elseif self.currentMaterial == 11 then -- Dirt -> Sand
        self:setMaterial(20)
    else
        self:setMaterial(20)
    end
end

-- Cycle through brush sizes
function MaterialHandler:cycleBrushSize()
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
    
    if self.inputHandler.debug then
        print("Brush size: " .. self.brushSize)
    end
end

-- Increase brush size
function MaterialHandler:increaseBrushSize()
    if self.brushSize < 10 then
        self.brushSize = self.brushSize + 1
        
        if self.inputHandler.debug then
            print("Brush size: " .. self.brushSize)
        end
    end
end

-- Decrease brush size
function MaterialHandler:decreaseBrushSize()
    if self.brushSize > 1 then
        self.brushSize = self.brushSize - 1
        
        if self.inputHandler.debug then
            print("Brush size: " .. self.brushSize)
        end
    end
end

-- Get the current material color
function MaterialHandler:getCurrentMaterialColor()
    if self.currentMaterial == 20 then -- Sand
        return {0.95, 0.85, 0.45, 1}
    elseif self.currentMaterial == 30 then -- Water
        return {0.2, 0.4, 0.9, 0.8}
    elseif self.currentMaterial == 40 then -- Fire
        return {1.0, 0.4, 0.0, 1}
    elseif self.currentMaterial == 10 then -- Stone
        return {0.5, 0.5, 0.5, 1}
    elseif self.currentMaterial == 11 then -- Dirt
        return {0.6, 0.4, 0.2, 1}
    else
        return {1, 1, 1, 1}
    end
end

-- Get the current material name
function MaterialHandler:getCurrentMaterialName()
    return self:getMaterialName(self.currentMaterial)
end

return MaterialHandler
