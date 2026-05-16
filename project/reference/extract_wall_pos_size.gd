static func execute(node: Node) -> String:
    var result := ""
    
    var house_building: Node3D = node.get_node("../../BlueprintReference")
    var walls_node: Node3D = house_building.get_node("Walls")
    
    result += "Wall Data Extracted:\n"
    result += "====================\n"
    
    for wall in walls_node.get_children():
        if wall is MeshInstance3D:
            var pos: Vector3 = wall.position
            var size: Vector3 = wall.mesh.size
            result += "Wall: " + wall.name + "\n"
            result += "  Position: " + str(pos) + "\n"
            result += "  Size: " + str(size) + "\n"
            result += "\n"
    
    return result