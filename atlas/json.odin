package atlas

import "core:fmt"
import "core:os"
import "core:encoding/json"

Entry :: struct {
	x, y:          i32,
	width, height: i32,
}

Output :: struct {
	width, height: i32,
	size:          int,
	entries:       map[string]Entry,
}

write_atlas_json :: proc(images: [dynamic]Image, width: i32, height: i32) {
	output: Output

	output.width = width
	output.height = height
	output.size = len(images)

	for i in images {
		output.entries[i.name] = Entry{i.x, i.y, i.width, i.height}
	}

	json_bytes, err := json.marshal(output)

	if err != nil {
		fmt.println("Error marshaling:", err)
		return
	}

	ok := os.write_entire_file("atlas.json", json_bytes)
	if !ok {
		fmt.println("Failed to write atlas.json file")
		return
	}
}
