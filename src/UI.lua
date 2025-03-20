-- UI.lua - Handles the game's user interface

local UI = {}
UI.__index = UI

-- Create a new UI
function UI.new(gameState, ballManager)
    local self = setmetatable({}, UI)
    
    -- References to other modules
    self.gameState = gameState
    self.ballManager = ballManager
    
    -- UI elements
    self.elements = {}
    
    -- Fonts
    self.fonts = {
        small = love.graphics.newFont(14),
        medium = love.graphics.newFont(20),
        large = love.graphics.newFont(32),
        title = love.graphics.newFont(48)
    }
    
    -- Colors
    self.colors = {
        background = {0.1, 0.1, 0.1, 0.7},
        text = {1, 1, 1, 1},
        highlight = {0.8, 0.8, 0.2, 1},
        button = {0.3, 0.3, 0.3, 1},
        buttonHover = {0.4, 0.4, 0.4, 1},
        buttonText = {1, 1, 1, 1},
        panel = {0.2, 0.2, 0.2, 0.9}
    }
    
    -- Transition effects
    self.fadeAlpha = 0
    
    -- Initialize UI elements
    self:initializeUI()
    
    return self
end

-- Initialize UI elements
function UI:initializeUI()
    -- Create UI elements based on game state
    self:createMenuUI()
    self:createHUD()
    self:createPauseMenu()
    self:createLevelCompleteUI()
    self:createGameOverUI()
end

-- Create main menu UI
function UI:createMenuUI()
    -- Main menu elements
    self.elements.menu = {
        title = {
            type = "text",
            text = "Cellular Golf",
            font = self.fonts.title,
            color = self.colors.highlight,
            x = love.graphics.getWidth() / 2,
            y = 100,
            align = "center"
        },
        startButton = {
            type = "button",
            text = "Start Game",
            font = self.fonts.large,
            x = love.graphics.getWidth() / 2 - 100,
            y = 250,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
                onClick = function()
                    -- Load level 2 for material debugging
                    loadLevel(2)  -- This is a global function defined in main.lua
                    self.gameState:setState("PLAYING")
                end
        },
        settingsButton = {
            type = "button",
            text = "Settings",
            font = self.fonts.large,
            x = love.graphics.getWidth() / 2 - 100,
            y = 320,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                -- TODO: Show settings menu
            end
        },
        exitButton = {
            type = "button",
            text = "Exit",
            font = self.fonts.large,
            x = love.graphics.getWidth() / 2 - 100,
            y = 390,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                love.event.quit()
            end
        }
    }
end

-- Create in-game HUD
function UI:createHUD()
    -- HUD elements
    self.elements.hud = {
        levelInfo = {
            type = "text",
            getText = function()
                return "Level " .. self.gameState:getCurrentLevel()
            end,
            font = self.fonts.medium,
            color = self.colors.text,
            x = 20,
            y = 20,
            align = "left"
        },
        shotCounter = {
            type = "text",
            getText = function()
                return "Shots: " .. self.gameState:getShots() .. " / Par: " .. self.gameState:getPar()
            end,
            font = self.fonts.medium,
            color = self.colors.text,
            x = 20,
            y = 50,
            align = "left"
        },
        ballType = {
            type = "text",
            getText = function()
                return "Ball: " .. self.ballManager:getCurrentBallType()
            end,
            font = self.fonts.medium,
            color = self.colors.text,
            x = 20,
            y = 80,
            align = "left"
        },
        materialInfo = {
            type = "text",
            getText = function()
                -- Access the global input handler to get material info
                local inputHandler = _G.inputHandler
                if not inputHandler then return "Material: Unknown" end
                
                local materialName = "Unknown"
                if inputHandler.currentMaterial == 20 then
                    materialName = "Sand"
                elseif inputHandler.currentMaterial == 30 then
                    materialName = "Water"
                elseif inputHandler.currentMaterial == 40 then
                    materialName = "Fire"
                elseif inputHandler.currentMaterial == 10 then
                    materialName = "Stone"
                elseif inputHandler.currentMaterial == 11 then
                    materialName = "Dirt"
                end
                
                return "Material: " .. materialName .. " (Brush: " .. (inputHandler.brushSize or 3) .. ")"
            end,
            font = self.fonts.medium,
            color = self.colors.highlight,
            x = 20,
            y = 110,
            align = "left"
        },
        pauseButton = {
            type = "button",
            text = "II",
            font = self.fonts.medium,
            x = love.graphics.getWidth() - 60,
            y = 20,
            width = 40,
            height = 40,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setState("PAUSED")
            end
        }
    }
