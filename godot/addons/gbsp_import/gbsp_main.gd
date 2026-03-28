@tool
extends EditorPlugin
class_name BSPImporter

static var bsp_data
static var scene_root
const IMPORT_SCALE = 0.025
static var load_entities
static var split_main_mesh

class BSPEntity:
	var kv_entries
	var entry_count
	var brush
	func _init():
		kv_entries = Array()
		entry_count = 0
		brush = false
	func GetString(key) -> String:
		for i in range(entry_count):
			if kv_entries[i] == key:
				return kv_entries[i + 1]
		return ""
	func GetInt(key, d: int = 1) -> int:
		for i in range(entry_count):
			if kv_entries[i] == key:
				return kv_entries[i + 1].to_int()
		return d
	func GetFloat(key, d: float = 1.0) -> float:
		for i in range(entry_count):
			if kv_entries[i] == key:
				return kv_entries[i + 1].to_float()
		return d
	func GetVector3(key) -> Vector3:
		for i in range(entry_count):
			if kv_entries[i] == key:
				var s1 = kv_entries[i + 1].split(" ")
				return Vector3(s1[0].to_float(), s1[1].to_float(), s1[2].to_float())
		return Vector3(0, 0, 0)
	func GetColor(key) -> Color:
		for i in range(entry_count):
			if kv_entries[i] == key:
				var s1 = kv_entries[i + 1].split(" ")
				var c = Color()
				c.r8 = s1[0].to_float()
				c.g8 = s1[1].to_float()
				c.b8 = s1[2].to_float()
				c.a8 = 255
				return c
		return Color(0.0, 0.0, 0.0, 1.0)

class BSPVertex:
	var position
	var normal
	var color
	var tex_coord
	var lm_coord
	
class TexInfo:
	var name
	var flags
	var contents

class BSPFace:
	var tex_index;
	var effect;
	var type; # 1=polygon, 2=patch, 3=mesh, 4=billboard
	var vertex;
	var n_vtx;
	var mesh_vertex;
	var n_mesh_vtx;
	var lm_index;
	var lm_start_x;
	var lm_start_y;
	var lm_size_x;
	var lm_size_y;
	var lm_origin;
	var lm_vector1;
	var lm_vector2;
	var normal;
	var size_x;
	var size_y;
		
class BSPModel:
	var mins;
	var maxs;
	var face;
	var n_faces;
	var brush;
	var n_brushes;
	
class BrushModelEntity:
	var modelIndex;
	var entityIndex;
	var name;
	var parent;
	var collision;
	var lm_scale;
	var smoothing;
	var isStatic;
	var isMaster;
	var isInstance;
	var origin;
		
class MeshVertex:
	var position;
	var normal;
	var uv;
	var baseIndex;
	
class SubMesh:
	var texId;
	var triangles;
	
class BSPNode:
	var planeIndex;
	var child1; # negative numbers are leafs
	var child2;
	var mins; # 3
	var maxs; # 3
	func GetArea() -> float:
		var area = 0.0
		if child1 < 0:
			area += BSPImporter.bsp_data.bsp_leaves[-(child1 + 1)].GetArea()
		else:
			area += BSPImporter.bsp_data.bsp_nodes[child1].GetArea()
		if child2 < 0:
			area += BSPImporter.bsp_data.bsp_leaves[-(child2 + 1)].GetArea()
		else:
			area += BSPImporter.bsp_data.bsp_nodes[child2].GetArea()
		return area

class BSPLeaf:
	var visCluster;
	var portalArea;
	var mins; # 3
	var maxs; # 3
	var leafFace;
	var n_leafFaces;
	var leafBrush;
	var n_leafBrushes;
	var area
	func GetArea() -> float:
		if area:
			return area
		area = 0.0
		if n_leafFaces < 1:
			return 0.0 # some leaves have no faces
		for i in range(n_leafFaces):
			var f1 = BSPImporter.bsp_data.bsp_faces[BSPImporter.bsp_data.bsp_leaffaces[leafFace + i]]
			var i2 = 0
			while i2 < f1.n_mesh_vtx:
				var v1 = BSPImporter.bsp_data.bsp_vertices[BSPImporter.bsp_data.bsp_mesh_vertices[i2 + f1.mesh_vertex] + f1.vertex].position
				var v2 = BSPImporter.bsp_data.bsp_vertices[BSPImporter.bsp_data.bsp_mesh_vertices[i2 + 1 + f1.mesh_vertex] + f1.vertex].position
				var v3 = BSPImporter.bsp_data.bsp_vertices[BSPImporter.bsp_data.bsp_mesh_vertices[i2 + 2 + f1.mesh_vertex] + f1.vertex].position
				i2 += 3
				area += BSPImporter.GetTriangleArea(v1, v2, v3)
		return area
	
