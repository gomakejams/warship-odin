// v0.0.1
package gluelib_printcolor

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"


ESCANSI :: "\033["
RESET :: ESCANSI + "0m"
ERR_COLOR :: ESCANSI + "40m" + ESCANSI + "31m"
INFO_COLOR :: ESCANSI + "40m" + ESCANSI + "34m"
WARN_COLOR :: ESCANSI + "40m" + ESCANSI + "33m"
NORMAL_COLOR :: ESCANSI + "40m" + ESCANSI + "38m"

//
// Prints to console with colors
// Examples :
// glue.printc("Hola mundo!!",2,"3", color = glue.ERR_COLOR)
// glue.printc("Hola mundo!!",2,"3")
// pc.printc("normal")
// pc.printc_error("error")
// pc.printc_warn("warm")
// pc.printc_info("info")
// pc.printc("normal",color=pc.NORMAL_COLOR)
// pc.printc("error",color=pc.ERR_COLOR)
// pc.printc("warm",color=pc.WARN_COLOR)
// pc.printc("info",color=pc.INFO_COLOR)
//
printc :: proc(args: ..any, color := NORMAL_COLOR, sep := " ", flush := true) -> int {
	buf: [1024]byte
	b: bufio.Writer
	bufio.writer_init_with_buf(&b, os.to_stream(os.stdout), buf[:]) // init buffer
	w := bufio.writer_to_writer(&b) // convert to stream
	fi: fmt.Info // struct for formatted printing
	fi.writer = w // assign stream writter to formatter
	if len(args) > 0 { // write color to stream
		fmt.fmt_value(&fi, color, 'v')
	}
	for _, i in args {
		if i > 0 { 	// skip sep for first item
			io.write_string(fi.writer, sep, &fi.n)
		}
		fmt.fmt_value(&fi, args[i], 'v') // write every arg formatting it
	}
	if len(args) > 0 {fmt.fmt_value(&fi, RESET, 'v')} 	// write ansi reset
	if len(args) > 0 {io.write_byte(fi.writer, '\n', &fi.n)} 	// write line feed
	// flush the stream
	if flush {
		io.flush(w)
	}
	return fi.n
}

printc_error :: proc(args: ..any, sep := " ", flush := true) -> int {
	return _internal_print(args = args, color = ERR_COLOR, sep = sep, flush = flush)
}

printc_warn :: proc(args: ..any, sep := " ", flush := true) -> int {
	return _internal_print (args = args, color = WARN_COLOR, sep = sep, flush = flush)
}


printc_info :: proc(args: ..any, sep := " ", flush := true) -> int {
	return _internal_print(args = args, color = INFO_COLOR, sep = sep, flush = flush)
}


@(private)
_internal_print :: proc(args: ..any, color := NORMAL_COLOR, sep := " ", flush := true) -> int {
	return printc(args = args, color = color, sep = sep, flush = flush)
}