end

-- Create pause menu
function UI:createPauseMenu()
    -- Pause menu elements
    self.elements.pause = {
        title = {
            type = "text",
            text = "Paused",
            font = self.fonts.large,
            color = self.colors.highlight,
            x = love.graphics.getWidth() / 2,
            y = 100,
            align = "center"
        },
        resumeButton = {
            type = "button",
            text = "Resume",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 200,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setState("PLAYING")
            end
        },
        restartButton = {
            type = "button",
            text = "Restart Level",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 270,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                -- Restart current level
                self.gameState:setCurrentLevel(self.gameState:getCurrentLevel())
                self.gameState:setState("PLAYING")
            end
        },
        menuButton = {
            type = "button",
            text = "Main Menu",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 340,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setState("MENU")
            end
        }
    }
end

-- Create level complete UI
function UI:createLevelCompleteUI()
    -- Level complete elements
    self.elements.levelComplete = {
        title = {
            type = "text",
            text = "Level Complete!",
            font = self.fonts.large,
            color = self.colors.highlight,
            x = love.graphics.getWidth() / 2,
            y = 100,
            align = "center"
        },
        scoreInfo = {
            type = "text",
            getText = function()
                local shots = self.gameState:getShots()
                local par = self.gameState:getPar()
                local diff = shots - par
                
                local scoreText = "Shots: " .. shots .. " / Par: " .. par
                
                if diff < 0 then
                    return scoreText .. " (" .. diff .. ", Birdie!)"
                elseif diff == 0 then
                    return scoreText .. " (Par)"
                else
                    return scoreText .. " (+" .. diff .. ")"
                end
            end,
            font = self.fonts.medium,
            color = self.colors.text,
            x = love.graphics.getWidth() / 2,
            y = 180,
            align = "center"
        },
        nextButton = {
            type = "button",
            text = "Next Level",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 250,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:nextLevel()
            end
        },
        restartButton = {
            type = "button",
            text = "Restart Level",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 320,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setCurrentLevel(self.gameState:getCurrentLevel())
                self.gameState:setState("PLAYING")
            end
        }
    }
end

-- Create game over UI
function UI:createGameOverUI()
    -- Game over elements
    self.elements.gameOver = {
        title = {
            type = "text",
            text = "Game Complete!",
            font = self.fonts.large,
            color = self.colors.highlight,
            x = love.graphics.getWidth() / 2,
            y = 100,
            align = "center"
        },
        message = {
            type = "text",
            text = "Congratulations on completing all levels!",
            font = self.fonts.medium,
            color = self.colors.text,
            x = love.graphics.getWidth() / 2,
            y = 180,
            align = "center"
        },
        restartButton = {
            type = "button",
            text = "Play Again",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 250,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setCurrentLevel(1)
                self.gameState:setState("PLAYING")
            end
        },
        menuButton = {
            type = "button",
            text = "Main Menu",
            font = self.fonts.medium,
            x = love.graphics.getWidth() / 2 - 100,
            y = 320,
            width = 200,
            height = 50,
            color = self.colors.button,
            hoverColor = self.colors.buttonHover,
            textColor = self.colors.buttonText,
            onClick = function()
                self.gameState:setState("MENU")
            end
        }
    }
end

