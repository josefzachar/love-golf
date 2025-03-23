-- BallManager.lua - Manages the ball and its physics
-- Circle physics with multi-cell visual representation

local BallTypes = require("src.balls.BallTypes")
local CellTypes = require("src.cells.CellTypes")

-- Import component modules
local BallPhysics = require("src.balls.components.BallPhysics")
local BallRendering = require("src.balls.components.BallRendering")
local BallInteractions = require("src.balls.components.BallInteractions")
local BallInput = require("src.balls.components.BallInput")

local BallManager = {}
BallManager.__index = BallManager

-- Create a new ball manager
function BallManager.new(cellWorld)
    local self = setmetatable({}, BallManager)
    
    -- Reference to the cell world
    self.cellWorld = cellWorld
    
    -- Make types accessible to component modules
    self.BallTypes = BallTypes
    self.CellTypes = CellTypes
    
    -- Current ball properties
    self.position = {x = 0, y = 0}
    self.velocity = {x = 0, y = 0}
    self.type = BallTypes.BALL
    self.radius = 1.5  -- Ball radius in cells (increased for 3x3 ball)
    self.active = false
    self.inHole = false
    
    -- Ball rotation properties
    self.rotation = 0  -- Current rotation in radians
    self.lastPosition = {x = 0, y = 0}  -- Last position for calculating movement
    
    -- Ball cells pattern (3x3 grid of cells)
    self.ballCells = {}
    self:initializeBallCells()
    
    -- Physics constants
    self.gravity = 500  -- Gravity acceleration (increased from 0.5 to match previous level2 value)
    self.friction = 0.98  -- Default friction (air)
    self.bounceFactor = 0.7  -- Default bounce factor
    self.maxVelocity = 2000  -- Maximum velocity cap
    self.restThreshold = 0.1 -- Threshold for considering the ball at rest
    
    -- Material properties
    self.materialProperties = {
        [CellTypes.STONE] = {
            solid = true,
            bounceFactor = 0.8,  -- Stone is more bouncy
            friction = 0.2,      -- Low friction
            strength = 5.0,      -- Very strong (hard to penetrate)
            elasticity = 1.2     -- Very elastic (bouncy)
        },
        [CellTypes.DIRT] = {
            solid = true,
            bounceFactor = 0.5,  -- Dirt absorbs more energy
            friction = 0.4,      -- Medium friction
            strength = 3.0,      -- Medium strength
            elasticity = 0.7     -- Less elastic than stone
        },
        [CellTypes.SAND] = {
            solid = false,
            bounceFactor = 0.2,  -- Sand absorbs most energy
            friction = 0.7,      -- High friction
            strength = 1.0,      -- Low strength (easy to penetrate)
            elasticity = 0.3,    -- Not very elastic
            displacement = 0.5   -- Can be displaced (crater formation)
        },
        [CellTypes.WATER] = {
            solid = false,
            liquid = true,
            bounceFactor = 0.1,  -- Almost no bounce
            friction = 0.3,      -- Medium-low friction
            viscosity = 0.6,     -- Medium viscosity
            buoyancy = 0.8,      -- High buoyancy
            displacement = 0.3   -- Can be displaced (splash effect)
        }
    }
    
    -- Shot properties
    self.isAiming = false
    self.clickPosition = {x = 0, y = 0}  -- Initial click position
    self.currentMousePosition = {x = 0, y = 0}  -- Current mouse position
    self.maxPower = 10
    self.powerMultiplier = 0.08  -- Multiplier for shot power
    
    -- Pixel art settings
    self.pixelSize = 2  -- Size of "pixels" for the pixel art effect
    
    -- Material interaction flags
    self.inSand = false
    self.inWater = false
    self.sinkingInWater = false
    self.sinkTimer = 0
    self.craterCreated = false
    
    -- Debug flag
    self.debug = true
    
    -- Force the ball to be active for testing
    self.active = true
    
    return self
end