class InfoOrigin:
	var position;
	var modelName;
	
class ObjectStringPair:
	var object1;
	var string1;
	func _init(obj, str1):
		object1 = obj;
		string1 = str1;

class BSPMapData:
	var tex_infos
	var bsp_planes
	var bsp_nodes
	var bsp_leaves
	var bsp_leaffaces
	var bsp_models
	var bsp_vertices
	var bsp_faces
	var bsp_mesh_vertices
	var bsp_entities
	var info_origins
	var brush_model_entities
	
	func _init():
		tex_infos = Array()
		bsp_planes = Array()
		bsp_nodes = Array()
		bsp_leaves = Array()
		bsp_leaffaces = Array()
		bsp_models = Array()
		bsp_vertices = Array()
		bsp_faces = Array()
		bsp_mesh_vertices = Array()
		bsp_entities = Array()
		info_origins = Array()
		brush_model_entities = Array()

	func LoadMapFile(file_path):
		if file_path.ends_with(".bsp"):
			LoadBSP(file_path)
		elif file_path.ends_with(".map"):
			LoadMap(file_path)
		else:
			printerr("\"" + file_path + "\" Is not a .bsp or .map file.")

	func LoadMap(file_path):
		var q3map2_path = file_path.get_base_dir().get_base_dir().get_base_dir() + "/Tools/q3map2.exe"
		var bsp_file_path = file_path.get_basename() + ".bsp"
		if !FileAccess.file_exists(q3map2_path):
			printerr("q3map2.exe not found in " + q3map2_path)
			return
		var args = PackedStringArray()
		args.push_back(file_path)
		var start = Time.get_ticks_msec()
		OS.create_process(q3map2_path, args, false)
		var editor_interface = Engine.get_singleton("EditorInterface")
		var editor_tree = editor_interface.get_editor_main_screen().get_tree()
		var v1 = 0.0
		while !FileAccess.file_exists(bsp_file_path) and v1 < 100.0:
			v1 += 10.0
			await editor_tree.create_timer(1.0).timeout
		var end = Time.get_ticks_msec()
		#print (end - start)
		DirAccess.remove_absolute(file_path.get_basename() + ".lin")
		DirAccess.remove_absolute(file_path.get_basename() + ".srf")
		LoadBSP(bsp_file_path)
		
	func LoadBSP(bsp_path):
		var file = FileAccess.open(bsp_path, FileAccess.READ)
		var signature = String.chr(file.get_8()) + String.chr(file.get_8()) + String.chr(file.get_8()) + String.chr(file.get_8())
		if signature != "IBSP":
			file.close()
			printerr("\"" + bsp_path + "\" Is not a valid bsp file.")
			return
		print("Loading: \"" + bsp_path + "\"")
		var bsp_version = file.get_32()
		if bsp_version == 46:
			print("BSP Version: " + str(bsp_version))
		else:
			printerr("BSP Version: " + str(bsp_version))
		var entities_offset = file.get_32()
		var entities_length = file.get_32()
		var textures_offset = file.get_32()
		var textures_length = file.get_32()
		var planes_offset = file.get_32()
		var planes_length = file.get_32()
		var nodes_offset = file.get_32()
		var nodes_length = file.get_32()
		var leaves_offset = file.get_32()
		var leaves_length = file.get_32()
		var leaffaces_offset = file.get_32()
		var leaffaces_length = file.get_32()
		file.seek(64)
		var models_offset = file.get_32()
		var models_length = file.get_32()
		file.seek(88)
		var vertices_offset = file.get_32()
		var vertices_length = file.get_32()
		var m_vertices_offset = file.get_32()
		var m_vertices_length = file.get_32()
		file.seek(112)
		var faces_offset = file.get_32()
		var faces_length = file.get_32()
		
		var vertex_count = vertices_length / 44
		var m_vertex_count = m_vertices_length / 4
		var face_count = faces_length / 104
		var textures_count = textures_length / 72
		var model_count = models_length / 40
		var planes_count = planes_length / 16
		var nodes_count = nodes_length / 36
		var leaves_count = leaves_length / 48
		var leaffaces_count = leaffaces_length / 4

		file.seek(textures_offset)
		tex_infos.resize(textures_count)
		for i in range(textures_count):
			tex_infos[i] = TexInfo.new()
			var bytes = file.get_buffer(64)
			tex_infos[i].name = bytes.get_string_from_utf8()
			tex_infos[i].flags = file.get_32()
			tex_infos[i].contents = file.get_32()

		file.seek(planes_offset)
		bsp_planes.resize(planes_count)
		for i in range(planes_count):
			var plane_normal = Vector3(0, 0, 0)
			plane_normal.x = -file.get_float()
			plane_normal.z = -file.get_float()
			plane_normal.y = file.get_float()
			var distance = file.get_float() * IMPORT_SCALE
			bsp_planes[i] = Plane(plane_normal, distance)

		file.seek(leaves_offset)
		bsp_leaves.resize(leaves_count)
		for i in range(leaves_count):
			bsp_leaves[i] = BSPLeaf.new()
			bsp_leaves[i].visCluster = file.get_32()
			bsp_leaves[i].portalArea = file.get_32()
			bsp_leaves[i].mins = [0, 0, 0]
			bsp_leaves[i].mins[0] = file.get_32()
			bsp_leaves[i].mins[1] = file.get_32()
			bsp_leaves[i].mins[2] = file.get_32()
			bsp_leaves[i].maxs = [0, 0, 0]
			bsp_leaves[i].maxs[0] = file.get_32()
			bsp_leaves[i].maxs[1] = file.get_32()
			bsp_leaves[i].maxs[2] = file.get_32()
			bsp_leaves[i].leafFace = file.get_32()
			bsp_leaves[i].n_leafFaces = file.get_32()
			bsp_leaves[i].leafBrush = file.get_32()
			bsp_leaves[i].n_leafBrushes = file.get_32()

		file.seek(nodes_offset)
		bsp_nodes.resize(nodes_count)
		for i in range(nodes_count):
			bsp_nodes[i] = BSPNode.new()
			bsp_nodes[i].planeIndex = file.get_32()
			bsp_nodes[i].child1 = file.get_32()
			bsp_nodes[i].child2 = file.get_32()
			bsp_nodes[i].mins = [0, 0, 0]
			bsp_nodes[i].mins[0] = file.get_32()
			bsp_nodes[i].mins[1] = file.get_32()
			bsp_nodes[i].mins[2] = file.get_32()
			bsp_nodes[i].maxs = [0, 0, 0]
			bsp_nodes[i].maxs[0] = file.get_32()
			bsp_nodes[i].maxs[1] = file.get_32()
			bsp_nodes[i].maxs[2] = file.get_32()
			
		file.seek(leaffaces_offset)
		bsp_leaffaces.resize(leaffaces_count)
		for i in range(leaffaces_count):
			bsp_leaffaces[i] = file.get_32()

		file.seek(models_offset)
		bsp_models.resize(model_count)
		for i in range(model_count):
			bsp_models[i] = BSPModel.new()
			bsp_models[i].mins = Vector3(0.0, 0.0, 0.0)
			bsp_models[i].mins.x = -file.get_float() * IMPORT_SCALE
			bsp_models[i].mins.z = -file.get_float() * IMPORT_SCALE
			bsp_models[i].mins.y = file.get_float() * IMPORT_SCALE
			bsp_models[i].maxs = Vector3(0.0, 0.0, 0.0)
			bsp_models[i].maxs.x = -file.get_float() * IMPORT_SCALE
			bsp_models[i].maxs.z = -file.get_float() * IMPORT_SCALE
			bsp_models[i].maxs.y = file.get_float() * IMPORT_SCALE
			bsp_models[i].face = file.get_32()
			bsp_models[i].n_faces = file.get_32()
			bsp_models[i].brush = file.get_32()
			bsp_models[i].n_brushes = file.get_32()

		file.seek(vertices_offset)
		bsp_vertices.resize(vertex_count)
		for i in range(vertex_count):
			bsp_vertices[i] = BSPVertex.new()
			bsp_vertices[i].position = Vector3(0.0, 0.0, 0.0)
			bsp_vertices[i].position.x = file.get_float() * IMPORT_SCALE
			bsp_vertices[i].position.z = -file.get_float() * IMPORT_SCALE
			bsp_vertices[i].position.y = file.get_float() * IMPORT_SCALE
			bsp_vertices[i].tex_coord = Vector2(0.0, 0.0)
			bsp_vertices[i].tex_coord.x = file.get_float()
			bsp_vertices[i].tex_coord.y = -file.get_float()
			bsp_vertices[i].lm_coord = Vector2(0.0, 0.0)
			bsp_vertices[i].lm_coord.x = file.get_float()
			bsp_vertices[i].lm_coord.y = -file.get_float()
			bsp_vertices[i].normal = Vector3(0.0, 0.0, 0.0)
			bsp_vertices[i].normal.x = file.get_float()
			bsp_vertices[i].normal.z = -file.get_float()
			bsp_vertices[i].normal.y = file.get_float()
			bsp_vertices[i].normal = bsp_vertices[i].normal.normalized()
			bsp_vertices[i].color = Color(0, 0, 0, 0)
			bsp_vertices[i].color.r8 = file.get_8()
			bsp_vertices[i].color.g8 = file.get_8()
			bsp_vertices[i].color.b8 = file.get_8()
			bsp_vertices[i].color.a8 = file.get_8()

		file.seek(faces_offset)
		bsp_faces.resize(face_count)
		for i in range(face_count):
			bsp_faces[i] = BSPFace.new()
			bsp_faces[i].tex_index = file.get_32()
			bsp_faces[i].effect = file.get_32()
			bsp_faces[i].type = file.get_32()
			bsp_faces[i].vertex = file.get_32()
			bsp_faces[i].n_vtx = file.get_32()
			bsp_faces[i].mesh_vertex = file.get_32()
			bsp_faces[i].n_mesh_vtx = file.get_32()
			bsp_faces[i].lm_index = file.get_32()
			bsp_faces[i].lm_start_x = file.get_32()
			bsp_faces[i].lm_start_y = file.get_32()
			bsp_faces[i].lm_size_x = file.get_32()
			bsp_faces[i].lm_size_y = file.get_32()
			bsp_faces[i].lm_origin = Vector3(0.0, 0.0, 0.0)
			bsp_faces[i].lm_origin.x = file.get_float()
			bsp_faces[i].lm_origin.y = file.get_float()
			bsp_faces[i].lm_origin.z = file.get_float()
			bsp_faces[i].lm_vector1 = Vector3(0.0, 0.0, 0.0)
			bsp_faces[i].lm_vector1.x = file.get_float()
			bsp_faces[i].lm_vector1.y = file.get_float()
			bsp_faces[i].lm_vector1.z = file.get_float()
			bsp_faces[i].lm_vector2 = Vector3(0.0, 0.0, 0.0)
			bsp_faces[i].lm_vector2.x = file.get_float()
			bsp_faces[i].lm_vector2.y = file.get_float()
			bsp_faces[i].lm_vector2.z = file.get_float()
			bsp_faces[i].normal = Vector3(0.0, 0.0, 0.0)
			bsp_faces[i].normal.x = -file.get_float()
			bsp_faces[i].normal.z = -file.get_float()
			bsp_faces[i].normal.y = file.get_float()
			bsp_faces[i].size_x = file.get_float()
			bsp_faces[i].size_y = file.get_float()
			
		file.seek(m_vertices_offset)
		bsp_mesh_vertices.resize(m_vertex_count)
		for i in range(m_vertex_count):
			bsp_mesh_vertices[i] = file.get_32()

		file.seek(entities_offset)
		var current_bsp_entity = BSPEntity.new()
		var str_buf = PackedByteArray()
		var c1 = 0
		var reading_str = false
		for i in range(entities_length):
			c1 = file.get_8()
			if reading_str:
				if c1 == 34: # "
					current_bsp_entity.kv_entries.push_back(str_buf.get_string_from_utf8())
					current_bsp_entity.entry_count += 1
					str_buf.clear()
					reading_str = false
				else:
					str_buf.push_back(c1)
			else:
				if c1 == 123: # {
					current_bsp_entity = BSPEntity.new()
					str_buf.clear()
				elif c1 == 34:
					reading_str = true
				elif c1 == 125: # }
					bsp_entities.push_back(current_bsp_entity)
		file.close()
		
		for i in range(bsp_entities.size()):
			var ent_name = bsp_entities[i].GetString("classname")
			if ent_name == "info_origin":
				var origin = InfoOrigin.new()
				origin.position = BSPImporter.Vector3FromQ3(bsp_entities[i].GetVector3("origin"))
				origin.modelName = bsp_entities[i].GetString("name")
				info_origins.push_back(origin)
			if ent_name.begins_with("brush_"):
				bsp_entities[i].brush = true
				var bme = BrushModelEntity.new()
				bme.modelIndex = bsp_entities[i].GetString("model").substr(1).to_int()
				bme.entityIndex = i
				bme.name = bsp_entities[i].GetString("name")
				bme.parent = bsp_entities[i].GetString("parent")
				bme.collision = bsp_entities[i].GetInt("collision", 1)
				bme.lm_scale = bsp_entities[i].GetFloat("lm_scale", 1.0)
				bme.smoothing = bsp_entities[i].GetFloat("smoothing", 30.0)
				var spawn_flags = bsp_entities[i].GetInt("spawnflags", 0)
				bme.isStatic = (spawn_flags & 0x00000001 > 0)
				bme.isMaster = (spawn_flags & 0x00000002 > 0)
				bme.isInstance = (spawn_flags & 0x00000004 > 0)
				bme.origin = (bsp_models[bme.modelIndex].mins + bsp_models[bme.modelIndex].maxs) * 0.5;
				for o1 in info_origins:
					if bme.name == o1.modelName:
						bme.origin = o1.position
						break
				brush_model_entities.push_back(bme)
		brush_model_entities = BSPImporter.sort_model_entities(brush_model_entities)
		
		for leaf in bsp_leaves:
			leaf.GetArea()
		for node in bsp_nodes:
			if node.child1 & 0x80000000:
				node.child1 -= 0x100000000
			if node.child2 & 0x80000000:
				node.child2 -= 0x100000000
		
		

		
	
	
		
