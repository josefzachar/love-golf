-- CellWorld.lua - Manages the cellular automaton simulation

local CellTypes = require("src.cells.CellTypes")
local utils = require("src.utils")

local CellWorld = {}
CellWorld.__index = CellWorld

-- Create a new cell world
function CellWorld.new(width, height, cellSize, shader)
    local self = setmetatable({}, CellWorld)
    
    -- Dimensions
    self.width = width
    self.height = height
    self.cellSize = cellSize
    
    -- Shader for GPU-accelerated rendering and simulation
    self.shader = shader
    
    -- Create cell data storage
    -- We use two buffers for double-buffering technique
    -- This allows us to read from one buffer while writing to the other
    self.cells = {}
    self.nextCells = {}
    self.cellColors = {}  -- Store colors separately for persistence
    
    -- Initialize cell data
    self:clear()
    
    -- Create canvas for rendering
    self.canvas = love.graphics.newCanvas(width * cellSize, height * cellSize)
    
    -- Performance tracking
    self.activeCellCount = 0
    
    -- Create cell data image for GPU processing
    self:updateCellDataImage()
    
    return self
end

-- Clear all cells
function CellWorld:clear()
    -- Initialize both buffers with empty cells
    self.cells = {}
    self.nextCells = {}
    self.cellColors = {}
    
    for y = 1, self.height do
        self.cells[y] = {}
        self.nextCells[y] = {}
        self.cellColors[y] = {}
        
        for x = 1, self.width do
            self.cells[y][x] = CellTypes.EMPTY
            self.nextCells[y][x] = CellTypes.EMPTY
            self.cellColors[y][x] = {1, 1, 1, 1}  -- Default white color
        end
    end
    
    self.activeCellCount = 0
end

-- Update the cell data image for GPU processing
function CellWorld:updateCellDataImage()
    -- Create image data for cell types
    local imageData = love.image.newImageData(self.width, self.height)
    
    for y = 1, self.height do
        -- Ensure the tables exist
        if not self.cells[y] then
            self.cells[y] = {}
        end
        
        if not self.cellColors[y] then
            self.cellColors[y] = {}
        end
        
        for x = 1, self.width do
            local cellType = self.cells[y][x] or CellTypes.EMPTY
            
            -- Ensure color exists
            if not self.cellColors[y][x] then
                self.cellColors[y][x] = {1, 1, 1, 1}  -- Default white color
            end
            
            local r, g, b, a = unpack(self.cellColors[y][x])
            
            -- Encode cell type in the alpha channel
            -- This allows us to use the RGB channels for visual appearance
            imageData:setPixel(x-1, y-1, r, g, b, cellType / 255)
        end
    end
    
    -- Create image from image data
    if self.cellDataImage then
        self.cellDataImage:replacePixels(imageData)
    else
        self.cellDataImage = love.graphics.newImage(imageData)
        self.cellDataImage:setFilter("nearest", "nearest")
    end
end

-- Set a single cell
function CellWorld:setCell(x, y, cellType, color)
    -- Check bounds
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return
    end
    
    -- Ensure the tables exist
    if not self.cells[y] then
        self.cells[y] = {}
    end
    
    if not self.cellColors[y] then
        self.cellColors[y] = {}
    end
    
    -- Set cell type
    self.cells[y][x] = cellType
    
    -- Set cell color if provided
    if color then
        self.cellColors[y][x] = color
    else
        -- Use default color for this cell type
        local defaultColor = CellTypes.getDefaultColor(cellType)
        if defaultColor then
            self.cellColors[y][x] = defaultColor
        else
            self.cellColors[y][x] = {1, 1, 1, 1}  -- Default white color
        end
    end
    
    -- Update active cell count
    if cellType ~= CellTypes.EMPTY then
        self.activeCellCount = self.activeCellCount + 1
    end
end

-- Get a cell type
function CellWorld:getCell(x, y)
    -- Check bounds
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return CellTypes.BOUNDARY
    end
    
    -- Ensure the table exists
    if not self.cells[y] then
        self.cells[y] = {}
    end
    
    -- Return cell type or empty if not set
    return self.cells[y][x] or CellTypes.EMPTY
end

-- Load cell data from a level definition
function CellWorld:loadFromData(cellData)
    for _, cell in ipairs(cellData) do
        local x, y, cellType = cell.x, cell.y, cell.type
        local color = cell.color or CellTypes.getDefaultColor(cellType)
        self:setCell(x, y, cellType, color)
    end
    
    -- Update the cell data image after loading
    self:updateCellDataImage()
end

-- Draw a circle of cells
function CellWorld:drawCircle(centerX, centerY, radius, cellType, color)
    for y = math.max(1, math.floor(centerY - radius)), math.min(self.height, math.ceil(centerY + radius)) do
        for x = math.max(1, math.floor(centerX - radius)), math.min(self.width, math.ceil(centerX + radius)) do
            local dx = x - centerX
            local dy = y - centerY
            if dx*dx + dy*dy <= radius*radius then
                self:setCell(x, y, cellType, color)
            end
        end
    end
    
    -- Update the cell data image after drawing
    self:updateCellDataImage()
