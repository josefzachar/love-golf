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
    
    -- Track dirt cells that are exposed to air
    self.exposedDirtCells = {}  -- Will store {x, y, timer} for each exposed dirt cell
    
    -- Initialize cell data
    self:clear()
    
    -- Create canvas for rendering
    self.canvas = love.graphics.newCanvas(width * cellSize, height * cellSize)
    
    -- Performance tracking
    self.activeCellCount = 0
    self.frameCount = 0
    self.activeRegions = {}
    
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

-- Helper function to check if a cell is active (needs updating)
function CellWorld:isActiveCell(x, y)
    local cellType = self:getCell(x, y)
    
    -- Skip empty cells, boundary cells, and solid non-destructible cells
    if cellType == CellTypes.EMPTY or cellType == CellTypes.BOUNDARY then
        return false
    end
    
    -- Check if it's a static cell (doesn't move or change)
    if cellType == CellTypes.STONE or cellType == CellTypes.METAL then
        -- Check if it has any dynamic neighbors (water, sand, etc.)
        local hasActiveCellNearby = false
        
        -- Check neighbors
        for dy = -1, 1 do
            for dx = -1, 1 do
                if dx ~= 0 or dy ~= 0 then  -- Skip the cell itself
                    local nx, ny = x + dx, y + dy
                    local neighborType = self:getCell(nx, ny)
                    
                    if neighborType == CellTypes.WATER or 
                       neighborType == CellTypes.SAND or 
                       neighborType == CellTypes.FIRE or
                       neighborType == CellTypes.STEAM or
                       neighborType == CellTypes.SMOKE then
                        hasActiveCellNearby = true
                        break
                    end
                end
            end
            if hasActiveCellNearby then break end
        end
        
        return hasActiveCellNearby
    end
    
    -- All other cells are considered active
    return true
end