static func BuildMapMesh():
	var face_vertices = PackedVector3Array()
	var face_normals = PackedVector3Array()
	var face_uvs = PackedVector2Array()
	var face_tangents = PackedFloat32Array()
	var face_indices = PackedInt32Array()
	
	var surf_vtx_offset = 0
	for f1 in bsp_data.bsp_faces:
		for i1 in range(f1.n_vtx):
			face_vertices.push_back(bsp_data.bsp_vertices[f1.vertex + i1].position)
			face_normals.push_back(bsp_data.bsp_vertices[f1.vertex + i1].normal)
			face_uvs.push_back(bsp_data.bsp_vertices[f1.vertex + i1].tex_coord)
		for i2 in range(f1.n_mesh_vtx):
			face_indices.push_back(bsp_data.bsp_mesh_vertices[f1.mesh_vertex + i2] + surf_vtx_offset)
		surf_vtx_offset += f1.n_vtx
	face_tangents.resize(face_vertices.size() * 4)
			
	var editor_interface = Engine.get_singleton("EditorInterface")
	var scene_root = editor_interface.get_editor_main_screen().get_tree().get_edited_scene_root()
	var mesh_instance = MeshInstance3D.new()
	scene_root.add_child(mesh_instance, true, Node.INTERNAL_MODE_DISABLED)
	mesh_instance.owner = scene_root
	mesh_instance.name = "M1"
	mesh_instance.visible = true
	
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = face_vertices
	arrays[Mesh.ARRAY_NORMAL] = face_normals
	arrays[Mesh.ARRAY_TANGENT] = face_tangents
	arrays[Mesh.ARRAY_TEX_UV] = face_uvs
	arrays[Mesh.ARRAY_INDEX] = face_indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	arr_mesh.regen_normal_maps()
	mesh_instance.mesh = arr_mesh
	add_trimesh_collision_for(mesh_instance)