-- Update UI
function UI:update(dt)
    -- Update fade effect for transitions
    if self.gameState:isTransitioning() then
        self.fadeAlpha = self.gameState:getTransitionProgress()
    else
        self.fadeAlpha = 0
    end
    
    -- Update UI element positions if window size changes
    local width, height = love.graphics.getDimensions()
    
    -- Update menu elements
    if self.elements.menu then
        self.elements.menu.title.x = width / 2
        self.elements.menu.startButton.x = width / 2 - 100
        self.elements.menu.settingsButton.x = width / 2 - 100
        self.elements.menu.exitButton.x = width / 2 - 100
    end
    
    -- Update HUD elements
    if self.elements.hud then
        self.elements.hud.pauseButton.x = width - 60
    end
    
    -- Update pause menu elements
    if self.elements.pause then
        self.elements.pause.title.x = width / 2
        self.elements.pause.resumeButton.x = width / 2 - 100
        self.elements.pause.restartButton.x = width / 2 - 100
        self.elements.pause.menuButton.x = width / 2 - 100
    end
    
    -- Update level complete elements
    if self.elements.levelComplete then
        self.elements.levelComplete.title.x = width / 2
        self.elements.levelComplete.scoreInfo.x = width / 2
        self.elements.levelComplete.nextButton.x = width / 2 - 100
        self.elements.levelComplete.restartButton.x = width / 2 - 100
    end
    
    -- Update game over elements
    if self.elements.gameOver then
        self.elements.gameOver.title.x = width / 2
        self.elements.gameOver.message.x = width / 2
        self.elements.gameOver.restartButton.x = width / 2 - 100
        self.elements.gameOver.menuButton.x = width / 2 - 100
    end
end

-- Draw UI
function UI:draw()
    -- Draw UI based on current game state
    local state = self.gameState:getState()
    
    if state == "menu" then
        self:drawMenu()
    elseif state == "playing" then
        self:drawHUD()
    elseif state == "paused" then
        self:drawHUD()
        self:drawPauseMenu()
    elseif state == "level_complete" then
        self:drawHUD()
        self:drawLevelComplete()
    elseif state == "game_over" then
        self:drawGameOver()
    end
    
    -- Draw transition effect
    if self.fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, self.fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
end

-- Draw main menu
function UI:drawMenu()
    -- Draw background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    local title = self.elements.menu.title
    love.graphics.setFont(title.font)
    love.graphics.setColor(title.color)
    love.graphics.printf(title.text, title.x - 200, title.y, 400, title.align)
    
    -- Draw buttons
    self:drawButton(self.elements.menu.startButton)
    self:drawButton(self.elements.menu.settingsButton)
    self:drawButton(self.elements.menu.exitButton)
end

-- Draw HUD
function UI:drawHUD()
    -- Draw level info
    local levelInfo = self.elements.hud.levelInfo
    love.graphics.setFont(levelInfo.font)
    love.graphics.setColor(levelInfo.color)
    love.graphics.printf(levelInfo.getText(), levelInfo.x, levelInfo.y, 300, levelInfo.align)
    
    -- Draw shot counter
    local shotCounter = self.elements.hud.shotCounter
    love.graphics.setFont(shotCounter.font)
    love.graphics.setColor(shotCounter.color)
    love.graphics.printf(shotCounter.getText(), shotCounter.x, shotCounter.y, 300, shotCounter.align)
    
    -- Draw ball type
    local ballType = self.elements.hud.ballType
    love.graphics.setFont(ballType.font)
    love.graphics.setColor(ballType.color)
    love.graphics.printf(ballType.getText(), ballType.x, ballType.y, 300, ballType.align)
    
    -- Draw material info
    local materialInfo = self.elements.hud.materialInfo
    if materialInfo then
        love.graphics.setFont(materialInfo.font)
        love.graphics.setColor(materialInfo.color)
        love.graphics.printf(materialInfo.getText(), materialInfo.x, materialInfo.y, 300, materialInfo.align)
    end
    
    -- Draw pause button
    self:drawButton(self.elements.hud.pauseButton)
