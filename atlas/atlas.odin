package beatlas

import "core:bytes"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import stbi "vendor:stb/image"

Image :: struct {
	name:                    string,
	x, y:                    i32,
	width, height, channels: i32,
	data:                    [^]u8,
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.println("Usage: atlas <dir>")
		return
	}

	input_path := os.args[1]

	images, ok := load_images(input_path)
	if !ok {
		return
	}

	for i in images {
		fmt.printfln("%v [%vx%v]", i.name, i.width, i.height)
	}
}

load_images :: proc(
	dir_path: string,
	allocator := context.allocator,
) -> (
	images: [dynamic]Image,
	ok: bool,
) {
	dir_handle, open_err := os.open(dir_path)
	if open_err != nil {
		fmt.printf("Error opening directory: %v\n", open_err)
		return nil, false
	}
	defer os.close(dir_handle)
	defer free_all(context.temp_allocator)

	result := make([dynamic]Image, allocator = allocator)

	// Read all files in directory
	file_infos, read_err := os.read_dir(dir_handle, -1, context.temp_allocator)
	if read_err != nil {
		fmt.printf("Error reading directory: %v\n", read_err)
		return nil, false
	}

	for file_info in file_infos {
		if file_info.is_dir {
			// TODO: read nested dirs
			continue
		}

		// Check if file is an image (by extension)
		ext := filepath.ext(file_info.name)
		if ext == ".png" {
			image: Image
			image.name = strings.clone(file_info.name, allocator)

			full_path := filepath.join({dir_path, file_info.name}, allocator)

			image.data = stbi.load(
				strings.clone_to_cstring(full_path, context.temp_allocator),
				&image.width,
				&image.height,
				&image.channels,
				4,
			)

			append(&result, image)
		}
	}

	return result, true
}
