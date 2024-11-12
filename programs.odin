package masterclass

import "core:fmt"
import "core:os"
import "core:strings"
import gl "vendor:OpenGL";
import "core:path/filepath";




Raster_Program :: struct {
	handle: u32,

	vertex_filename: string,
	fragment_filename: string,

	vertex_timestamp: os.File_Time,
	fragment_timestamp: os.File_Time,
}

load_raster_program :: proc(vertex_filename, fragment_filename: string) -> (program: Raster_Program) {
    handle, success := gl.load_shaders(vertex_filename, fragment_filename);
    if !success {
        error_message, type := gl.get_last_error_message();
        fmt.printf("Error loading raster shader %q %q: %v %s\n", vertex_filename, fragment_filename, type, error_message);
        return {};
    }
    vertex_timestamp, vertex_err := os.last_write_time_by_name(vertex_filename)
    fragment_timestamp, fragment_err := os.last_write_time_by_name(fragment_filename)

    program.handle = handle
    program.vertex_filename = strings.clone(vertex_filename)
    program.fragment_filename = strings.clone(fragment_filename)
    program.vertex_timestamp = vertex_timestamp
    program.fragment_timestamp = fragment_timestamp
    return
}

refresh_raster_program :: proc(program: ^Raster_Program) {
	current_vertex_timestamp, vertex_err := os.last_write_time_by_name(program.vertex_filename)
	current_fragment_timestamp, fragment_err := os.last_write_time_by_name(program.fragment_filename)

	if current_vertex_timestamp != program.vertex_timestamp || current_fragment_timestamp != program.fragment_timestamp {
    	new_handle, success := gl.load_shaders(program.vertex_filename, program.fragment_filename);
        if success {
            gl.DeleteProgram(program.handle);
            program.handle = new_handle;
            if current_vertex_timestamp != program.vertex_timestamp {
            	fmt.printf("Updated raster program. Vertex shader %q changed.\n", program.vertex_filename);
            } else {
            	fmt.printf("Updated raster program. Fragment shader %q changed.\n", program.fragment_filename);
            }
        } 
        program.vertex_timestamp = current_vertex_timestamp
        program.fragment_timestamp = current_fragment_timestamp
	}
}



Compute_Program :: struct {
	handle: u32,

	filename: string,

	timestamp: os.File_Time,

    local_size: [3]i32,
}

load_compute_program :: proc(filename: string) -> (program: Compute_Program) {
    handle, success := gl.load_compute_file(filename);
    if !success {
        error_message, type := gl.get_last_error_message();
        fmt.printf("Error loading file %q: %v %s\n", filename, type, error_message);
        return {};
    }
    timestamp, err := os.last_write_time_by_name(filename)

    program.handle = handle
    program.filename = strings.clone(filename)
    program.timestamp =  timestamp
    gl.GetProgramiv(handle, gl.COMPUTE_WORK_GROUP_SIZE, &program.local_size[0])
    return
}

refresh_compute_program :: proc(program: ^Compute_Program) {
	current_timestamp, err := os.last_write_time_by_name(program.filename)
	if current_timestamp != program.timestamp {
    	new_handle, success := gl.load_compute_file(program.filename);
        if success {
            gl.DeleteProgram(program.handle);
            program.handle = new_handle;
            fmt.printf("Updated compute program. Compute shader %q changed.\n", program.filename);

            old_local_size := program.local_size
            gl.GetProgramiv(new_handle, gl.COMPUTE_WORK_GROUP_SIZE, &program.local_size[0])
            if old_local_size != program.local_size do fmt.println("    local_size changed from", old_local_size, "to", program.local_size)

        } 
        program.timestamp = current_timestamp
	}
}


load_all_shaders :: proc() -> (raster_programs: map[string]Raster_Program, compute_programs: map[string]Compute_Program) {
	compute_filenames, _ := filepath.glob("shaders/compute_*", context.temp_allocator)
	vertex_filenames, _ := filepath.glob("shaders/vertex_*", context.temp_allocator)
	fragment_filenames, _ := filepath.glob("shaders/fragment_*", context.temp_allocator)

	for filename, i in compute_filenames {
		name := filename[len("shaders/compute_"):len(filename)-len(".glsl")]
		compute_programs[name] = load_compute_program(filename)
		fmt.println(name)
	}

	// NOTE: Assumes there's always a matching fragment and vertex shader, and that there are no non-matching ones of either type
	for filename, i in vertex_filenames {
		name := filename[len("shaders/vertex_"):len(filename)-len(".glsl")]
		raster_programs[name] = load_raster_program(vertex_filenames[i], fragment_filenames[i])
		fmt.println(name)
	}
	return 
}