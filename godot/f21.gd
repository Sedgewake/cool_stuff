static func average_mesh_normals(mesh1: ArrayMesh, max_angle: float = 45.0) -> ArrayMesh:
	var new_mesh := ArrayMesh.new()
	var surface_count := mesh1.get_surface_count()

	var max_angle_rad := deg_to_rad(max_angle)
	var max_dot := cos(max_angle_rad)
	var threshold := 0.01   # merge distance

	for surface in surface_count:
		var arrays = mesh1.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var v_count := vertices.size()

		# ==== 1) Build spatial buckets ====
		# key = Vector3i cell position
		# value = Array of vertex indices in this cell
		var buckets := {}

		# Grid cell size = threshold (so close vertices end up in same/neighbour bucket)
		var cell_size := threshold

		for i in range(v_count):
			var pos = vertices[i]
			var key = Vector3i(
				int(pos.x / cell_size),
				int(pos.y / cell_size),
				int(pos.z / cell_size)
			)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(i)

		# ==== 2) Compute smoothed normals ====
		var new_normals := PackedVector3Array()
		new_normals.resize(v_count)

		for i in range(v_count):
			var pos_i = vertices[i]
			var n_i = normals[i]

			var sum_n = n_i
			var count := 1

			var cell = Vector3i(
				int(pos_i.x / cell_size),
				int(pos_i.y / cell_size),
				int(pos_i.z / cell_size)
			)

			# Search only in 3×3×3 neighbour cells (27 total instead of v_count)
			for dx in -1:2:
				for dy in -1:2:
					for dz in -1:2:
						var key = cell + Vector3i(dx, dy, dz)
						if not buckets.has(key):
							continue

						for j in buckets[key]:
							if i == j:
								continue

							# distance check
							if pos_i.distance_to(vertices[j]) > threshold:
								continue

							# angle check
							if n_i.dot(normals[j]) < max_dot:
								continue

							sum_n += normals[j]
							count += 1

			new_normals[i] = (sum_n / count).normalized()

		arrays[Mesh.ARRAY_NORMAL] = new_normals
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return new_mesh
	
	static func compute_tangents(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> PackedFloat32Array:

	var vcount := vertices.size()

	# tangents WITHOUT handedness (Vector3)
	var tan1 := []
	var tan2 := []
	tan1.resize(vcount)
	tan2.resize(vcount)

	for i in vcount:
		tan1[i] = Vector3.ZERO
		tan2[i] = Vector3.ZERO

	var tri_count := indices.size() / 3

	for t in tri_count:
		var i1 = indices[t * 3 + 0]
		var i2 = indices[t * 3 + 1]
		var i3 = indices[t * 3 + 2]

		var p1 = vertices[i1]
		var p2 = vertices[i2]
		var p3 = vertices[i3]

		var uv1 = uvs[i1]
		var uv2 = uvs[i2]
		var uv3 = uvs[i3]

		var x1 = p2.x - p1.x
		var x2 = p3.x - p1.x
		var y1 = p2.y - p1.y
		var y2 = p3.y - p1.y
		var z1 = p2.z - p1.z
		var z2 = p3.z - p1.z

		var s1 = uv2.x - uv1.x
		var s2 = uv3.x - uv1.x
		var t1 = uv2.y - uv1.y
		var t2 = uv3.y - uv1.y

		var denom = (s1 * t2 - s2 * t1)
		if abs(denom) < 1e-10:
			# Degenerate UV region → skip
			continue

		var r = 1.0 / denom

		var sdir = Vector3(
			(t2 * x1 - t1 * x2) * r,
			(t2 * y1 - t1 * y2) * r,
			(t2 * z1 - t1 * z2) * r
		)

		var tdir = Vector3(
			(s1 * x2 - s2 * x1) * r,
			(s1 * y2 - s2 * y1) * r,
			(s1 * z2 - s2 * z1) * r
		)

		tan1[i1] += sdir
		tan1[i2] += sdir
		tan1[i3] += sdir

		tan2[i1] += tdir
		tan2[i2] += tdir
		tan2[i3] += tdir

	# Now build the packed tangent array
	var result := PackedFloat32Array()
	result.resize(vcount * 4)

	for i in vcount:
		var n = normals[i]
		var t = tan1[i]

		# Orthonormalize tangent with Gram-Schmidt
		var tangent = (t - n * n.dot(t)).normalized()

		# Handedness (bitangent direction)
		var w = 1.0
		if n.cross(tangent).dot(tan2[i]) < 0.0:
			w = -1.0

		# Store tangent as 4 floats: x, y, z, w
		result[i * 4 + 0] = tangent.x
		result[i * 4 + 1] = tangent.y
		result[i * 4 + 2] = tangent.z
		result[i * 4 + 3] = w

	return result