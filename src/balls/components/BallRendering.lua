-- BallRendering.lua - Drawing and visual functions for the ball

local BallRendering = {}

-- Draw a pixelated dotted line
function BallRendering.drawPixelatedDottedLine(ball, startX, startY, endX, endY, color, dashLength, gapLength, thickness)
    -- Calculate direction vector
    local dx = endX - startX
    local dy = endY - startY
    local distance = math.sqrt(dx*dx + dy*dy)
    
    if distance == 0 then return end
    
    local dirX = dx / distance
    local dirY = dy / distance
    
    -- Default values
    dashLength = dashLength or 8
    gapLength = gapLength or 12
    thickness = thickness or 4
    
    -- Draw individual square "dots"
    local currentDistance = 0
    while currentDistance < distance do
        local dotX = startX + dirX * currentDistance
        local dotY = startY + dirY * currentDistance
        
        -- Round to pixel grid for pixelated look
        dotX = math.floor(dotX / ball.pixelSize) * ball.pixelSize
        dotY = math.floor(dotY / ball.pixelSize) * ball.pixelSize
        
        -- Draw a single square "dot"
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", 
                               dotX - thickness/2, 
                               dotY - thickness/2, 
                               thickness, 
                               thickness)
        
        -- Move to next dot position
        currentDistance = currentDistance + dashLength + gapLength
    end
end

-- Draw a pixelated arrowhead
function BallRendering.drawPixelatedArrowhead(ball, x, y, dirX, dirY, color, size)
    -- Default size
    size = size or 10
    
    -- Calculate points for a pixelated arrow
    local backDirX = -dirX
    local backDirY = -dirY
    
    -- Rotate back direction by 45 degrees for right point
    local rightDirX = backDirX * math.cos(math.pi/4) - backDirY * math.sin(math.pi/4)
    local rightDirY = backDirX * math.sin(math.pi/4) + backDirY * math.cos(math.pi/4)
    
    -- Rotate back direction by -45 degrees for left point
    local leftDirX = backDirX * math.cos(-math.pi/4) - backDirY * math.sin(-math.pi/4)
    local leftDirY = backDirX * math.sin(-math.pi/4) + backDirY * math.cos(-math.pi/4)
    
    -- Calculate the three points of the triangle
    local rightX = x + rightDirX * size
    local rightY = y + rightDirY * size
    
    local leftX = x + leftDirX * size
    local leftY = y + leftDirY * size
    
    -- Draw the filled triangle
    love.graphics.setColor(color)
    love.graphics.polygon("fill", x, y, rightX, rightY, leftX, leftY)
end

