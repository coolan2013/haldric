extends TileMap

var WIDTH
var HEIGHT

var offset = Vector2(36, 36)

var villages = []

var game
# enum DIRECTION {SE, NE, N, NW, SW, S}
# that's the order of the neighbors in the lookup table
#do not change order they appear in
var neighbor_table = [
	# EVEN col, ALL rows
    [
		Vector2(+1,  0), # SE
		Vector2(+1, -1), # NE
		Vector2(0, -1), # N
     	Vector2(-1, -1), # NW
		Vector2(-1,  0), # SW
		Vector2(0, +1) # S
	],
	# ODD col, ALL rows
    [
		Vector2(+1, +1), # SE
		Vector2(+1,  0), # NE
		Vector2(0, -1), # N
     	Vector2(-1,  0), # NW
		Vector2(-1, +1), # SW
		Vector2( 0, +1) # S
	]]

var tiles = {}
var grid = AStar.new()

var overlay = TileMap.new()
var cover = TileMap.new()

func _ready():
	WIDTH = get_used_rect().end.x
	HEIGHT = get_used_rect().end.y
	
	_generate_tiles()
	_generate_points()
	_generate_point_connections()

# P U B L I C   F U N C T I O N S


func find_path_by_position(_start_position, _end_position):
	var start_cell = world_to_map(_start_position)
	var end_cell = world_to_map(_end_position)
	return find_path_by_cell(start_cell, end_cell)

func find_path_by_cell(start_cell, end_cell):
	var path2D = []
	if check_boundaries(start_cell) and check_boundaries(end_cell):
		var path3D = grid.get_point_path(flatten_v(start_cell), flatten_v(end_cell))
		for point in path3D:
			path2D.append(Vector2(point.x, point.y))
	return path2D

func update_weight(unit):
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell = Vector2(x,y)
			var id = flatten_v(cell)
			var cost =  unit.get_movement_cost(tiles[id].terrain_type)
			var other_unit = game.get_unit_at_cell(cell)
			if other_unit:
				if not other_unit.side == unit.side:
					cost = 99
			else:	
				for other_unit in get_adjacent_units(cell):
					if not other_unit.side == unit.side:
						cost += 100
						break
			grid.set_point_weight_scale(id, cost)

func get_reachable_cells_u(unit):
	update_weight(unit)
	var reachable = []
	if unit.current_moves == 0:
		for other_unit in get_adjacent_units(world_to_map(unit.position)):
			if not other_unit.side == unit.side:
				reachable.append(world_to_map(other_unit.position))
		return reachable
	reachable = get_reachable_cells(world_to_map(unit.position), unit.current_moves)
	return reachable

func get_reachable_cells(start_cell, _range):
	var start_cube = v2_to_v3(start_cell)
	var reachable = []
	var cell_range = _get_cells_in_range(start_cell,_range)
	for cell in cell_range:
		var cube = v2_to_v3(cell)
		var diff_x = abs(start_cube.x - cube.x)
		var diff_y = abs(start_cube.y - cube.y)
		var diff_z = abs(start_cube.z - cube.z)
		if max(max(diff_x, diff_y), diff_z) > _range or tiles[flatten_v(cell)].is_blocked:
			continue
		var path = grid.get_id_path(flatten_v(start_cell), flatten_v(cell))
		path.remove(0)
		var weight = 0
		var in_zoc = false
		for i in range(path.size()):
			var value = grid.get_point_weight_scale(path[i])
			if value > 100:
				if not i == path.size() - 1:
					weight = _range + 1
					break 
				else:
					value -= 100
					in_zoc = true
			weight += value
		if weight <= _range:
			reachable.append(cell)
			if in_zoc:
				for other_unit in get_adjacent_units(cell):
					reachable.append(world_to_map(other_unit.position))
	return reachable

func get_tile_at_cell(cell):
	return tiles[flatten_v(cell)]

func get_tile_at_position(position):
	return tiles[flatten_v(world_to_map(position))]

func are_neighbors(cell1, cell2):
	var cell1_neighbors = _get_neighbors(cell1)

	for n in cell1_neighbors:
		if cell2 == n:
			return true
	return false

func unblock_cell(cell):
	tiles[flatten_v(cell)].is_blocked = false

func block_cell(cell):
	tiles[flatten_v(cell)].is_blocked = true

func connect_cell(cell):
	_connect_with_neighbors(cell)

func disconnect_cell(cell):
	_disconnect_with_neighbors(cell)

func map_to_world_centered(_cell):
	var pos = map_to_world(_cell)
	return pos + offset

func world_to_world_centered(_position):
	_position = map_to_world_centered(world_to_map(_position))
	return _position

func flatten_v(_cell):
	return int(_cell.y) * WIDTH + int(_cell.x)

func flatten(_x, _y):
	return int(_y) * WIDTH + int(_x)

func check_boundaries(cell):
	return (cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH  and cell.y < HEIGHT)