-- Initialize the ball cells pattern (3x3 grid)
function BallManager:initializeBallCells()
    -- Create a 3x3 pattern of cells
    self.ballCells = {}
    
    -- Create a circular pattern
    local offsets = {
        {x = -1, y = -1}, {x = 0, y = -1}, {x = 1, y = -1},
        {x = -1, y = 0},  {x = 0, y = 0},  {x = 1, y = 0},
        {x = -1, y = 1},  {x = 0, y = 1},  {x = 1, y = 1}
    }
    
    -- Add each cell to the pattern with a pattern value (checkerboard)
    for i, offset in ipairs(offsets) do
        -- Determine pattern value (checkerboard pattern)
        local pattern = (offset.x + offset.y) % 2 == 0
        
        table.insert(self.ballCells, {
            offset = offset,
            pattern = pattern
        })
    end
end

-- Reset the ball to a starting position
function BallManager:reset(position, ballType, initialVelocity)
    -- Ensure the ball is positioned at the center of a cell
    self.position = {
        x = math.floor(position.x) + 0.5, 
        y = math.floor(position.y) + 0.5
    }
    self.velocity = initialVelocity or {x = 0, y = 0}
    self.type = BallTypes.BALL  -- Always use BALL type
    self.active = true
    self.inHole = false
    
    -- Reset rotation
    self.rotation = 0
    self.lastPosition = {x = self.position.x, y = self.position.y}
    
    -- Reset aiming
    self.isAiming = false
    self.clickPosition = {x = 0, y = 0}
    self.currentMousePosition = {x = 0, y = 0}
    
    -- Reset material interaction flags
    self.inSand = false
    self.inWater = false
    self.sinkingInWater = false
    self.sinkTimer = 0
    self.craterCreated = false
    
    if self.debug then
        print("[BALL] Reset at position: " .. self.position.x .. ", " .. self.position.y)
    end
end

-- Delegate to component modules

-- Physics methods
function BallManager:update(dt)
    BallPhysics.update(self, dt)
end

function BallManager:updateBallRotation(dt)
    BallPhysics.updateBallRotation(self, dt)
end

function BallManager:handleCollisions(oldX, oldY, dt)
    BallPhysics.handleCollisions(self, oldX, oldY, dt)
end

function BallManager:isMoving()
    return BallPhysics.isMoving(self)
end

function BallManager:canShoot()
    return BallPhysics.canShoot(self)
end

function BallManager:checkHole()
    return BallPhysics.checkHole(self)
end

-- Rendering methods
function BallManager:draw()
    BallRendering.draw(self)
end

function BallManager:drawPixelatedDottedLine(startX, startY, endX, endY, color, dashLength, gapLength, thickness)
    BallRendering.drawPixelatedDottedLine(self, startX, startY, endX, endY, color, dashLength, gapLength, thickness)
end

function BallManager:drawPixelatedArrowhead(x, y, dirX, dirY, color, size)
    BallRendering.drawPixelatedArrowhead(self, x, y, dirX, dirY, color, size)
end

function BallManager:createImpactEffect(cellX, cellY, cellType, impactForce)
    BallRendering.createImpactEffect(self, cellX, cellY, cellType, impactForce)
end

-- Material interaction methods
function BallManager:handleMaterialInteractions(cellType, dt)
    BallInteractions.handleMaterialInteractions(self, cellType, dt)
end

function BallManager:applyWaterPhysics(dt)
    BallInteractions.applyWaterPhysics(self, dt)
end

function BallManager:applySandPhysics(dt)
    BallInteractions.applySandPhysics(self, dt)
end

function BallManager:handleWaterSinking(dt)
    BallInteractions.handleWaterSinking(self, dt)
end

function BallManager:createSandDepression()
    BallInteractions.createSandDepression(self)
end

function BallManager:getMaterialBounceFactor(cellType)
    return BallInteractions.getMaterialBounceFactor(self, cellType)
end

function BallManager:getMaterialName(cellType)
    return BallInteractions.getMaterialName(self, cellType)
end

-- Input methods
function BallManager:startAiming(mouseX, mouseY)
    BallInput.startAiming(self, mouseX, mouseY)
end

function BallManager:updateAim(mouseX, mouseY)
    BallInput.updateAim(self, mouseX, mouseY)
end

function BallManager:shoot()
    return BallInput.shoot(self)
end

function BallManager:cancelShot()
    BallInput.cancelShot(self)
end

function BallManager:getCurrentBall()
    return BallInput.getCurrentBall(self)
end

function BallManager:getCurrentBallType()
    return BallInput.getCurrentBallType(self)
end

function BallManager:isInHole()
    return BallInput.isInHole(self)
end

-- Return the module
return BallManager
