-- CursorRenderer.lua - Handles drawing the custom cursor and material indicator

local CursorRenderer = {}
CursorRenderer.__index = CursorRenderer

function CursorRenderer.new(inputHandler)
    local self = setmetatable({}, CursorRenderer)
    
    -- Reference to parent input handler
    self.inputHandler = inputHandler
    
    -- Material indicator
    self.materialIndicator = {
        x = 20,
        y = 150,
        width = 40,
        height = 40,
        padding = 5
    }
    
    return self
end

-- Draw the custom cursor and material indicator
function CursorRenderer:draw()
    -- Draw the material indicator
    self:drawMaterialIndicator()
    
    -- Draw the custom cursor
    self:drawCustomCursor()
    
    -- Draw the current mode
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Mode: " .. (self.inputHandler.mode == "spray" and "Spray (Space to toggle)" or "Shoot (Space to toggle)"), 10, 130)
end

-- Draw the custom cursor
function CursorRenderer:drawCustomCursor()
    local mouseX = self.inputHandler.mouseX
    local mouseY = self.inputHandler.mouseY
    local mode = self.inputHandler.mode
    local mouseDown = self.inputHandler.mouseDown
    local cameraActive = self.inputHandler.cameraController:isDragging()
    
    -- Get the current material color
    local color = self.inputHandler.materialHandler:getCurrentMaterialColor()
    
    -- In spray mode, draw a spray can cursor
    if mode == "spray" then
        love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Dark gray for the can
        
        -- Can body
        love.graphics.rectangle("fill", mouseX - 8, mouseY - 4, 16, 20)
        
        -- Can top
        love.graphics.rectangle("fill", mouseX - 6, mouseY - 10, 12, 6)
        
        -- Spray nozzle
        love.graphics.rectangle("fill", mouseX - 2, mouseY - 14, 4, 4)
        
        -- Material color indicator on the can
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", mouseX - 6, mouseY, 12, 12)
        
        -- Draw spray particles if mouse is down
        if mouseDown and not cameraActive then
            -- Draw some spray particles
            for i = 1, 5 do
                local angle = math.random() * math.pi * 0.5 - math.pi * 0.25  -- -45 to 45 degrees
                local distance = math.random(10, 20)
                local x = mouseX + math.cos(angle) * distance
                local y = mouseY - 16 + math.sin(angle) * distance  -- From the nozzle
                
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
        love.graphics.circle("line", mouseX, mouseY, 12)
        
        -- Inner circle
        love.graphics.circle("line", mouseX, mouseY, 6)
        
        -- Crosshair lines
        love.graphics.line(mouseX - 16, mouseY, mouseX - 8, mouseY)
        love.graphics.line(mouseX + 8, mouseY, mouseX + 16, mouseY)
        love.graphics.line(mouseX, mouseY - 16, mouseX, mouseY - 8)
        love.graphics.line(mouseX, mouseY + 8, mouseX, mouseY + 16)
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the material indicator
function CursorRenderer:drawMaterialIndicator()
    -- Only show material indicator in spray mode
    if self.inputHandler.mode ~= "spray" then return end
    
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
    
    -- Get material info
    local materialColor = self.inputHandler.materialHandler:getCurrentMaterialColor()
    local materialName = self.inputHandler.materialHandler:getCurrentMaterialName()
    local brushSize = self.inputHandler.materialHandler.brushSize
    
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
    love.graphics.print("Brush: " .. brushSize, x + width + 10, y + height/2 + font:getHeight())
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return CursorRenderer