end

-- Update the cell simulation
function CellWorld:update(dt, gravity)
    -- Count active cells
    self.activeCellCount = 0
    
    for y = 1, self.height do
        for x = 1, self.width do
            local cellType = self.cells[y][x]
            if cellType and cellType ~= CellTypes.EMPTY then
                self.activeCellCount = self.activeCellCount + 1
            end
        end
    end
    
    -- Enhanced cellular automaton physics
    -- Process cells from bottom to top, right to left for better simulation
    for y = self.height, 1, -1 do
        -- Alternate direction each row for more natural flow
        local startX, endX, stepX
        if y % 2 == 0 then
            startX, endX, stepX = 1, self.width, 1  -- Left to right
        else
            startX, endX, stepX = self.width, 1, -1  -- Right to left
        end
        
        for x = startX, endX, stepX do
            local cellType = self.cells[y][x]
            
            -- Skip empty cells and boundary cells
            if cellType and cellType ~= CellTypes.EMPTY and cellType ~= CellTypes.BOUNDARY then
                local cellColor = self.cellColors[y][x]
                
                -- SAND behavior
                if cellType == CellTypes.SAND then
                    -- Try to fall down
                    if y < self.height and self:getCell(x, y + 1) == CellTypes.EMPTY then
                        -- Preserve the cell's color when moving
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x, y + 1, CellTypes.SAND, cellColor)
                    -- Try to fall diagonally
                    elseif y < self.height then
                        local leftClear = x > 1 and self:getCell(x - 1, y + 1) == CellTypes.EMPTY
                        local rightClear = x < self.width and self:getCell(x + 1, y + 1) == CellTypes.EMPTY
                        
                        if leftClear and rightClear then
                            -- Choose randomly between left and right
                            if math.random() < 0.5 then
                                self:setCell(x, y, CellTypes.EMPTY)
                                self:setCell(x - 1, y + 1, CellTypes.SAND, cellColor)
                            else
                                self:setCell(x, y, CellTypes.EMPTY)
                                self:setCell(x + 1, y + 1, CellTypes.SAND, cellColor)
                            end
                        elseif leftClear then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x - 1, y + 1, CellTypes.SAND, cellColor)
                        elseif rightClear then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x + 1, y + 1, CellTypes.SAND, cellColor)
                        end
                    end
                    
                    -- Sand can displace water
                    if y < self.height and self:getCell(x, y + 1) == CellTypes.WATER then
                        local waterColor = self.cellColors[y + 1][x]
                        self:setCell(x, y, CellTypes.WATER, waterColor)
                        self:setCell(x, y + 1, CellTypes.SAND, cellColor)
                    end
                end
                
                -- WATER behavior
                if cellType == CellTypes.WATER then
                    -- Try to fall down
                    if y < self.height and self:getCell(x, y + 1) == CellTypes.EMPTY then
                        -- Preserve the cell's color when moving
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x, y + 1, CellTypes.WATER, cellColor)
                    -- Try to flow horizontally
                    else
                        local flowDistance = 3  -- How far water can flow horizontally
                        local flowed = false
                        
                        -- Try to flow left or right randomly
                        if math.random() < 0.5 then
                            -- Try left first
                            for i = 1, flowDistance do
                                if x - i > 0 and self:getCell(x - i, y) == CellTypes.EMPTY then
                                    -- Preserve the cell's color when moving
                                    self:setCell(x, y, CellTypes.EMPTY)
                                    self:setCell(x - i, y, CellTypes.WATER, cellColor)
                                    flowed = true
                                    break
                                elseif x - i <= 0 or self:getCell(x - i, y) ~= CellTypes.WATER then
                                    break
                                end
                            end
                            
                            -- If couldn't flow left, try right
                            if not flowed then
                                for i = 1, flowDistance do
                                    if x + i <= self.width and self:getCell(x + i, y) == CellTypes.EMPTY then
                                        -- Preserve the cell's color when moving
                                        self:setCell(x, y, CellTypes.EMPTY)
                                        self:setCell(x + i, y, CellTypes.WATER, cellColor)
                                        break
                                    elseif x + i > self.width or self:getCell(x + i, y) ~= CellTypes.WATER then
                                        break
                                    end
                                end
                            end
                        else
                            -- Try right first
                            for i = 1, flowDistance do
                                if x + i <= self.width and self:getCell(x + i, y) == CellTypes.EMPTY then
                                    -- Preserve the cell's color when moving
                                    self:setCell(x, y, CellTypes.EMPTY)
                                    self:setCell(x + i, y, CellTypes.WATER, cellColor)
                                    flowed = true
                                    break
                                elseif x + i > self.width or self:getCell(x + i, y) ~= CellTypes.WATER then
                                    break
                                end
                            end
                            
                            -- If couldn't flow right, try left
                            if not flowed then
                                for i = 1, flowDistance do
                                    if x - i > 0 and self:getCell(x - i, y) == CellTypes.EMPTY then
                                        -- Preserve the cell's color when moving
                                        self:setCell(x, y, CellTypes.EMPTY)
                                        self:setCell(x - i, y, CellTypes.WATER, cellColor)
                                        break
                                    elseif x - i <= 0 or self:getCell(x - i, y) ~= CellTypes.WATER then
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- FIRE behavior (if implemented)
                if cellType == CellTypes.FIRE then
                    -- Fire rises and spreads
                    if y > 1 and self:getCell(x, y - 1) == CellTypes.EMPTY and math.random() < 0.8 then
                        -- Preserve the cell's color when moving
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x, y - 1, CellTypes.FIRE, cellColor)
                    -- Fire has a chance to burn out
                    elseif math.random() < 0.05 then
                        -- Create smoke with a color based on the fire color but more transparent
                        local smokeColor = {
                            cellColor[1] * 0.5,
                            cellColor[2] * 0.5,
                            cellColor[3] * 0.5,
                            0.7
                        }
                        self:setCell(x, y, CellTypes.SMOKE, smokeColor)
                    end
                end
                
                -- SMOKE behavior (if implemented)
                if cellType == CellTypes.SMOKE then
                    -- Smoke rises
                    if y > 1 and self:getCell(x, y - 1) == CellTypes.EMPTY then
                        -- Preserve the cell's color when moving
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x, y - 1, CellTypes.SMOKE, cellColor)
                    -- Smoke dissipates
                    elseif math.random() < 0.02 then
                        self:setCell(x, y, CellTypes.EMPTY)
                    end
                end
            end
        end
    end