static func BuildMap():
	pass

static func average_mesh_normals(mesh1: ArrayMesh, max_angle: float = 45.0) -> ArrayMesh:
	var new_mesh := ArrayMesh.new()
	for surface in mesh1.get_surface_count():
		var arrays = mesh1.surface_get_arrays(surface)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var v_count = vertices.size()
		var new_normals = PackedVector3Array()
		new_normals.resize(v_count)
		var max_angle_rad = deg_to_rad(max_angle)
		var max_dot = cos(max_angle_rad)
		for i in range(v_count):
			var base_pos = vertices[i]
			var base_n = normals[i]
			var sum_normal = base_n
			var group_count = 1
			for j in range(v_count):
				if i == j:
					continue
				if base_pos.distance_to(vertices[j]) < 0.01:
					if base_n.dot(normals[j]) > max_dot:
						sum_normal += normals[j]
						group_count += 1
			if group_count < 2:
				new_normals[i] = base_n
			else:
				new_normals[i] = (sum_normal / float(group_count)).normalized()
		arrays[Mesh.ARRAY_NORMAL] = new_normals
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return new_mesh
	
static func create_optimized_collision_mesh(mesh: Mesh, weld_threshold := 0.01) -> ArrayMesh:
	var all_vertices = []
	var all_indices = PackedInt32Array()
	var offset = 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var inds: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if inds.is_empty():
			inds = PackedInt32Array()
			for i in range(verts.size()):
				inds.append(i)
		for v in verts:
			all_vertices.append(v)
		for i in inds:
			all_indices.append(i + offset)
		offset += verts.size()
	var cell = weld_threshold
	var grid := {}  # Vector3i -> int (new index)
	var welded_vertices = []
	var index_remap = {}  # int -> int
	for i in range(all_vertices.size()):
		var v = all_vertices[i]
		var h = Vector3i(int(floor(v.x / cell)), int(floor(v.y / cell)), int(floor(v.z / cell)))
		var found = false
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var key = Vector3i(h.x + x, h.y + y, h.z + z)
					if key in grid:
						var candidate_index = grid[key]
						var candidate = welded_vertices[candidate_index]
						if v.distance_to(candidate) <= weld_threshold:
							index_remap[i] = candidate_index
							found = true
							break
			if found:
				break
		if not found:
			var new_index = welded_vertices.size()
			welded_vertices.append(v)
			grid[h] = new_index
			index_remap[i] = new_index
	var final_indices = PackedInt32Array()
	final_indices.resize(all_indices.size())
	for i in range(all_indices.size()):
		final_indices[i] = index_remap[all_indices[i]]
	var cleaned_indices = PackedInt32Array()
	cleaned_indices.resize(final_indices.size())

	for i in range(0, final_indices.size(), 3):
		var a = final_indices[i]
		var b = final_indices[i + 1]
		var c = final_indices[i + 2]
		if a != b and b != c and a != c:
			cleaned_indices.append(a)
			cleaned_indices.append(b)
			cleaned_indices.append(c)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(welded_vertices)
	arrays[Mesh.ARRAY_INDEX] = cleaned_indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
	
