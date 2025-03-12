require("svg")

local border = 12
local ligation_size = 26
local atom_radius = 7
local distance_between_ligations = 20

local waves = {
    { 0 },
    { distance_between_ligations/2, - distance_between_ligations/2 },
    { distance_between_ligations, 0, -distance_between_ligations }
}

function handle_err(err)
    print(err)
    os.exit(1)
end

local filename = arg[1]
file = io.open(filename, "r")
local content = file:read("*a")
file:close()

local sections = {}
for s in content:gmatch("[^$]+") do
    table.insert(sections, s)
end

local section_tags = sections[1]
local section_atms = sections[2]
local section_ligs = sections[3]

local tags = {}
for line in section_tags:gmatch("[^%s]+") do
    table.insert(tags, line)
end

local eletrons_type = {
    ["-"] = 1,
    ["="] = 2,
    ["%"] = 3
}

function handle_pattern(pattern)
    local pattern_file = io.open("./pattern/"..pattern..".pre.z1", "r")
    if pattern_file == nil then
        handle_err("Pattern '"..pattern.."' not found")
    end

    local pattern_content = pattern_file:read("*a")
    pattern_file:close()

    return handle_section_ligations(pattern_content)
end

function handle_ligation(params)
    local ligations = {}

    local angle = tonumber(params[1])

    if angle == nil then
        local pattern = params[1]

        local pattern_ligations = handle_pattern(pattern)
        for _, pattern_ligation in ipairs(pattern_ligations) do
            table.insert(ligations, pattern_ligation)
        end
    else
        local eletrons = eletrons_type[params[2]]
        local eletrons_behaviour = params[3]

        if eletrons == nil then
            eletrons = 1
            eletrons_behaviour = params[2]
        end

        local ligation = {
            angle = angle,
            eletrons = eletrons,
            eletrons_behaviour = eletrons_behaviour
        }

        table.insert(ligations, ligation)
    end

    return ligations
end

function handle_section_ligations(section)
    local ligations = {}
    for line in section:gmatch("[^\n]+") do

        local params = {}
        for param in line:gmatch("[^%s]+") do
            table.insert(params, param)
        end
        
        local ligs = handle_ligation(params)
        for _, lig in ipairs(ligs) do
            table.insert(ligations, lig)        
        end

    end
    return ligations
end

local ligations = handle_section_ligations(section_ligs)

local atoms = {}
for line in section_atms:gmatch("[^\n]+") do
    local params = {}
    for param in line:gmatch("[^%s]+") do
        table.insert(params, param)
    end

    local symbol = params[1]
    if symbol:match("[A-Z][a-z]?") == nil then
        handle_err("symbol '" .. params[1] .. "' invalid")
    end

    local start_ligation_index = 1
    local charge = 0
    if params[2]:match("[-|+][0-9]") ~= nil then
        start_ligation_index = 2
        charge = tonumber(params[2])
        if charge == nil then
            handle_err("charge '" .. charge .. "' invalid")
        end
    end

    local ligs = {}
    for k, v in ipairs(params) do
        if k > start_ligation_index then
            local lig = tonumber(v)
            if lig == nil then
                handle_err("ligation '" .. lig .. "' invalid")
            end

            if ligations[lig]["atoms"] == nil then
                ligations[lig]["atoms"] = {#atoms + 1}
            else
                table.insert(ligations[lig]["atoms"], #atoms + 1)
            end

            table.insert(ligs, lig)
        end
    end

    atom = {
        symbol = symbol,
        charge = charge,
        ligations = ligs
    }
    table.insert(atoms, atom)
end

local already = {}

local min_x = 0
local min_y = 0
local max_x = 0
local max_y = 0

function calc_atoms_position(idx, dad_atom, ligation)
    for k, v in ipairs(already) do
        if idx == v then
            return
        end
    end

    local x = 0
    local y = 0

    if dad_atom ~= nil then
        local angle = ligation["angle"]
        local angle_rad = math.pi * angle / 180
        x = dad_atom["x"] + math.cos(angle_rad) * ligation_size
        y = dad_atom["y"] + math.sin(angle_rad) * ligation_size
    end

    if x > max_x then max_x = x end
    if y > max_y then max_y = y end
    if x < min_x then min_x = x end
    if y < min_y then min_y = y end

    atoms[idx]["x"] = x
    atoms[idx]["y"] = y
    table.insert(already, idx)

    for _, lig in ipairs(ligations) do
        if lig["atoms"][1] == idx then
            calc_atoms_position(lig["atoms"][2], atoms[idx], lig)
        end
    end
end

calc_atoms_position(1)

local cwidth = max_x + -min_x
local cheight = max_y + -min_y

local width = border * 2 + cwidth
local height = border * 2 + cheight

local center_x = border + math.abs(min_x)
local center_y = border + math.abs(min_y)

svg = Svg:new{}

for _, atom in ipairs(atoms) do
    local symbol = atom["symbol"]
    local x = center_x + atom["x"]
    local y = center_y + atom["y"]

    svg:text(atom["symbol"], x, y)

    local charge = atom["charge"]

    if charge ~= 0 then
        if charge == 1 then charge = "+" end
        if charge == -1 then charge = "-" end
        svg:subtext(charge, x + atom_radius, y - atom_radius)
    end
end

for _, ligation in ipairs(ligations) do
    local from_atom = atoms[ligation["atoms"][1]]
    local to_atom = atoms[ligation["atoms"][2]]

    local ax = center_x + from_atom["x"]
    local ay = center_y + from_atom["y"]
    local bx = center_x + to_atom["x"]
    local by = center_y + to_atom["y"]

    local angles = waves[ ligation["eletrons"] ]

    local a_angle = math.atan((by - ay), (bx - ax))
    local b_angle = math.pi + a_angle

    if ligation["eletrons_behaviour"] ~= "i" then
        for _, angle in ipairs(angles) do
            local nax = ax + math.cos(a_angle + (math.pi * angle / 180)) * atom_radius
            local nay = ay + math.sin(a_angle + (math.pi * angle / 180)) * atom_radius

            local nbx = bx + math.cos(b_angle - (math.pi * angle / 180)) * atom_radius
            local nby = by + math.sin(b_angle - (math.pi * angle / 180)) * atom_radius

            svg:line(nax, nay, nbx, nby)
        end
    end
end

svg_content = svg:build(width, height)

local filename_without_ext = filename:gsub(".z1", "")

final_file = io.open(filename_without_ext .. ".svg", "w+")
final_file:write(svg_content)
final_file:close()