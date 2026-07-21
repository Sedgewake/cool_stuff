bl_info = {
    "name": "Mesh Debris Fracture",
    "author": "Assistant",
    "version": (1, 0, 0),
    "blender": (2, 79, 0),
    "location": "View3D > Tools > Debris Fracture",
    "description": "Split mesh into randomly shaped debris with capped faces",
    "category": "Mesh"
}

import bpy
import bmesh
from mathutils import Vector, Matrix
from random import random, seed, uniform
import math


def create_random_plane(bbox_center, bbox_size, offset_range=0.3):
    """Create a random cutting plane within the bounding box"""
    # Random point within the bounding box
    point = Vector((
        bbox_center.x + uniform(-bbox_size.x * offset_range, bbox_size.x * offset_range),
        bbox_center.y + uniform(-bbox_size.y * offset_range, bbox_size.y * offset_range),
        bbox_center.z + uniform(-bbox_size.z * offset_range, bbox_size.z * offset_range)
    ))
    
    # Random normal direction
    theta = uniform(0, 2 * math.pi)
    phi = uniform(0, math.pi)
    normal = Vector((
        math.sin(phi) * math.cos(theta),
        math.sin(phi) * math.sin(theta),
        math.cos(phi)
    ))
    normal.normalize()
    
    return point, normal


def bisect_mesh_with_fill(obj, point, normal, assign_cap_material=False):
    """Bisect mesh and fill the cut with a face, returns two new objects"""
    # Create two duplicate objects
    bpy.ops.object.select_all(action='DESELECT')
    obj.select = True
    bpy.context.scene.objects.active = obj
    
    # First piece
    bpy.ops.object.duplicate()
    obj1 = bpy.context.active_object
    obj1.name = obj.name + "_piece"
    
    # Second piece
    bpy.ops.object.select_all(action='DESELECT')
    obj.select = True
    bpy.context.scene.objects.active = obj
    bpy.ops.object.duplicate()
    obj2 = bpy.context.active_object
    obj2.name = obj.name + "_piece"
    
    # Get or create cap material if needed
    cap_material = None
    cap_material_index = -1
    if assign_cap_material:
        if "cap_mtl" not in bpy.data.materials:
            cap_material = bpy.data.materials.new(name="cap_mtl")
            cap_material.diffuse_color = (0.8, 0.8, 0.8)
        else:
            cap_material = bpy.data.materials["cap_mtl"]
    
    # Process first piece (keep inner)
    bpy.ops.object.select_all(action='DESELECT')
    obj1.select = True
    bpy.context.scene.objects.active = obj1
    
    # Add cap material to object if needed
    if assign_cap_material and cap_material:
        if cap_material.name not in obj1.data.materials:
            obj1.data.materials.append(cap_material)
        cap_material_index = obj1.data.materials.find(cap_material.name)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    
    bpy.ops.mesh.bisect(
        plane_co=point,
        plane_no=normal,
        use_fill=True,
        clear_inner=False,
        clear_outer=True
    )
    
    # Get fresh bmesh after bisect
    bpy.ops.mesh.select_all(action='DESELECT')
    me = obj1.data
    bm = bmesh.from_edit_mesh(me)
    
    # Select faces that are aligned with the cutting plane (the caps)
    for face in bm.faces:
        dot = face.normal.dot(normal)
        if abs(abs(dot) - 1.0) < 0.01:  # Face is parallel to cutting plane
            face.select = True
            # Assign cap material to this face
            if assign_cap_material and cap_material_index >= 0:
                face.material_index = cap_material_index
    
    bmesh.update_edit_mesh(me)
    
    # Apply planar unwrap to selected cap faces if any are selected
    has_selection = any(f.select for f in bm.faces)
    if has_selection:
        bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.001)
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Process second piece (keep outer)
    bpy.ops.object.select_all(action='DESELECT')
    obj2.select = True
    bpy.context.scene.objects.active = obj2
    
    # Add cap material to object if needed
    if assign_cap_material and cap_material:
        if cap_material.name not in obj2.data.materials:
            obj2.data.materials.append(cap_material)
        cap_material_index = obj2.data.materials.find(cap_material.name)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    
    bpy.ops.mesh.bisect(
        plane_co=point,
        plane_no=normal,
        use_fill=True,
        clear_inner=True,
        clear_outer=False
    )
    
    # Get fresh bmesh after bisect
    bpy.ops.mesh.select_all(action='DESELECT')
    me = obj2.data
    bm = bmesh.from_edit_mesh(me)
    
    # Select cap faces
    for face in bm.faces:
        dot = face.normal.dot(normal)
        if abs(abs(dot) - 1.0) < 0.01:
            face.select = True
            # Assign cap material to this face
            if assign_cap_material and cap_material_index >= 0:
                face.material_index = cap_material_index
    
    bmesh.update_edit_mesh(me)
    
    # Apply planar unwrap to selected cap faces if any are selected
    has_selection = any(f.select for f in bm.faces)
    if has_selection:
        bpy.ops.uv.unwrap(method='ANGLE_BASED', margin=0.001)
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Remove original object
    bpy.ops.object.select_all(action='DESELECT')
    obj.select = True
    bpy.ops.object.delete()
    
    return [obj1, obj2]