end

-- Draw the cell world
function CellWorld:draw()
    -- Skip shader rendering for now and draw cells directly
    for y = 1, self.height do
        for x = 1, self.width do
            local cellType = self.cells[y][x]
            if cellType and cellType ~= CellTypes.EMPTY then
                -- Make sure we have a valid color
                if not self.cellColors[y] or not self.cellColors[y][x] then
                    self.cellColors[y] = self.cellColors[y] or {}
                    self.cellColors[y][x] = CellTypes.getDefaultColor(cellType) or {1, 1, 1, 1}
                end
                
                -- Get the color and apply it
                local color = self.cellColors[y][x]
                love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
                
                -- Draw the cell
                love.graphics.rectangle("fill", (x-1) * self.cellSize, (y-1) * self.cellSize, 
                                       self.cellSize, self.cellSize)
            end
        end
    end
    
    -- Draw a border around the world
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("line", 0, 0, self.width * self.cellSize, self.height * self.cellSize)
end

-- Get the number of active (non-empty) cells
function CellWorld:getActiveCellCount()
    return self.activeCellCount
end

-- Check if a position is empty (for collision detection)
function CellWorld:isEmpty(x, y)
    local cellType = self:getCell(x, y)
    return cellType == CellTypes.EMPTY
end

-- Check if a position is solid (for collision detection)
function CellWorld:isSolid(x, y)
    local cellType = self:getCell(x, y)
    return CellTypes.isSolid(cellType)
end

-- Check if a position is liquid (for physics behavior)
function CellWorld:isLiquid(x, y)
    local cellType = self:getCell(x, y)
    return CellTypes.isLiquid(cellType)
end

-- Explode cells in a radius
function CellWorld:explode(centerX, centerY, radius)
    -- Create explosion effect
    for y = math.max(1, math.floor(centerY - radius)), math.min(self.height, math.ceil(centerY + radius)) do
        for x = math.max(1, math.floor(centerX - radius)), math.min(self.width, math.ceil(centerX + radius)) do
            local dx = x - centerX
            local dy = y - centerY
            local distSq = dx*dx + dy*dy
            
            if distSq <= radius*radius then
                local cellType = self:getCell(x, y)
                
                -- Different materials react differently to explosions
                if CellTypes.isDestructible(cellType) then
                    -- Calculate force direction
                    local force = 1 - math.sqrt(distSq) / radius
                    local angle = math.atan2(dy, dx)
                    
                    -- Convert solid blocks to particles
                    if CellTypes.isSolid(cellType) and not CellTypes.isIndestructible(cellType) then
                        self:setCell(x, y, CellTypes.SAND, self.cellColors[y][x])
                    end
                    
                    -- Add fire at the center of explosion
                    if distSq <= (radius * 0.3)^2 then
                        self:setCell(x, y, CellTypes.FIRE, {1, 0.5, 0, 1})
                    end
                end
            end
        end
    end
    
    -- Update the cell data image after explosion
    self:updateCellDataImage()
end

return CellWorld
