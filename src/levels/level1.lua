-- level1.lua - First level of the game

local CellTypes = require("src.cells.CellTypes")
local BallTypes = require("src.balls.BallTypes")

local level = {}

-- Level properties
level.name = "Tutorial"
level.description = "Learn the basics of Cellular Golf"
level.par = 3

-- Starting position and ball type
level.startPosition = {x = 25, y = 25}  -- Adjusted for smaller world
level.ballType = BallTypes.BALL

-- Hole position
level.holePosition = {x = 85, y = 40}  -- Adjusted for smaller world

-- Cell data for the level
level.cells = {}

-- Create a completely new level for the smaller world size
level.cells = {}  -- Clear existing cells

-- Create ground
for x = 5, 95 do
    for y = 50, 65 do
        -- Add some variation to the ground
        local cellType = CellTypes.DIRT
        
        -- Random stone blocks
        if math.random() < 0.1 then
            cellType = CellTypes.STONE
        end
        
        -- Add cell with slight color variation
        local baseColor = CellTypes.getDefaultColor(cellType)
        local colorVar = 0.1
        local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * colorVar))
        local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * colorVar))
        local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * colorVar))
        
        table.insert(level.cells, {
            x = x,
            y = y,
            type = cellType,
            color = {r, g, b, 1}
        })
    end
end

-- Create a small hill
for x = 25, 35 do
    for y = 45, 50 do
        local cellType = CellTypes.DIRT
        local baseColor = CellTypes.getDefaultColor(cellType)
        local colorVar = 0.1
        local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * colorVar))
        local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * colorVar))
        local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * colorVar))
        
        table.insert(level.cells, {
            x = x,
            y = y,
            type = cellType,
            color = {r, g, b, 1}
        })
    end
end

-- Create a small pit with water
for x = 50, 60 do
    for y = 45, 50 do
        local cellType = CellTypes.WATER
        local baseColor = CellTypes.getDefaultColor(cellType)
        local colorVar = 0.1
        local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * colorVar))
        local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * colorVar))
        local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * colorVar))
        
        table.insert(level.cells, {
            x = x,
            y = y,
            type = cellType,
            color = {r, g, b, baseColor[4]}
        })
    end
end

-- Create some sand traps
for x = 70, 78 do
    for y = 45, 50 do
        local cellType = CellTypes.SAND
        local baseColor = CellTypes.getDefaultColor(cellType)
        local colorVar = 0.1
        local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * colorVar))
        local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * colorVar))
        local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * colorVar))
        
        table.insert(level.cells, {
            x = x,
            y = y,
            type = cellType,
            color = {r, g, b, 1}
        })
    end
end

-- Create a small platform for the hole
for x = 85, 90 do
    for y = 45, 50 do
        local cellType = CellTypes.DIRT
        local baseColor = CellTypes.getDefaultColor(cellType)
        local colorVar = 0.1
        local r = math.max(0, math.min(1, baseColor[1] + (math.random() - 0.5) * colorVar))
        local g = math.max(0, math.min(1, baseColor[2] + (math.random() - 0.5) * colorVar))
        local b = math.max(0, math.min(1, baseColor[3] + (math.random() - 0.5) * colorVar))
        
        table.insert(level.cells, {
            x = x,
            y = y,
            type = cellType,
            color = {r, g, b, 1}
        })
    end
end

-- Create the hole
for x = 87, 88 do
    for y = 44, 45 do
        table.insert(level.cells, {
            x = x,
            y = y,
            type = CellTypes.HOLE,
            color = {0, 0, 0, 1}
        })
    end
end

-- Create some decorative elements

-- Add some grass on top of the ground
for x = 5, 95, 1 do
    local grassHeight = math.random(1, 2)
    for y = 49 - grassHeight, 49 do
        if math.random() < 0.5 then
            local greenShade = 0.5 + math.random() * 0.3
            table.insert(level.cells, {
                x = x,
                y = y,
                type = CellTypes.DIRT,
                color = {0.2, greenShade, 0.1, 1}
            })
        end
    end
end

-- Add a flag at the hole
for y = 40, 44 do
    table.insert(level.cells, {
        x = 87,
        y = y,
        type = CellTypes.WOOD,
        color = {0.6, 0.4, 0.2, 1}
    })
end

-- Add flag cloth
for x = 88, 90 do
    for y = 40, 42 do
        table.insert(level.cells, {
            x = x,
            y = y,
            type = CellTypes.FLAG,
            color = {1, 0, 0, 1}
        })
    end
end

-- Add some clouds in the sky
local function addCloud(centerX, centerY, size)
    for x = centerX - size, centerX + size do
        for y = centerY - size/2, centerY + size/2 do
            local dx = x - centerX
            local dy = y - centerY
            local distSq = (dx*dx) / (size*size) + (dy*dy) / ((size/2)*(size/2))
            
            if distSq <= 1 and math.random() < 0.7 then
                local whiteness = 0.9 + math.random() * 0.1
                table.insert(level.cells, {
                    x = x,
                    y = y,
                    type = CellTypes.STEAM,
                    color = {whiteness, whiteness, whiteness, 0.8}
                })
            end
        end
    end
end

addCloud(25, 20, 4)
addCloud(50, 15, 5)
addCloud(75, 22, 3)

return level
