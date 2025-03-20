// cell.glsl - GPU-accelerated cellular automaton simulation

// Input uniforms
uniform Image cellData;  // Cell data texture
uniform vec2 dimensions; // World dimensions (width, height)
uniform float time;      // Current time for random variations

// Constants for cell types
const float EMPTY = 0.0;
const float BOUNDARY = 1.0 / 255.0;

// Solid materials
const float STONE = 10.0 / 255.0;
const float DIRT = 11.0 / 255.0;
const float MUD = 12.0 / 255.0;
const float WOOD = 13.0 / 255.0;
const float METAL = 14.0 / 255.0;

// Particle solids
const float SAND = 20.0 / 255.0;
const float GRAVEL = 21.0 / 255.0;
const float ASH = 22.0 / 255.0;

// Liquids
const float WATER = 30.0 / 255.0;
const float OIL = 31.0 / 255.0;
const float LAVA = 32.0 / 255.0;

// Energy/Special
const float FIRE = 40.0 / 255.0;
const float STEAM = 41.0 / 255.0;
const float SMOKE = 42.0 / 255.0;

// Game objects
const float HOLE = 90.0 / 255.0;
const float FLAG = 91.0 / 255.0;

// Helper function to get cell type at a position
vec4 getCell(vec2 pos) {
    // Bounds checking
    if (pos.x < 0.0 || pos.x >= dimensions.x || pos.y < 0.0 || pos.y >= dimensions.y) {
        return vec4(0.2, 0.2, 0.2, BOUNDARY);
    }
    
    // Get cell data from texture
    return Texel(cellData, pos / dimensions);
}

// Random function based on position and time
float random(vec2 pos) {
    return fract(sin(dot(pos + time * 0.01, vec2(12.9898, 78.233))) * 43758.5453);
}

// Check if a cell type is a solid
bool isSolid(float cellType) {
    return cellType == STONE || cellType == DIRT || cellType == MUD || 
           cellType == WOOD || cellType == METAL || cellType == BOUNDARY;
}

// Check if a cell type is a liquid
bool isLiquid(float cellType) {
    return cellType == WATER || cellType == OIL || cellType == LAVA;
}

// Check if a cell type is a particle
bool isParticle(float cellType) {
    return cellType == SAND || cellType == GRAVEL || cellType == ASH || 
           cellType == MUD || cellType == STEAM || cellType == SMOKE;
}

// Get density of a cell type
float getDensity(float cellType) {
    if (cellType == STONE) return 5.0;
    if (cellType == DIRT) return 3.0;
    if (cellType == MUD) return 3.5;
    if (cellType == WOOD) return 2.0;
    if (cellType == METAL) return 7.0;
    if (cellType == SAND) return 4.0;
    if (cellType == GRAVEL) return 4.5;
    if (cellType == ASH) return 2.0;
    if (cellType == WATER) return 3.0;
    if (cellType == OIL) return 2.0;
    if (cellType == LAVA) return 5.0;
    if (cellType == FIRE) return 0.5;
    if (cellType == STEAM) return 0.2;
    if (cellType == SMOKE) return 0.1;
    if (cellType == BOUNDARY) return 999.0;
    return 0.0;
}