static func create_collider_for_mesh(mesh_instance: MeshInstance3D, use_sphere: bool = false) -> StaticBody3D:
	var parent = mesh_instance.get_parent()
	if parent == null:
		push_error("MeshInstance3D has no parent")
		return null
	var static_body = StaticBody3D.new()
	static_body.name = mesh_instance.name + "_Collider"
	parent.add_child(static_body)
	static_body.owner = parent.get_tree().edited_scene_root if Engine.is_editor_hint() else parent
	static_body.global_transform = mesh_instance.global_transform
	var aabb = mesh_instance.get_aabb()
	var size = aabb.size
	var center = aabb.get_center()
	var collision_shape = CollisionShape3D.new()
	if use_sphere:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = max(size.x, max(size.y, size.z)) / 2.0
		collision_shape.shape = sphere_shape
	else:
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
	collision_shape.position = center
	static_body.add_child(collision_shape)
	collision_shape.owner = static_body.owner
	return static_body
	
static func add_trimesh_collision_for(mesh_instance: MeshInstance3D) -> StaticBody3D:
	if mesh_instance.mesh == null:
		push_error("MeshInstance3D has no mesh.")
		return null
	var parent := mesh_instance.get_parent()
	if parent == null:
		push_error("MeshInstance3D has no parent; cannot add sibling.")
		return null
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.owner = mesh_instance.owner   # ensure it appears in editor / saved
	body.name = mesh_instance.name + "_StaticBody"
	var col_shape := CollisionShape3D.new()
	body.add_child(col_shape)
	col_shape.owner = mesh_instance.owner
	col_shape.name = "Collision"
	var cm = create_optimized_collision_mesh(mesh_instance.mesh)
	var trimesh = cm.create_trimesh_shape()
	col_shape.shape = trimesh
	body.transform = mesh_instance.transform
	return body
	
