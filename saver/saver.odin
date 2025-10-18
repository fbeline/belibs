package saver

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:encoding/json"
import "core:mem"

get_full_path :: proc(app_name: string, allocator: mem.Allocator) -> string {
    when ODIN_OS == .Windows {
        base_path := os.get_env("APPDATA");
    }
    when ODIN_OS == .Linux {
        base_path := filepath.join([]string { os.get_env("HOME"), ".config"} );
    }
    when ODIN_OS == .Darwin {
        base_path := filepath.join([]string { os.get_env("HOME"), "Library", "Application Support" });
    }
    defer delete(base_path)

    full_dir: string = filepath.join([]string { base_path, app_name }, allocator);
    if !(os.exists(full_dir) && os.is_dir(full_dir)) {
        os.make_directory(full_dir);
    }

    return full_dir;
}

Saver :: struct {
    app_name: string,
    base_path: string,
    allocator: mem.Allocator,
}

init :: proc(name: string, allocator := context.allocator) -> Saver {
    saver: Saver;
    saver.app_name = name;
    saver.base_path = get_full_path(name, allocator);
    saver.allocator = allocator;

    return saver;
}

store :: proc(saver: Saver, file_name: string, data: $T) -> bool {
    defer free_all(context.temp_allocator)

    full_path, path_err := filepath.join(
        []string{saver.base_path, file_name},
        context.temp_allocator,
    )
    if path_err != nil { return false }

    parent_dir := filepath.dir(full_path, context.temp_allocator)
    if len(parent_dir) > 0 && !os.is_dir(parent_dir) {
        return false
    }

    json_options := json.Marshal_Options{ pretty = false, use_spaces = false, }
    json_bytes, marshal_err := json.marshal(data, json_options, context.temp_allocator)
    if marshal_err != nil { return false }

    write_ok := os.write_entire_file(full_path, json_bytes)
    if !write_ok { return false }


    return true
}

load :: proc(saver: Saver, file_name: string, data: ^$T) -> bool {
    defer free_all(context.temp_allocator)

    full_path := filepath.join([]string{saver.base_path, file_name}, context.temp_allocator)
    if !os.exists(full_path) {
        return false
    }

    file_content, read_ok := os.read_entire_file(full_path, context.temp_allocator)
    if !read_ok {
        return false
    }

    // Create temporary variable to decode into
    temp_data: T

    unmarshal_err := json.unmarshal(file_content, &temp_data, allocator = saver.allocator)
    if unmarshal_err != nil {
        return false
    }

    data^ = temp_data
    return true
}

TestData :: struct {
    counter: int,
    name: string,
    list: []int,
}

main :: proc() {
    saver: Saver = init("MyApp");

    fmt.println("Saver initialized for app: ", saver.base_path);

    data := TestData{ counter = -1, name = "Default", list = []int{} };
    load_ok := load(saver, "test", &data);
    fmt.printf("Default: %v\n", data)

    data = TestData{ counter = 42, name = "Test2", list = []int{1,2,3,4,5} };
    save_ok := store(saver, "test", data);
    fmt.printf("Save successful: %v\n", save_ok);
}

