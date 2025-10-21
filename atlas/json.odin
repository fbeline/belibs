package atlas

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Entry :: struct {
	x, y:          i32,
	width, height: i32,
}

Animation :: struct {
	fps:    int,
	frames: [dynamic]Entry,
}

Output :: struct {
	width, height: i32,
	size:          int,
	images:        map[string]Entry,
	animations:    map[string]Animation,
}

write_atlas_json :: proc(images: [dynamic]Image, width: i32, height: i32) {
	output: Output

	output.width = width
	output.height = height
	output.size = len(images)

	slice.sort_by(images[:], proc(a, b: Image) -> bool {
		return a.name < b.name
	})

	for i in images {
		slash_index := strings.index(i.name, "/")
		entry := Entry{i.x, i.y, i.width, i.height}
		if slash_index >= 0 {
			key := i.name[0:slash_index]
			anim, has := &output.animations[key]
			if !has {
				output.animations[key] = Animation {
					fps    = 10,
					frames = make([dynamic]Entry),
				}
				anim = &output.animations[key]
			}

			append(&anim.frames, entry)
		} else {
			output.images[i.name] = entry
		}
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