end

-- Draw pause menu
function UI:drawPauseMenu()
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    local title = self.elements.pause.title
    love.graphics.setFont(title.font)
    love.graphics.setColor(title.color)
    love.graphics.printf(title.text, title.x - 200, title.y, 400, title.align)
    
    -- Draw buttons
    self:drawButton(self.elements.pause.resumeButton)
    self:drawButton(self.elements.pause.restartButton)
    self:drawButton(self.elements.pause.menuButton)
end

-- Draw level complete screen
function UI:drawLevelComplete()
    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    local title = self.elements.levelComplete.title
    love.graphics.setFont(title.font)
    love.graphics.setColor(title.color)
    love.graphics.printf(title.text, title.x - 200, title.y, 400, title.align)
    
    -- Draw score info
    local scoreInfo = self.elements.levelComplete.scoreInfo
    love.graphics.setFont(scoreInfo.font)
    love.graphics.setColor(scoreInfo.color)
    love.graphics.printf(scoreInfo.getText(), scoreInfo.x - 200, scoreInfo.y, 400, scoreInfo.align)
    
    -- Draw buttons
    self:drawButton(self.elements.levelComplete.nextButton)
    self:drawButton(self.elements.levelComplete.restartButton)
end

-- Draw game over screen
function UI:drawGameOver()
    -- Draw background
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    local title = self.elements.gameOver.title
    love.graphics.setFont(title.font)
    love.graphics.setColor(title.color)
    love.graphics.printf(title.text, title.x - 200, title.y, 400, title.align)
    
    -- Draw message
    local message = self.elements.gameOver.message
    love.graphics.setFont(message.font)
    love.graphics.setColor(message.color)
    love.graphics.printf(message.text, message.x - 300, message.y, 600, message.align)
    
    -- Draw buttons
    self:drawButton(self.elements.gameOver.restartButton)
    self:drawButton(self.elements.gameOver.menuButton)
end

-- Draw a button
function UI:drawButton(button)
    -- Check if mouse is hovering over button
    local mx, my = love.mouse.getPosition()
    local hover = mx >= button.x and mx <= button.x + button.width and
                  my >= button.y and my <= button.y + button.height
    
    -- Draw button background
    if hover then
        love.graphics.setColor(button.hoverColor)
    else
        love.graphics.setColor(button.color)
    end
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
    
    -- Draw button text
    love.graphics.setFont(button.font)
    love.graphics.setColor(button.textColor)
    love.graphics.printf(button.text, button.x, button.y + (button.height - button.font:getHeight()) / 2, 
                         button.width, "center")
end

-- Handle mouse press
function UI:mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    -- Debug output
    print("UI:mousepressed", x, y, button)
    print("Current game state:", self.gameState:getState())
    
    -- Check which UI elements to check based on game state
    local state = self.gameState:getState()
    local elements = {}
    
    if state == "menu" then
        elements = self.elements.menu
        print("Checking menu elements")
    elseif state == "playing" then
        elements = self.elements.hud
        print("Checking HUD elements")
    elseif state == "paused" then
        elements = self.elements.pause
        print("Checking pause elements")
    elseif state == "level_complete" then
        elements = self.elements.levelComplete
        print("Checking level complete elements")
    elseif state == "game_over" then
        elements = self.elements.gameOver
        print("Checking game over elements")
    end
    
    -- Check for button clicks
    for name, element in pairs(elements) do
        if element.type == "button" then
            print("Checking button:", name, element.x, element.y, element.width, element.height)
            if x >= element.x and x <= element.x + element.width and
               y >= element.y and y <= element.y + element.height then
                print("Button clicked:", name)
                if element.onClick then
                    print("Executing onClick for:", name)
                    element.onClick()
                    print("After onClick, game state:", self.gameState:getState())
                end
                return true
            end
        end
    end
    
    return false
end

return UI