-- Update the cell simulation
function CellWorld:update(dt, gravity)
    -- Count active cells and build active cell list
    self.activeCellCount = 0
    
    -- Only scan every other frame for active cells to improve performance
    self.frameCount = self.frameCount + 1
    
    if self.frameCount % 2 == 0 or not next(self.activeRegions) then
        -- Reset active regions
        self.activeRegions = {}
        
        -- Divide the world into regions for spatial partitioning
        local regionSize = 16  -- Size of each region
        
        for y = 1, self.height do
            for x = 1, self.width do
                local cellType = self.cells[y][x]
                
                if cellType and cellType ~= CellTypes.EMPTY then
                    self.activeCellCount = self.activeCellCount + 1
                    
                    -- Check if this cell is active
                    if self:isActiveCell(x, y) then
                        -- Calculate region coordinates
                        local regionX = math.floor((x - 1) / regionSize) + 1
                        local regionY = math.floor((y - 1) / regionSize) + 1
                        local regionKey = regionX .. "," .. regionY
                        
                        -- Mark this region and its neighbors as active
                        for dy = -1, 1 do
                            for dx = -1, 1 do
                                local nrx = regionX + dx
                                local nry = regionY + dy
                                local nrKey = nrx .. "," .. nry
                                
                                self.activeRegions[nrKey] = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Process exposed dirt cells to grow grass
    self:processGrassGrowth(dt)
    
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
            -- Skip cells in inactive regions
            local regionX = math.floor((x - 1) / 16) + 1
            local regionY = math.floor((y - 1) / 16) + 1
            local regionKey = regionX .. "," .. regionY
            
            if not self.activeRegions[regionKey] then
                goto continue
            end
            
            local cellType = self.cells[y][x]
            
            -- Skip empty cells and boundary cells
            if not cellType or cellType == CellTypes.EMPTY or cellType == CellTypes.BOUNDARY then
                goto continue
            end
            
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
                -- Optimize water simulation by using a simpler algorithm
                -- Try to fall down first
                if y < self.height and self:getCell(x, y + 1) == CellTypes.EMPTY then
                    self:setCell(x, y, CellTypes.EMPTY)
                    self:setCell(x, y + 1, CellTypes.WATER, cellColor)
                else
                    -- Try to flow horizontally (only check immediate neighbors for better performance)
                    local leftEmpty = x > 1 and self:getCell(x - 1, y) == CellTypes.EMPTY
                    local rightEmpty = x < self.width and self:getCell(x + 1, y) == CellTypes.EMPTY
                    
                    if leftEmpty and rightEmpty then
                        -- Choose randomly
                        if math.random() < 0.5 then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x - 1, y, CellTypes.WATER, cellColor)
                        else
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x + 1, y, CellTypes.WATER, cellColor)
                        end
                    elseif leftEmpty then
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x - 1, y, CellTypes.WATER, cellColor)
                    elseif rightEmpty then
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x + 1, y, CellTypes.WATER, cellColor)
                    end
                    
                    -- Try to flow diagonally down
                    if not (leftEmpty or rightEmpty) then
                        local leftDownEmpty = x > 1 and y < self.height and self:getCell(x - 1, y + 1) == CellTypes.EMPTY
                        local rightDownEmpty = x < self.width and y < self.height and self:getCell(x + 1, y + 1) == CellTypes.EMPTY
                        
                        if leftDownEmpty and rightDownEmpty then
                            -- Choose randomly
                            if math.random() < 0.5 then
                                self:setCell(x, y, CellTypes.EMPTY)
                                self:setCell(x - 1, y + 1, CellTypes.WATER, cellColor)
                            else
                                self:setCell(x, y, CellTypes.EMPTY)
                                self:setCell(x + 1, y + 1, CellTypes.WATER, cellColor)
                            end
                        elseif leftDownEmpty then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x - 1, y + 1, CellTypes.WATER, cellColor)
                        elseif rightDownEmpty then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x + 1, y + 1, CellTypes.WATER, cellColor)
                        end
                    end
                end
            end
            
            -- FIRE behavior
            if cellType == CellTypes.FIRE then
                -- Check for water cells around the fire to evaporate
                local evaporated = false
                
                -- Check below
                if y < self.height and self:getCell(x, y + 1) == CellTypes.WATER then
                    -- Get the water color
                    local waterColor = self.cellColors[y + 1][x]
                    -- Create steam with a color based on the water color but more transparent
                    local steamColor = {
                        0.8, 0.8, 0.8, 0.7  -- Light gray, semi-transparent
                    }
                    -- Replace water with empty and fire with steam
                    self:setCell(x, y + 1, CellTypes.EMPTY)
                    self:setCell(x, y, CellTypes.STEAM, steamColor)
                    evaporated = true
                end
                
                -- Check left
                if not evaporated and x > 1 and self:getCell(x - 1, y) == CellTypes.WATER then
                    -- Get the water color
                    local waterColor = self.cellColors[y][x - 1]
                    -- Create steam with a color based on the water color but more transparent
                    local steamColor = {
                        0.8, 0.8, 0.8, 0.7  -- Light gray, semi-transparent
                    }
                    -- Replace water with empty and fire with steam
                    self:setCell(x - 1, y, CellTypes.EMPTY)
                    self:setCell(x, y, CellTypes.STEAM, steamColor)
                    evaporated = true
                end
                
                -- Check right
                if not evaporated and x < self.width and self:getCell(x + 1, y) == CellTypes.WATER then
                    -- Get the water color
                    local waterColor = self.cellColors[y][x + 1]
                    -- Create steam with a color based on the water color but more transparent
                    local steamColor = {
                        0.8, 0.8, 0.8, 0.7  -- Light gray, semi-transparent
                    }
                    -- Replace water with empty and fire with steam
                    self:setCell(x + 1, y, CellTypes.EMPTY)
                    self:setCell(x, y, CellTypes.STEAM, steamColor)
                    evaporated = true
                end
                
                -- Check above
                if not evaporated and y > 1 and self:getCell(x, y - 1) == CellTypes.WATER then
                    -- Get the water color
                    local waterColor = self.cellColors[y - 1][x]
                    -- Create steam with a color based on the water color but more transparent
                    local steamColor = {
                        0.8, 0.8, 0.8, 0.7  -- Light gray, semi-transparent
                    }
                    -- Replace water with empty and fire with steam
                    self:setCell(x, y - 1, CellTypes.EMPTY)
                    self:setCell(x, y, CellTypes.STEAM, steamColor)
                    evaporated = true
                end
                
                -- If no water was evaporated, proceed with normal fire behavior
                if not evaporated then
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
            end
            
            -- STEAM behavior
            if cellType == CellTypes.STEAM then
                -- Steam rises faster than smoke
                if y > 1 and self:getCell(x, y - 1) == CellTypes.EMPTY then
                    -- Preserve the cell's color when moving
                    self:setCell(x, y, CellTypes.EMPTY)
                    self:setCell(x, y - 1, CellTypes.STEAM, cellColor)
                -- Steam can also move diagonally upward
                elseif y > 1 then
                    local leftClear = x > 1 and self:getCell(x - 1, y - 1) == CellTypes.EMPTY
                    local rightClear = x < self.width and self:getCell(x + 1, y - 1) == CellTypes.EMPTY
                    
                    if leftClear and rightClear then
                        -- Choose randomly between left and right
                        if math.random() < 0.5 then
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x - 1, y - 1, CellTypes.STEAM, cellColor)
                        else
                            self:setCell(x, y, CellTypes.EMPTY)
                            self:setCell(x + 1, y - 1, CellTypes.STEAM, cellColor)
                        end
                    elseif leftClear then
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x - 1, y - 1, CellTypes.STEAM, cellColor)
                    elseif rightClear then
                        self:setCell(x, y, CellTypes.EMPTY)
                        self:setCell(x + 1, y - 1, CellTypes.STEAM, cellColor)
                    end
                end
                
                -- Steam dissipates faster than smoke
                if math.random() < 0.03 then
                    self:setCell(x, y, CellTypes.EMPTY)
                end
                
                -- Steam gradually becomes more transparent
                if cellColor[4] > 0.2 then
                    cellColor[4] = cellColor[4] - 0.01
                    self.cellColors[y][x] = cellColor
                end
            end
            
            -- SMOKE behavior
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
            
            ::continue::
        end
    end
    
    -- Update the cell data image after simulation
    if self.frameCount % 5 == 0 then  -- Only update every 5 frames for better performance
        self:updateCellDataImage()
    end
