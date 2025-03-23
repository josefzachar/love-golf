-- InputHandler.lua - Main input handler that coordinates all input modules
-- This is the main entry point for input handling

local CameraController = require("src.input.CameraController")
local MaterialHandler = require("src.input.MaterialHandler")
local KeyboardHandler = require("src.input.KeyboardHandler")
local MouseHandler = require("src.input.MouseHandler")
local TouchHandler = require("src.input.TouchHandler")
local CursorRenderer = require("src.input.CursorRenderer")

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
    
    -- Mode switching
    self.mode = "shoot"  -- "spray" or "shoot" - Default to shoot mode
    
    -- Custom cursor
    self.showCustomCursor = true
    
    -- Key states
    self.keys = {}
    self.prevKeys = {} -- Track previous key states
    
    -- Debug flag
    self.debug = true
    
    -- Initialize sub-modules
    self.cameraController = CameraController.new(self)
    self.materialHandler = MaterialHandler.new(self)
    self.keyboardHandler = KeyboardHandler.new(self)
    self.mouseHandler = MouseHandler.new(self)
    self.touchHandler = TouchHandler.new(self)
    self.cursorRenderer = CursorRenderer.new(self)
    
    -- Hide the system cursor if we're using a custom one
    if self.showCustomCursor then
        love.mouse.setVisible(false)
    end
    
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
    
    -- Update camera controller
    self.cameraController:update(dt)
    
    -- Update material handler
    self.materialHandler:update(dt)
    
    -- Handle keyboard input
    self.keyboardHandler:update(dt)
end

-- Mouse pressed callback
function InputHandler:mousepressed(x, y, button)
    self.mouseX = x
    self.mouseY = y
    
    -- Delegate to mouse handler
    self.mouseHandler:mousepressed(x, y, button)
end

-- Mouse moved callback
function InputHandler:mousemoved(x, y, dx, dy)
    -- Update mouse position
    self.mouseX = x
    self.mouseY = y
    
    -- Delegate to mouse handler
    self.mouseHandler:mousemoved(x, y, dx, dy)
end

-- Mouse released callback
function InputHandler:mousereleased(x, y, button)
    -- Delegate to mouse handler
    self.mouseHandler:mousereleased(x, y, button)
end

-- Mouse wheel moved callback
function InputHandler:wheelmoved(x, y)
    -- Delegate to mouse handler
    self.mouseHandler:wheelmoved(x, y)
end

-- Key pressed callback
function InputHandler:keypressed(key)
    self.keys[key] = true
    
    -- Delegate to keyboard handler
    self.keyboardHandler:keypressed(key)
end

-- Key released callback
function InputHandler:keyreleased(key)
    self.keys[key] = false
    
    -- Delegate to keyboard handler
    self.keyboardHandler:keyreleased(key)
end

-- Touch pressed callback (for mobile)
function InputHandler:touchpressed(id, x, y)
    -- Delegate to touch handler
    self.touchHandler:touchpressed(id, x, y)
end

-- Touch moved callback (for mobile)
function InputHandler:touchmoved(id, x, y)
    -- Delegate to touch handler
    self.touchHandler:touchmoved(id, x, y)
end

-- Touch released callback (for mobile)
function InputHandler:touchreleased(id, x, y)
    -- Delegate to touch handler
    self.touchHandler:touchreleased(id, x, y)
end

-- Draw the custom cursor and material indicator
function InputHandler:draw()
    -- Only draw if we're showing the custom cursor
    if not self.showCustomCursor then return end
    
    -- Delegate to cursor renderer
    self.cursorRenderer:draw()
end

return InputHandler
