temp_output = nil
lovr.keyboard = require 'lovr-keyboard'
lovr.mouse = require 'lovr-mouse'

lovr.graphics.setDefaultFilter("nearest", 0)

require 'chunk_vertice_generator'
require 'input'
require 'camera'
require 'game_math'
require 'api_functions'

--this holds the data for the gpu to render
gpu_chunk_pool = {}

--this holds the chunk data for the game to work with
chunk_map = {}

local seed = lovr.math.random()

local x_limit = 16
local z_limit = 16*128
local y_limit = 16
local function memory_position(i)
	i = i - 1
	local z = math.floor(i / z_limit)
	i = i % z_limit
	local y = math.floor(i / y_limit)
    i = i  % y_limit
	local x = math.floor(i)
	return x,y,z
end

--local p_count = 0
--local position_hold = {}
function gen_chunk_data(x,z)
    local c_index = hash_chunk_position(x,z)
    local cx,cz = x,z
    chunk_map[c_index] = {}

    local x,y,z = 0,0,0

    noise = math.ceil(lovr.math.noise((x+(cx*16))/100, ((cz*16)+z)/100,seed)*100)

    for i = 1,16*16*128 do
        
        local index = hash_position(x,y,z)

        if y < noise then
            chunk_map[c_index][index] = lovr.math.random(1,2)
        else
            --if y == noise + 1 then
            --    p_count = p_count + 1
            --    position_hold[p_count] = {x=x+(cx*16),y=y,z=z+(cz*16)}
            --end
            chunk_map[c_index][index] = 0
        end
        
        --up
        y = y + 1
        if y > 127 then
            y = 0
            --forwards
            x = x + 1
            
            noise = math.ceil(lovr.math.noise((x+(cx*16))/100, ((cz*16)+z)/100,seed)*100)
            if x > 15 then
                x = 0
                --right
                noise = math.ceil(lovr.math.noise((x+(cx*16))/100, ((cz*16)+z)/100,seed)*100)
                z = z + 1
            end
        end
    end
end


function chunk_update_vert(x,z)
    local c_index = hash_chunk_position(x,z)
    if gpu_chunk_pool[c_index] then
        gpu_chunk_pool[c_index] = generate_chunk_vertices(x,z)
        gpu_chunk_pool[c_index]:setMaterial(dirt)
    end
end

local dirs = {
    {x=-1,z= 0},
    {x= 1,z= 0},
    {x= 0,z=-1},
    {x= 0,z= 1},
}

function gen_chunk(x,z)
    
    local c_index = hash_chunk_position(x,z)

    gen_chunk_data(x,z)

    gpu_chunk_pool[c_index] = generate_chunk_vertices(x,z)
    if gpu_chunk_pool[c_index] then
        gpu_chunk_pool[c_index]:setMaterial(dirt)
    end

    for _,dir in ipairs(dirs) do
        chunk_update_vert(x+dir.x,z+dir.z)
    end
end

local test_view_distance = 5
function lovr.load()
    lovr.mouse.setRelativeMode(true)
    lovr.graphics.setCullingEnabled(true)
    lovr.graphics.setBlendMode(nil,nil)
    --lovr.graphics.setWireframe(true)
    
    camera = {
        transform = lovr.math.vec3(),
        position = lovr.math.vec3(0,130,0),
        movespeed = 10,
        pitch = 0,
        yaw = math.pi
    }    

    dirttexture = lovr.graphics.newTexture("textures/dirt.png")

    dirt = lovr.graphics.newMaterial()
    dirt:setTexture(dirttexture)


    s_width, s_height = lovr.graphics.getDimensions()
    fov = 72
    fov_origin = fov
end

local counter = 0
local up = true
local time_delay = 0
local curr_chunk_index = {x=-test_view_distance,z=-test_view_distance}
function lovr.update(dt)
    --dig()
    camera_look(dt)
    if up then
        counter = counter + dt/5
    else
        counter = counter - dt/5
    end
    if counter >= 0.4 then
        up = false
    elseif counter <= 0 then
        up = true
    end
    
    
    if time_delay then
       -- time_delay = time_delay + dt
        --if time_delay > 0.02 then
            --time_delay = 0
            gen_chunk(curr_chunk_index.x,curr_chunk_index.z)

            curr_chunk_index.x = curr_chunk_index.x + 1
            if curr_chunk_index.x > test_view_distance then
                curr_chunk_index.x = -test_view_distance
                curr_chunk_index.z = curr_chunk_index.z + 1
                if curr_chunk_index.z > test_view_distance then
                    time_delay = nil
                end
            end
        --end
    end
end

timer = 0
function lovr.draw()
    --this is where the ui should be drawn
    lovr.graphics.push()
        lovr.graphics.print("FPS:"..lovr.timer.getFPS(), -0.1, 0.072, -0.1, 0.01, 0, 0, 1, 0,0, "left","top")
        lovr.graphics.print("+", 0, 0, -0.1, 0.01, 0, 0, 1, 0)
    lovr.graphics.pop()

    local x,y,z = camera.position:unpack()

    lovr.graphics.rotate(-camera.pitch, 1, 0, 0)
    lovr.graphics.rotate(-camera.yaw, 0, 1, 0)

    lovr.graphics.transform(-x,-y,-z)

    lovr.graphics.setProjection(lovr.math.mat4():perspective(0.01, 1000, 90/fov,s_width/s_height))

    for _,mesh in pairs(gpu_chunk_pool) do
        lovr.graphics.push()
        mesh:draw()
        lovr.graphics.pop()
    end

    lovr.graphics.push()

    
    --local dx,dy,dz = get_camera_dir()
    --dx = dx * 4
    --dy = dy * 4
    --dz = dz * 4
    --local pos = {x=x+dx,y=y+dy,z=z+dz}

    --local fps = lovr.timer.getFPS()

    --lovr.graphics.print(tostring(temp_output), pos.x, pos.y, pos.z,1,camera.yaw,0,1,0)

    --for _,data in ipairs(position_hold) do
        --lovr.graphics.print(tostring(data.x.." "..data.y.." "..data.y), data.x, data.y, data.z,0.5,camera.yaw,0,1,0)
    --end

    if selected_block then
        lovr.graphics.cube('line',  selected_block.x+0.5, selected_block.y+0.5, selected_block.z+0.5, 1)
    end
    --lovr.graphics.cube('line',  pos.x, pos.y, pos.z, .5, lovr.timer.getTime())

    lovr.graphics.pop()
end