end

-- Draw the cell world
function CellWorld:draw()
    -- Fallback to CPU rendering (shader disabled to fix visibility issues)
    -- Only render cells that are visible in the current view
    local minX = math.max(1, math.floor(1))
    local maxX = math.min(self.width, math.ceil(self.width))
    local minY = math.max(1, math.floor(1))
    local maxY = math.min(self.height, math.ceil(self.height))
    
    -- Batch similar cells together to reduce draw calls
    local cellBatches = {}
    
    for y = minY, maxY do
        for x = minX, maxX do
            local cellType = self.cells[y][x]
            if cellType and cellType ~= CellTypes.EMPTY then
                -- Make sure we have a valid color
                if not self.cellColors[y] or not self.cellColors[y][x] then
                    self.cellColors[y] = self.cellColors[y] or {}
                    self.cellColors[y][x] = CellTypes.getDefaultColor(cellType) or {1, 1, 1, 1}
                end
                
                -- Get the color
                local color = self.cellColors[y][x]
                local colorKey = table.concat({cellType, color[1], color[2], color[3], color[4] or 1}, ",")
                
                -- Add to batch
                if not cellBatches[colorKey] then
                    cellBatches[colorKey] = {
                        cellType = cellType,
                        color = color,
                        positions = {}
                    }
                end
                
                table.insert(cellBatches[colorKey].positions, {
                    x = (x-1) * self.cellSize,
                    y = (y-1) * self.cellSize
                })
            end
        end
    end
    
    -- Draw each batch with a single color setting
    for _, batch in pairs(cellBatches) do
        love.graphics.setColor(batch.color[1], batch.color[2], batch.color[3], batch.color[4] or 1)
        
        for _, pos in ipairs(batch.positions) do
            love.graphics.rectangle("fill", pos.x, pos.y, self.cellSize, self.cellSize)
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

-- Process grass growth on top of dirt
function CellWorld:processGrassGrowth(dt)
    -- Time it takes for grass to grow on dirt (in seconds)
    local grassGrowthTime = 2.0
    
    -- First, scan for dirt cells with air above them
    for y = 2, self.height do  -- Start from y=2 to ensure there's a cell above
        for x = 1, self.width do
            local cellType = self:getCell(x, y)
            local cellAbove = self:getCell(x, y - 1)
            
            -- Check if this is a dirt cell with air above it
            if cellType == CellTypes.DIRT and cellAbove == CellTypes.EMPTY then
                -- Create a unique key for this cell
                local key = x .. "," .. y
                
                -- If this cell is not already being tracked, add it
                if not self.exposedDirtCells[key] then
                    self.exposedDirtCells[key] = {
                        x = x,
                        y = y,
                        timer = 0
                    }
                end
            end
        end
    end
    
    -- Now process all tracked dirt cells
    local cellsToRemove = {}
    
    for key, cell in pairs(self.exposedDirtCells) do
        local x, y = cell.x, cell.y
        local cellType = self:getCell(x, y)
        local cellAbove = self:getCell(x, y - 1)
        
        -- Check if conditions are still valid for grass growth
        if cellType == CellTypes.DIRT and cellAbove == CellTypes.EMPTY then
            -- Increment timer
            cell.timer = cell.timer + dt
            
            -- If timer exceeds threshold, convert to grass
            if cell.timer >= grassGrowthTime then
                -- Get the dirt color and make it slightly greener for grass
                local dirtColor = self.cellColors[y][x]
                local grassColor = {
                    dirtColor[1] * 0.7,  -- Reduce red
                    dirtColor[2] * 1.3,  -- Increase green
                    dirtColor[3] * 0.7,  -- Reduce blue
                    dirtColor[4]         -- Keep same alpha
                }
                
                -- Ensure green component is not too high
                grassColor[2] = math.min(grassColor[2], 0.8)
                
                -- Convert dirt to grass
                self:setCell(x, y, CellTypes.GRASS, grassColor)
                
                -- Mark for removal from tracking
                table.insert(cellsToRemove, key)
            end
        else
            -- Conditions no longer valid, mark for removal
            table.insert(cellsToRemove, key)
        end
    end
    
    -- Remove cells that are no longer valid
    for _, key in ipairs(cellsToRemove) do
        self.exposedDirtCells[key] = nil
    end
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