-- Draw the ball and aiming line
function BallRendering.draw(ball)
    if not ball.active then return end
    
    local cellSize = ball.cellWorld.cellSize
    
    -- Calculate screen position - center of the ball
    local centerX = ball.position.x * cellSize
    local centerY = ball.position.y * cellSize
    
    -- Get ball color
    local ballColor = ball.BallTypes.getColor(ball.type)
    
    -- Create color variants for the pattern
    local mainColor = {ballColor[1], ballColor[2], ballColor[3], ballColor[4] or 1}
    
    -- Create a slightly darker variant for pattern
    local patternColor = {
        ballColor[1] * 0.7,
        ballColor[2] * 0.7,
        ballColor[3] * 0.7,
        ballColor[4] or 1
    }
    
    -- Create a lighter variant for highlights
    local highlightColor = {
        math.min(1.0, ballColor[1] * 1.3),
        math.min(1.0, ballColor[2] * 1.3),
        math.min(1.0, ballColor[3] * 1.3),
        ballColor[4] or 1
    }
    
    -- If the ball is sinking in water, adjust the opacity
    if ball.sinkingInWater then
        local sinkDuration = 3.0
        local sinkProgress = math.min(ball.sinkTimer / sinkDuration, 1.0)
        mainColor[4] = mainColor[4] * (1.0 - sinkProgress)
        patternColor[4] = patternColor[4] * (1.0 - sinkProgress)
        highlightColor[4] = highlightColor[4] * (1.0 - sinkProgress)
    end
    
    -- Draw each cell of the ball with rotation
    for _, cell in ipairs(ball.ballCells) do
        -- Apply rotation to the cell offset
        local rotatedX = cell.offset.x * math.cos(ball.rotation) - cell.offset.y * math.sin(ball.rotation)
        local rotatedY = cell.offset.x * math.sin(ball.rotation) + cell.offset.y * math.cos(ball.rotation)
        
        -- Calculate pixel position after rotation
        local pixelX = centerX + rotatedX * cellSize
        local pixelY = centerY + rotatedY * cellSize
        
        -- Determine color based on pattern
        local pixelColor
        if cell.pattern then
            pixelColor = mainColor
        else
            pixelColor = patternColor
        end
        
        -- Create a small 3D effect with highlight - top-left quadrant gets highlight
        local normalizedOffset = {
            x = rotatedX,
            y = rotatedY
        }
        
        -- Normalize only if not zero
        local length = math.sqrt(normalizedOffset.x * normalizedOffset.x + normalizedOffset.y * normalizedOffset.y)
        if length > 0 then
            normalizedOffset.x = normalizedOffset.x / length
            normalizedOffset.y = normalizedOffset.y / length
            
            if normalizedOffset.x < -0.3 and normalizedOffset.y < -0.3 then
                pixelColor = highlightColor
            end
        end
        
        -- Draw the cell
        love.graphics.setColor(pixelColor)
        love.graphics.rectangle("fill", pixelX - cellSize/2, pixelY - cellSize/2, cellSize, cellSize)
    end
    
    -- Draw aiming line if aiming
    if ball.isAiming then
        -- Use the actual position for the aiming line
        local actualScreenX = ball.position.x * cellSize
        local actualScreenY = ball.position.y * cellSize
        
        -- Calculate the direction vectors
        local dx = ball.currentMousePosition.x - ball.clickPosition.x
        local dy = ball.currentMousePosition.y - ball.clickPosition.y
        local distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 0 then
            local dragDirX = dx / distance
            local dragDirY = dy / distance
            
            -- Calculate the power based on drag distance
            local power = math.min(distance / 100, 1.0)
            
            -- Draw the aiming line
            BallRendering.drawPixelatedDottedLine(
                ball,
                actualScreenX, 
                actualScreenY, 
                actualScreenX - dragDirX * 100 * power, 
                actualScreenY - dragDirY * 100 * power, 
                {1, 1, 0, 0.8},  -- Yellow color
                8, 12, 4
            )
            
            -- Draw the arrowhead at the end of the line
            BallRendering.drawPixelatedArrowhead(
                ball,
                actualScreenX - dragDirX * 100 * power, 
                actualScreenY - dragDirY * 100 * power, 
                -dragDirX, -dragDirY, 
                {1, 1, 0, 0.8},  -- Yellow color
                10
            )
        end
    end
end

-- Create impact effect based on material and force
function BallRendering.createImpactEffect(ball, cellX, cellY, cellType, impactForce)
    -- Check adjacent cells for sand to create crater
    local directions = {
        {x = 1, y = 0}, {x = -1, y = 0}, {x = 0, y = 1}, {x = 0, y = -1},
        {x = 1, y = 1}, {x = -1, y = 1}, {x = 1, y = -1}, {x = -1, y = -1}
    }
    
    for _, dir in ipairs(directions) do
        local checkX = cellX + dir.x
        local checkY = cellY + dir.y
        
        -- Check if the cell is within bounds
        if checkX >= 1 and checkX <= ball.cellWorld.width and
           checkY >= 1 and checkY <= ball.cellWorld.height then
            
            local checkCellType = ball.cellWorld:getCell(checkX, checkY)
            
            -- Only create craters in sand
            if checkCellType == ball.CellTypes.SAND then
                -- TODO: Add visual crater effect
                -- For now, just log it
                if ball.debug then
                    print("[IMPACT] Created crater in sand at: " .. checkX .. ", " .. checkY)
                end
                break  -- Only create one crater per impact
            end
        end
    end
end

return BallRendering