def get_bbox_info(obj):
    """Get bounding box center and size in world space"""
    bbox_corners = [obj.matrix_world * Vector(corner) for corner in obj.bound_box]
    
    min_x = min(v.x for v in bbox_corners)
    max_x = max(v.x for v in bbox_corners)
    min_y = min(v.y for v in bbox_corners)
    max_y = max(v.y for v in bbox_corners)
    min_z = min(v.z for v in bbox_corners)
    max_z = max(v.z for v in bbox_corners)
    
    center = Vector((
        (min_x + max_x) / 2,
        (min_y + max_y) / 2,
        (min_z + max_z) / 2
    ))
    
    size = Vector((
        max_x - min_x,
        max_y - min_y,
        max_z - min_z
    ))
    
    return center, size


def fracture_mesh(obj, num_pieces, random_seed=0, assign_cap_material=False):
    """Fracture mesh into debris pieces"""
    seed(random_seed)
    
    # Start with a list containing the original object
    current_pieces = [obj]
    
    # Calculate number of cuts needed
    num_cuts = num_pieces - 1
    
    for i in range(num_cuts):
        if not current_pieces:
            break
            
        # Pick a random piece to split
        piece_index = int(random() * len(current_pieces))
        piece_to_split = current_pieces.pop(piece_index)
        
        # Get bounding box info
        bbox_center, bbox_size = get_bbox_info(piece_to_split)
        
        # Create random cutting plane
        point, normal = create_random_plane(bbox_center, bbox_size)
        
        # Bisect and get two new pieces
        new_pieces = bisect_mesh_with_fill(piece_to_split, point, normal, assign_cap_material)
        
        # Add new pieces to the list
        current_pieces.extend(new_pieces)
    
    return current_pieces


class MESH_OT_debris_fracture(bpy.types.Operator):
    """Fracture selected mesh into random debris pieces"""
    bl_idname = "mesh.debris_fracture"
    bl_label = "Debris Fracture"
    bl_options = {'REGISTER', 'UNDO'}
    
    num_pieces = bpy.props.IntProperty(
        name="Number of Pieces",
        description="Number of debris pieces to create",
        default=5,
        min=2,
        max=50
    )
    
    random_seed = bpy.props.IntProperty(
        name="Random Seed",
        description="Seed for random number generator",
        default=0,
        min=0
    )
    
    assign_cap_material = bpy.props.BoolProperty(
        name="Assign Cap Material",
        description="Create and assign 'cap_mtl' material to cap faces",
        default=True
    )
    
    def execute(self, context):
        obj = context.active_object
        
        if obj is None or obj.type != 'MESH':
            self.report({'ERROR'}, "Please select a mesh object")
            return {'CANCELLED'}
        
        # Make sure we're in object mode
        if context.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        
        # Ensure UV map exists
        if not obj.data.uv_textures:
            obj.data.uv_textures.new(name="UVMap")
        
        # Fracture the mesh
        pieces = fracture_mesh(obj, self.num_pieces, self.random_seed, self.assign_cap_material)
        
        self.report({'INFO'}, "Created {} debris pieces".format(len(pieces)))
        
        return {'FINISHED'}


class VIEW3D_PT_debris_fracture(bpy.types.Panel):
    """Panel for debris fracture tools"""
    bl_label = "Debris Fracture"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'TOOLS'
    bl_category = "Tools"
    
    def draw(self, context):
        layout = self.layout
        
        col = layout.column(align=True)
        col.label(text="Fracture Settings:")
        col.operator("mesh.debris_fracture")


def register():
    bpy.utils.register_class(MESH_OT_debris_fracture)
    bpy.utils.register_class(VIEW3D_PT_debris_fracture)


def unregister():
    bpy.utils.unregister_class(MESH_OT_debris_fracture)
    bpy.utils.unregister_class(VIEW3D_PT_debris_fracture)


if __name__ == "__main__":
    register()
