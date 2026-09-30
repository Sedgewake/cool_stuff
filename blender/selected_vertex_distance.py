bl_info = {
    "name": "Selected Vertex Distance",
    "author": "OpenAI",
    "version": (1, 0),
    "blender": (2, 79, 0),
    "location": "View3D > Tools",
    "description": "Displays distance between two selected vertices",
    "category": "Mesh",
}

import bpy
import bmesh
from mathutils import Vector


def get_selected_vertex_distance(context):
    obj = context.active_object

    if not obj:
        return None

    if obj.type != 'MESH':
        return None

    if context.mode != 'EDIT_MESH':
        return None

    bm = bmesh.from_edit_mesh(obj.data)

    selected = [v for v in bm.verts if v.select]

    if len(selected) != 2:
        return None

    v1 = obj.matrix_world * selected[0].co
    v2 = obj.matrix_world * selected[1].co

    return (v2 - v1).length


class VIEW3D_PT_vertex_distance(bpy.types.Panel):
    bl_label = "Vertex Distance"
    bl_idname = "VIEW3D_PT_vertex_distance"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'TOOLS'
    bl_category = "Tools"

    def draw(self, context):
        layout = self.layout

        distance = get_selected_vertex_distance(context)

        if distance is None:
            layout.label("Select exactly 2 vertices")
        else:
            layout.label("Distance:")
            layout.label("{:.6f}".format(distance))


classes = (
    VIEW3D_PT_vertex_distance,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()