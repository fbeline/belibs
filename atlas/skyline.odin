package atlas

import "core:fmt"
import "core:slice"

// Skyline point represents a vertex on the skyline
Skyline_Point :: struct {
	x: i32,
	y: i32,
}

// Packer state for skyline algorithm
Skyline_Packer :: struct {
	width:       i32, // Atlas/container width
	height:      i32, // Atlas/container height
	skyline:     [dynamic]Skyline_Point,
	initialized: bool,
	auto_resize: bool,
}

// Initialize a skyline packer with the given initial atlas dimensions
skyline_packer_init :: proc(
	initial_width, initial_height: i32,
) -> Skyline_Packer {
	packer := Skyline_Packer {
		width       = initial_width,
		height      = initial_height,
		auto_resize = true,
	}

	// Initialize skyline with bottom-left corner
	append(&packer.skyline, Skyline_Point{x = 0, y = 0})
	packer.initialized = true

	return packer
}

// Destroy the packer and free resources
skyline_packer_destroy :: proc(packer: ^Skyline_Packer) {
	delete(packer.skyline)
}

// Pack a single image into the atlas with auto-resize
// Returns true if successful, false if image is too large even after resizing
skyline_pack_image :: proc(packer: ^Skyline_Packer, image: ^Image) -> bool {
	// Early exit for invalid dimensions
	if image.width <= 0 || image.height <= 0 {
		return false
	}

	// Try to pack with current atlas size
	best_idx, best_idx2, best_x, best_y, found := find_best_position(
		packer,
		image.width,
		image.height,
	)

	// If not found and auto-resize is enabled, try to grow the atlas
	if !found && packer.auto_resize {
		if try_resize_atlas(packer, image.width, image.height) {
			// Try again with the new size
			best_idx, best_idx2, best_x, best_y, found = find_best_position(
				packer,
				image.width,
				image.height,
			)
		}
	}

	if !found {
		return false
	}

	// Update the image position
	image.x = best_x
	image.y = best_y

	// Update the skyline
	update_skyline(packer, best_idx, best_idx2, best_x, best_y, image.width, image.height)

	return true
}

// Try to resize the atlas to accommodate the given rectangle
// Returns true if resize was successful
try_resize_atlas :: proc(packer: ^Skyline_Packer, needed_width, needed_height: i32) -> bool {
	original_width := packer.width
	original_height := packer.height

	// Calculate new dimensions
	new_width := packer.width
	new_height := packer.height

	// Get current maximum y from skyline
	current_max_y := skyline_get_used_height(packer^)

	// Determine which dimension to grow
	// Strategy: prefer growing width first, then height
	// This creates more horizontal space which often packs better

	should_grow_width := false
	should_grow_height := false

	// Check if we need more width
	if needed_width > packer.width {
		should_grow_width = true
	}

	// Check if we need more height
	if needed_height > packer.height || current_max_y + needed_height > packer.height {
		should_grow_height = true
	}

	// If we don't strictly need to grow, try anyway to create more space
	if !should_grow_width && !should_grow_height {
		// Prefer width growth for better packing
		should_grow_width = true
	}

	// Double the width if needed
	if should_grow_width {
		new_width = packer.width * 2
	}

	// Double the height if needed
	if should_grow_height {
		new_height = packer.height * 2
	}

	// Check if we actually changed anything
	if new_width == original_width && new_height == original_height {
		// Already at maximum size
		return false
	}

	// Apply the new dimensions
	packer.width = new_width
	packer.height = new_height

	return true
}