// Main fragment shader function
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    // Convert screen coordinates to cell coordinates
    vec2 cellPos = floor(screen_coords);
    
    // Get current cell data
    vec4 currentCell = getCell(cellPos);
    float cellType = currentCell.a * 255.0;
    
    // Debug: Just render the cell directly without simulation
    if (cellType != 0.0) {
        return vec4(currentCell.rgb, 1.0);
    }
    
    // If empty, check if something should fall into this cell
    if (cellType == EMPTY) {
        // Check cell above for falling particles or liquids (optimize by checking only if needed)
        vec4 aboveCell = getCell(cellPos - vec2(0, 1));
        float aboveCellType = aboveCell.a * 255.0;
        
        if (isParticle(aboveCellType / 255.0) || isLiquid(aboveCellType / 255.0)) {
            // Particle or liquid falls down
            return aboveCell;
        }
        
        // Only check diagonals for particles (sand-like behavior) if above cell isn't falling
        vec4 aboveLeftCell = vec4(0.0);
        vec4 aboveRightCell = vec4(0.0);
        float aboveLeftCellType = 0.0;
        float aboveRightCellType = 0.0;
        
        // Only fetch these cells if we need to check for particles
        aboveLeftCell = getCell(cellPos - vec2(1, 1));
        aboveLeftCellType = aboveLeftCell.a * 255.0;
        
        aboveRightCell = getCell(cellPos - vec2(-1, 1));
        aboveRightCellType = aboveRightCell.a * 255.0;
        
        // Randomly choose left or right for variety
        bool checkLeftFirst = random(cellPos) > 0.5;
        
        if (checkLeftFirst) {
            if (isParticle(aboveLeftCellType / 255.0)) {
                return aboveLeftCell;
            } else if (isParticle(aboveRightCellType / 255.0)) {
                return aboveRightCell;
            }
        } else {
            if (isParticle(aboveRightCellType / 255.0)) {
                return aboveRightCell;
            } else if (isParticle(aboveLeftCellType / 255.0)) {
                return aboveLeftCell;
            }
        }
        
        // Check sides for liquids (water-like spreading)
        vec4 leftCell = getCell(cellPos - vec2(1, 0));
        float leftCellType = leftCell.a * 255.0;
        
        vec4 rightCell = getCell(cellPos - vec2(-1, 0));
        float rightCellType = rightCell.a * 255.0;
        
        if (checkLeftFirst) {
            if (isLiquid(leftCellType / 255.0)) {
                return leftCell;
            } else if (isLiquid(rightCellType / 255.0)) {
                return rightCell;
            }
        } else {
            if (isLiquid(rightCellType / 255.0)) {
                return rightCell;
            } else if (isLiquid(leftCellType / 255.0)) {
                return leftCell;
            }
        }
        
        // Check for rising gases (smoke, steam)
        vec4 belowCell = getCell(cellPos - vec2(0, -1));
        float belowCellType = belowCell.a * 255.0;
        
        if (belowCellType == STEAM || belowCellType == SMOKE) {
            return belowCell;
        }
        
        // Nothing moved here, remain empty
        return vec4(0, 0, 0, EMPTY);
    }
    
    // Handle particles (sand, gravel, ash)
    else if (isParticle(cellType / 255.0)) {
        // Check if can fall down
        vec4 belowCell = getCell(cellPos + vec2(0, 1));
        float belowCellType = belowCell.a * 255.0;
        
        if (belowCellType == EMPTY) {
            // Fall down
            return vec4(0, 0, 0, EMPTY);
        }
        
        // Check if can fall diagonally
        bool checkLeftFirst = random(cellPos) > 0.5;
        
        if (checkLeftFirst) {
            vec4 belowLeftCell = getCell(cellPos + vec2(-1, 1));
            float belowLeftCellType = belowLeftCell.a * 255.0;
            
            if (belowLeftCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
            
            vec4 belowRightCell = getCell(cellPos + vec2(1, 1));
            float belowRightCellType = belowRightCell.a * 255.0;
            
            if (belowRightCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        } else {
            vec4 belowRightCell = getCell(cellPos + vec2(1, 1));
            float belowRightCellType = belowRightCell.a * 255.0;
            
            if (belowRightCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
            
            vec4 belowLeftCell = getCell(cellPos + vec2(-1, 1));
            float belowLeftCellType = belowLeftCell.a * 255.0;
            
            if (belowLeftCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        }
        
        // Check for liquid displacement (particles sink in liquids)
        if (isLiquid(belowCellType / 255.0) && getDensity(cellType / 255.0) > getDensity(belowCellType / 255.0)) {
            // Swap with liquid below (particle sinks)
            return belowCell;
        }
        
        // Stay in place
        return currentCell;
    }
    
    // Handle liquids (water, oil, lava)
    else if (isLiquid(cellType / 255.0)) {
        // Check if can fall down
        vec4 belowCell = getCell(cellPos + vec2(0, 1));
        float belowCellType = belowCell.a * 255.0;
        
        if (belowCellType == EMPTY) {
            // Fall down
            return vec4(0, 0, 0, EMPTY);
        }
        
        // Check if can displace less dense liquid
        if (isLiquid(belowCellType / 255.0) && getDensity(cellType / 255.0) > getDensity(belowCellType / 255.0)) {
            // Swap with liquid below (denser liquid sinks)
            return belowCell;
        }
        
        // Check if can flow to sides
        bool flowLeft = random(cellPos) > 0.5;
        int flowDistance = int(random(cellPos) * 4.0) + 1; // Flow 1-4 cells
        
        if (flowLeft) {
            // Try to flow left
            for (int i = 1; i <= flowDistance; i++) {
                vec2 checkPos = cellPos + vec2(-i, 0);
                vec4 sideCell = getCell(checkPos);
                float sideCellType = sideCell.a * 255.0;
                
                if (sideCellType == EMPTY) {
                    // Check if there's support underneath
                    vec4 belowSideCell = getCell(checkPos + vec2(0, 1));
                    float belowSideCellType = belowSideCell.a * 255.0;
                    
                    if (belowSideCellType != EMPTY) {
                        // Flow to this empty cell
                        return vec4(0, 0, 0, EMPTY);
                    }
                } else {
                    // Hit an obstacle, stop checking
                    break;
                }
            }
        }
        
        // Try to flow right
        for (int i = 1; i <= flowDistance; i++) {
            vec2 checkPos = cellPos + vec2(i, 0);
            vec4 sideCell = getCell(checkPos);
            float sideCellType = sideCell.a * 255.0;
            
            if (sideCellType == EMPTY) {
                // Check if there's support underneath
                vec4 belowSideCell = getCell(checkPos + vec2(0, 1));
                float belowSideCellType = belowSideCell.a * 255.0;
                
                if (belowSideCellType != EMPTY) {
                    // Flow to this empty cell
                    return vec4(0, 0, 0, EMPTY);
                }
            } else {
                // Hit an obstacle, stop checking
                break;
            }
        }
        
        // If we couldn't flow left or right, try the other direction
        if (!flowLeft) {
            // Try to flow left
            for (int i = 1; i <= flowDistance; i++) {
                vec2 checkPos = cellPos + vec2(-i, 0);
                vec4 sideCell = getCell(checkPos);
                float sideCellType = sideCell.a * 255.0;
                
                if (sideCellType == EMPTY) {
                    // Check if there's support underneath
                    vec4 belowSideCell = getCell(checkPos + vec2(0, 1));
                    float belowSideCellType = belowSideCell.a * 255.0;
                    
                    if (belowSideCellType != EMPTY) {
                        // Flow to this empty cell
                        return vec4(0, 0, 0, EMPTY);
                    }
                } else {
                    // Hit an obstacle, stop checking
                    break;
                }
            }
        }
        
        // Special case for lava: chance to set nearby flammable materials on fire
        if (cellType == LAVA * 255.0) {
            float fireChance = 0.01; // 1% chance per frame
            
            if (random(cellPos + time) < fireChance) {
                // Check adjacent cells for flammable materials
                vec2 directions[4] = vec2[4](
                    vec2(-1, 0), vec2(1, 0), vec2(0, -1), vec2(0, 1)
                );
                
                for (int i = 0; i < 4; i++) {
                    vec2 checkPos = cellPos + directions[i];
                    vec4 adjacentCell = getCell(checkPos);
                    float adjacentCellType = adjacentCell.a * 255.0;
                    
                    // Wood and oil are flammable
                    if (adjacentCellType == WOOD || adjacentCellType == OIL) {
                        // Set the cell on fire in the next frame
                        // (This is handled by the CPU-side code)
                    }
                }
            }
        }
        
        // Stay in place
        return currentCell;
    }
    
    // Handle fire
    else if (cellType == FIRE * 255.0) {
        // Fire has a chance to burn out
        float burnOutChance = 0.05; // 5% chance per frame
        
        if (random(cellPos + time) < burnOutChance) {
            // Convert to smoke or disappear
            if (random(cellPos) < 0.7) {
                return vec4(0.3, 0.3, 0.3, SMOKE);
            } else {
                return vec4(0, 0, 0, EMPTY);
            }
        }
        
        // Fire rises
        vec4 aboveCell = getCell(cellPos - vec2(0, 1));
        float aboveCellType = aboveCell.a * 255.0;
        
        if (aboveCellType == EMPTY) {
            // Rise up and leave smoke behind
            if (random(cellPos) < 0.3) {
                return vec4(0.3, 0.3, 0.3, SMOKE);
            } else {
                return vec4(0, 0, 0, EMPTY);
            }
        }
        
        // Animate fire by slightly changing its color
        float r = currentCell.r + (random(cellPos + time) - 0.5) * 0.1;
        float g = currentCell.g + (random(cellPos + time + 1.0) - 0.5) * 0.1;
        
        return vec4(
            clamp(r, 0.8, 1.0),
            clamp(g, 0.3, 0.7),
            0.0,
            FIRE
        );
    }
    
    // Handle steam and smoke
    else if (cellType == STEAM * 255.0 || cellType == SMOKE * 255.0) {
        // Gases rise and dissipate
        float dissipateChance = 0.02; // 2% chance per frame
        
        if (random(cellPos + time) < dissipateChance) {
            return vec4(0, 0, 0, EMPTY);
        }
        
        // Check if can rise
        vec4 aboveCell = getCell(cellPos - vec2(0, 1));
        float aboveCellType = aboveCell.a * 255.0;
        
        if (aboveCellType == EMPTY) {
            // Rise up
            return vec4(0, 0, 0, EMPTY);
        }
        
        // Check if can rise diagonally
        bool checkLeftFirst = random(cellPos) > 0.5;
        
        if (checkLeftFirst) {
            vec4 aboveLeftCell = getCell(cellPos - vec2(-1, 1));
            float aboveLeftCellType = aboveLeftCell.a * 255.0;
            
            if (aboveLeftCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
            
            vec4 aboveRightCell = getCell(cellPos - vec2(1, 1));
            float aboveRightCellType = aboveRightCell.a * 255.0;
            
            if (aboveRightCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        } else {
            vec4 aboveRightCell = getCell(cellPos - vec2(1, 1));
            float aboveRightCellType = aboveRightCell.a * 255.0;
            
            if (aboveRightCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
            
            vec4 aboveLeftCell = getCell(cellPos - vec2(-1, 1));
            float aboveLeftCellType = aboveLeftCell.a * 255.0;
            
            if (aboveLeftCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        }
        
        // Spread horizontally
        bool spreadLeft = random(cellPos) > 0.5;
        
        if (spreadLeft) {
            vec4 leftCell = getCell(cellPos - vec2(1, 0));
            float leftCellType = leftCell.a * 255.0;
            
            if (leftCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        } else {
            vec4 rightCell = getCell(cellPos - vec2(-1, 0));
            float rightCellType = rightCell.a * 255.0;
            
            if (rightCellType == EMPTY) {
                return vec4(0, 0, 0, EMPTY);
            }
        }
        
        // Fade the gas over time
        float alpha = currentCell.a - 0.01;
        if (alpha < 0.2) {
            return vec4(0, 0, 0, EMPTY);
        }
        
        // Stay in place with slight color/alpha changes for animation
        return vec4(
            currentCell.r,
            currentCell.g,
            currentCell.b,
            cellType / 255.0
        );
    }
    
    // All other cell types (solids, game objects) stay in place
    return currentCell;
}
