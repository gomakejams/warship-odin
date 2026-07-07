#+feature dynamic-literals
package gluelib_raylibtools

import "base:runtime"
import "core:c"
import "core:fmt"
import rl "vendor:raylib"
//import "vendor:fontstash"

@(private) console_active: bool = true
@(private) console_camera: rl.Camera2D
@(private) CONSOLE_MAX_LINE_COUNT :: 100
@(private) console_num_lines: int
@(private) console_lines: map[int]cstring
@(private) CONSOLE_FONT_SIZE: c.int : 20
@(private) CONSOLE_FONT_DEFAULT_COLOR: rl.Color : {0, 0, 0, 255}
@(private) console_font_color: rl.Color
@(private) console_font_height: int
@(private) console_position : [2]c.int
@(private)
ConsoleLineData :: struct {
	line:  int,
	value: cstring,
}

console_show :: proc() {
	console_active = true
}

console_hide :: proc() {
	console_active = false
}

console_init :: proc(width, height: c.int, position:[2]c.int = {4,4},	max_lines: int = 10, color: rl.Color = CONSOLE_FONT_DEFAULT_COLOR ) {
	// camera
	console_camera.target = rl.Vector2{0,0}
	console_camera.offset = rl.Vector2{0,0}
	console_camera.rotation = 0
	console_camera.zoom = 1
	console_position = position
	console_font_color = color
	console_font_height = 20
	// lines
	assert(CONSOLE_MAX_LINE_COUNT >= max_lines, "console_init: CONSOLE_MAX_LINE_COUNT <= max_lines")
	console_num_lines = max_lines
	err: runtime.Allocator_Error
	console_lines, err = make(map[int]cstring, console_num_lines)
	assert(err == runtime.Allocator_Error.None, "console_init: can't allocate console_lines")
}


console_delete :: proc() {
	// we must free remaining items in the console lines map
	for i := 0; i < console_num_lines; i += 1 {
		delete(console_lines[i])
	}
	delete(console_lines)
}


console_draw :: proc() {
	if !console_active || len(console_lines) <= 0 {
		return
	}
	rl.BeginMode2D(console_camera)
	posY: c.int = console_position.y
	for i := 0; i < console_num_lines; i += 1 {
		if console_lines[i] != "" {
			rl.DrawText(console_lines[i], console_position.x, posY, CONSOLE_FONT_SIZE, console_font_color)
		}
		posY += (c.int)(i + console_font_height)
	}
	rl.EndMode2D()
}

console_setline :: proc {
	console_set_cstring,
	console_set_vector,
	console_set_cint,
	console_set_string,
	console_set_i64,
	console_set_f64,
}

@(private)
console_set_vector :: proc(line: int, value: [2]f32, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %f %f", tag, value.x, value.y)
	console_lines[line] = cvalue
}

@(private)
console_set_cint :: proc(line: int, value: c.int, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %i", tag, value)
	console_lines[line] = cvalue
}

@(private)
console_set_cstring :: proc(line: int, value: cstring, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %s", tag, value)
	console_lines[line] = cvalue
}

@(private)
console_set_string :: proc(line: int, value: string, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %s", tag, value)
	console_lines[line] = cvalue
}


@(private)
console_set_i64 :: proc(line: int, value: i64, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %i", tag, value)
	console_lines[line] = cvalue
}

@(private)
console_set_f64 :: proc(line: int, value: f64, tag: string = "") {
	assert(line < console_num_lines, "console_addline : line > console_num_lines")
	if old, ok := console_lines[line]; ok {
        delete(old)
    }
	cvalue: cstring = fmt.caprintf("%s %f", tag, value)
	console_lines[line] = cvalue
}
