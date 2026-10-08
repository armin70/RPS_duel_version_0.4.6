@tool
extends Node3D

# Choose any material from res://land/materials/ in the Inspector.
# The two meshes share one PlaneMesh but keep independent materials.
@export var left_material: Material:
    set(value):
        left_material = value
        _apply_materials()

@export var right_material: Material:
    set(value):
        right_material = value
        _apply_materials()


func _ready() -> void:
    _apply_materials()


func _apply_materials() -> void:
    var left := get_node_or_null("GroundLeft") as MeshInstance3D
    var right := get_node_or_null("GroundRight") as MeshInstance3D
    if left != null:
        left.material_override = left_material
    if right != null:
        right.material_override = right_material


# Optional runtime API for changing sides independently.
func set_ground_materials(left: Material, right: Material) -> void:
    left_material = left
    right_material = right
    _apply_materials()