static func sort_model_entities(entities: Array) -> Array:
	var sorted = []
	var processed = {}
	var standalone = []
	var masters_with_instances = {}
	for entity in entities:
		if entity.isMaster:
			var has_instances = false
			for other in entities:
				if other.isInstance and not other.isMaster and other.name == entity.name:
					has_instances = true
					break
			if has_instances:
				if not masters_with_instances.has(entity.name):
					masters_with_instances[entity.name] = []
				masters_with_instances[entity.name].append(entity)
	for master_name in masters_with_instances.keys():
		for master in masters_with_instances[master_name]:
			sorted.append(master)
			processed[master] = true
		for entity in entities:
			if entity.isInstance and not entity.isMaster and entity.name == master_name:
				sorted.append(entity)
				processed[entity] = true
	for entity in entities:
		if not processed.has(entity):
			standalone.append(entity)
	sorted.append_array(standalone)
	return sorted

static func to_signed32(u: int) -> int:
	if u & 0x80000000:
		return u - 0x100000000
	return u

static func Vector3FromQ3(input) -> Vector3:
	return Vector3(-input.x, input.z, -input.y) * IMPORT_SCALE;

static func Vector3FromQ3NoScale(input) -> Vector3:
	return Vector3(-input.x, input.z, -input.y);

