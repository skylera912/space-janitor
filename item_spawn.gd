extends Node3D

var scene_dict ={ 
"item1": preload("res://item1_scene.tscn"),
"item2": preload("res://item2_scene.tscn"),
}

var name_map = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instantiate_items("item1", 2, 2)
	
	
func instantiate_items(item_name: String, count: int, spacing: float) -> void:
	for i in range(count): #i stands for iterate or how many times
		var scene_to_instantiate = scene_dict[item_name]
		var new_instance = scene_to_instantiate.instantiate()
		new_instance.name = item_name + "_" + str(i)
		new_instance.transform.origin = Vector3(i * spacing, 1, 0)
		add_child(new_instance)
		
		
		
		print("Added Child Node:", new_instance.name)
		#print("Current children of this node:")
		#for child in get_children():
			#print(child.name)
			
			
			#var scene_to_instantiate = scene_dict.get(item.name, null)