func get_map_string():
	var string = ""
	
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var id = flatten(x, y)
			if get_cell(x, y) == TileMap.INVALID_CELL:
				set_cell(x, y, tile_set.find_tile_by_name("Xv"))
				overlay.set_cell(x, y, TileMap.INVALID_CELL)
			
			var code = tile_set.tile_get_name(get_cell(x, y))
			var overlay_code = ""

			var overlay_cell = overlay.get_cell(x, y)

			if overlay_cell != TileMap.INVALID_CELL:
				overlay_code = tile_set.tile_get_name(overlay_cell)
			if x < WIDTH - 1 and y < HEIGHT - 1:
				string += code + overlay_code + ","
			else:
				string += code + overlay_code
		string += "\n"
	return string


func _generate_tiles():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var id = flatten(x, y)
			
			if get_cell(x, y) == TileMap.INVALID_CELL:
				set_cell(x, y, tile_set.find_tile_by_name("Xv"))
				overlay.set_cell(x, y, TileMap.INVALID_CELL)
			
			var code = tile_set.tile_get_name(get_cell(x, y))
			var overlay_code = ""

			var overlay_cell = overlay.get_cell(x, y)

			if overlay_cell != TileMap.INVALID_CELL:
				overlay_code = tile_set.tile_get_name(overlay_cell)

			var type
			var overlay_type
			
			var is_keep = false
      
			if not overlay_code.empty():
				match overlay_code[1]:
					"V":
						overlay_type = "village"
						villages.append(Vector2(x, y))
					"F":
						overlay_type = "forest"
					_:
						overlay_type = "unknown"
			else: 
				overlay_type = ""

			match code[0]:					
				"X":
					type = "impassable"
				"G":
					type = "flat"
				"H":
					type = "hills"
				"M":
					type = "mountains"
				"K":
					type = "castle"
					is_keep = true
				"C":
					type = "castle"
				_:
					type = "unknown"

			tiles[id] = {
				terrain_type = [type,overlay_type],
                terrain_code = code + overlay_code,
				position = map_to_world_centered(Vector2(x, y)),
                unit = null,
				stack_limit = 1,
				is_village = overlay_type == "village",
				is_keep = is_keep,
				is_blocked = false,
			}

func _generate_points():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell = Vector2(x, y)
			var id = flatten(x, y)
			var point = grid.add_point(id, Vector3(x, y, 0))

func _generate_point_connections():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var cell = Vector2(x, y)
			var id = flatten(x, y)
			var point = grid.get_point_position(id)
			_connect_with_neighbors(cell)

func _connect_with_neighbors(_cell):
	var id = flatten_v(_cell)
	var neighbors = _get_neighbors(_cell)
	for n in neighbors:
		var n_id = flatten(n.x, n.y)
		if check_boundaries(n) and !grid.are_points_connected(id, n_id):
			if !tiles[id].is_blocked and !tiles[n_id].is_blocked:
				grid.connect_points(id, n_id)

func _disconnect_with_neighbors(_cell):
	var id = flatten_v(_cell)
	var neighbors = _get_neighbors(_cell)
	for n in neighbors:
		var n_id = flatten(n.x, n.y)
		if check_boundaries(n) and !grid.are_points_connected(id, n_id):
			grid.disconnect_points(id, n_id)

func _get_neighbor(cell, direction):
	var parity = cell.x & 1
	var dir = neighbor_table[parity][direction]
	return Vector2(cell.x + dir[0], cell.y + dir[1])

func _get_neighbors(cell):
	var neighbors = []
	var parity = int(cell.x) & 1
	for n in neighbor_table[parity]:
		neighbors.append(Vector2(cell.x + n.x, cell.y+n.y))
	return neighbors

func _get_cells_in_range(cell, _range):
	var cells = [cell]
	for n in range(1,_range+1):
		var current_cell = Vector2(cell.x, cell.y - n)
		for j in range(6):
			for i in range(n):
				var parity = int(current_cell.x) & 1
				var temp = neighbor_table[parity][(j+4)%6]
				current_cell += temp
				if check_boundaries(current_cell):
					cells.append(current_cell)
	return cells

func get_adjacent_units(cell):
	var neighbors = []
	var parity = int(cell.x) & 1
	for n in neighbor_table[parity]:
		var new_cell = Vector2(cell.x + n.x, cell.y+n.y)
		var other_unit = game.get_unit_at_cell(new_cell)
		if other_unit:
			neighbors.append(other_unit)
	return neighbors

func v3_to_v2(cube):
    var col = cube.x
    var row = cube.z + (cube.x - (int(cube.x) & 1)) / 2
    return Vector2(col, row)

func v2_to_v3(hex):
    var x = hex.x
    var z = hex.y - (hex.x - (int(hex.x) & 1)) / 2
    var y = -x-z
    return Vector3(x, y, z)