static func GetTriangleArea(p1: Vector3, p2: Vector3, p3: Vector3) -> float:
	return (p2 - p1).cross(p3 - p1).length() * 0.5

var _file_dialog
var import_button
var ent_button
var split_button
var v1 = 0.0
var dock

func _enter_tree():
	dock = preload("res://addons/gbsp_import/gbsp_tab.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)
	import_button = dock.get_node("ImportButton")
	import_button.connect("pressed", _do_work)
	ent_button = dock.get_node("EntButton")
	ent_button.connect("toggled", set_load_ent)
	split_button = dock.get_node("SplitButton")
	split_button.connect("toggled", set_split_mesh)
	BSPImporter.load_entities = true
	BSPImporter.split_main_mesh = true
	add_tool_menu_item('Find Texture Borders', _do_work)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.connect("file_selected", _on_FileDialog_file_selected)
	var editor_interface = get_editor_interface()
	var base_control = editor_interface.get_base_control()
	base_control.add_child(_file_dialog)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()

	_file_dialog.queue_free()

func _do_work():
	_file_dialog.popup_centered_ratio()
	
func  set_load_ent(value1):
	load_entities = value1
func set_split_mesh(value1):
	split_main_mesh = value1

func _on_FileDialog_file_selected(path):
	bsp_data = BSPMapData.new()
	BSPImporter.scene_root = get_tree().get_edited_scene_root() as Node3D # Give BSP Data scene root handle
	bsp_data.LoadMapFile(path)