// Find the best position (lowest, then leftmost) for a rectangle
find_best_position :: proc(
	packer: ^Skyline_Packer,
	width, height: i32,
) -> (
	best_idx, best_idx2: int,
	best_x, best_y: i32,
	found: bool,
) {
	best_idx = -1
	best_idx2 = -1
	best_x = max(i32)
	best_y = max(i32)

	skyline_count := len(packer.skyline)

	// Search for the best candidate location
	for idx in 0 ..< skyline_count {
		x := packer.skyline[idx].x
		y := packer.skyline[idx].y

		// Check if rectangle would exceed right boundary
		if x + width > packer.width {
			break
		}

		// Skip if this position can't beat current best
		if y >= best_y {
			continue
		}

		// Find overlapping skyline points and raise y to avoid collisions
		x_max := x + width
		idx2 := idx + 1

		for idx2 < skyline_count {
			if x_max <= packer.skyline[idx2].x {
				break
			}

			// Raise y to avoid intersection with this skyline point
			if y < packer.skyline[idx2].y {
				y = packer.skyline[idx2].y
			}

			idx2 += 1
		}

		// Check if this position is valid
		if y >= best_y {
			continue
		}

		// Check if rectangle would exceed top boundary
		if y + height > packer.height {
			continue
		}

		// This is the new best position
		best_idx = idx
		best_idx2 = idx2
		best_x = x
		best_y = y
	}

	found = best_idx >= 0
	return
}

// Update the skyline after placing a rectangle
update_skyline :: proc(
	packer: ^Skyline_Packer,
	idx_best, idx_best2: int,
	x, y, width, height: i32,
) {
	assert(idx_best >= 0 && idx_best < len(packer.skyline))
	assert(idx_best2 > idx_best && idx_best2 <= len(packer.skyline))

	// Calculate new skyline points
	new_tl := Skyline_Point {
		x = x,
		y = y + height,
	} // Top-left
	new_br := Skyline_Point {
		x = x + width,
		y = packer.skyline[idx_best2 - 1].y,
	} // Bottom-right

	// Determine if we need to add the bottom-right point
	add_br := false
	if idx_best2 < len(packer.skyline) {
		add_br = new_br.x < packer.skyline[idx_best2].x
	} else {
		add_br = new_br.x < packer.width
	}

	removed_count := idx_best2 - idx_best
	inserted_count := add_br ? 2 : 1

	// Modify the skyline array
	if inserted_count > removed_count {
		// Expand: need to insert more points than we remove
		expand_count := inserted_count - removed_count

		// Make room by inserting dummy points
		for i in 0 ..< expand_count {
			inject_at(&packer.skyline, idx_best2, Skyline_Point{})
		}

	} else if inserted_count < removed_count {
		// Shrink: need to remove more points than we insert
		shrink_count := removed_count - inserted_count

		// Remove points by shifting left
		for i in 0 ..< shrink_count {
			ordered_remove(&packer.skyline, idx_best + inserted_count)
		}
	}

	// Insert the new points
	packer.skyline[idx_best] = new_tl
	if add_br {
		packer.skyline[idx_best + 1] = new_br
	}
}

// Pack multiple images into an atlas (receives pointer to dynamic array)
// Returns the number of successfully packed images
skyline_pack_images :: proc(packer: ^Skyline_Packer, images: ^[dynamic]Image) -> int {
	packed_count := 0

	for &image in images {
		if skyline_pack_image(packer, &image) {
			packed_count += 1
		} else {
			fmt.printf("Failed to pack image: %s (%dx%d)\n", image.name, image.width, image.height)
		}
	}

	return packed_count
}

// Pack images with optional sorting for better packing efficiency
skyline_pack_images_sorted :: proc(packer: ^Skyline_Packer, images: ^[dynamic]Image) -> int {
	slice.sort_by(images[:], proc(a, b: Image) -> bool {
		if a.height != b.height {
			return a.height > b.height
		}
		return a.width > b.width
	})

	return skyline_pack_images(packer, images)
}

// Get the actual used height of the atlas
skyline_get_used_height :: proc(packer: Skyline_Packer) -> i32 {
	max_height: i32 = 0

	for point in packer.skyline {
		if point.y > max_height {
			max_height = point.y
		}
	}

	return max_height
}

// Get the actual used width of the atlas
skyline_get_used_width :: proc(packer: Skyline_Packer) -> i32 {
	max_width: i32 = 0

	for point in packer.skyline {
		if point.x > max_width {
			max_width = point.x
		}
	}

	return max_width
}

// Enable or disable auto-resize
skyline_set_auto_resize :: proc(packer: ^Skyline_Packer, enabled: bool) {
	packer.auto_resize = enabled
}
