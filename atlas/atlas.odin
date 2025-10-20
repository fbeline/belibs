package atlas

import "core:bytes"
import "core:fmt"
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

	skyline := skyline_packer_init(1024, 1024)
	skyline_pack_images_sorted(&skyline, &images)
	
	width, height := skyline_get_size(skyline)
	write_atlas(images, width, height)
	write_atlas_json(images, width, height)
}

load_images :: proc(dir_path: string) -> (images: [dynamic]Image, ok: bool) {
	dir_handle, open_err := os.open(dir_path)
	if open_err != nil {
		fmt.printf("Error opening directory: %v\n", open_err)
		return nil, false
	}
	defer os.close(dir_handle)

	result := make([dynamic]Image)
	// Read all files in directory
	file_infos, read_err := os.read_dir(dir_handle, -1)
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
			image.name = file_info.name[:len(file_info.name) - 4]

			full_path := filepath.join({dir_path, file_info.name})

			image.data = stbi.load(
				strings.clone_to_cstring(full_path),
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

write_atlas :: proc(images: [dynamic]Image, atlas_width: i32, atlas_height: i32) -> bool {
	// Allocate flat pixel buffer: width * height * channels
	pixel_count := atlas_width * atlas_height * 4
	buffer := make([dynamic]u8, pixel_count)

	// Initialize buffer to transparent black
	for i in 0 ..< pixel_count {
		buffer[i] = 0
	}

	// Copy each image’s data into the buffer at its (x,y) position
	for img in images {
		src_stride := img.width * img.channels
		dst_stride := atlas_width * 4

		for row in 0 ..< img.height {
			for col in 0 ..< img.width {
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
