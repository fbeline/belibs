package atlas

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

    skyline := skyline_packer_init(1024, 512)
    skyline_pack_images_sorted(&skyline, &images)
    write_atlas(images, skyline)

    skyline_packer_destroy(&skyline)
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

write_atlas :: proc(images: [dynamic]Image, packer: Skyline_Packer) -> bool {
    // Compute atlas dimensions
    atlas_width  := skyline_get_used_width(packer)
    atlas_height := skyline_get_used_height(packer)
    
    // Allocate flat pixel buffer: width * height * channels
    pixel_count := atlas_width * atlas_height * 4
    buffer := make([dynamic]u8, pixel_count)
    defer delete(buffer)
    
    // Initialize buffer to transparent black
    for i in 0..<pixel_count {
        buffer[i] = 0
    }
    
    // Copy each image’s data into the buffer at its (x,y) position
    for img in images {
    	src_stride := img.width * img.channels
    	dst_stride := atlas_width * 4

        for row in 0..<img.height {
        	for col in 0..<img.width {
        		src_index := row * src_stride + col * img.channels
                dst_index := (img.y + row) * dst_stride + (img.x + col) * 4

                buffer[dst_index] = img.data[src_index]
                buffer[dst_index + 1] = img.data[src_index + 1]
                buffer[dst_index + 2] = img.data[src_index + 2]
                buffer[dst_index + 3] = img.data[src_index + 3]
        	}
        }
    }
    
    stbi.write_png("atlas.png", atlas_width, atlas_height, 4, raw_data(buffer), atlas_width * 4)

    return true
}
