#+private
//package back
package gluelib_back

@(require) import "base:runtime"
@(require) import "core:fmt"
@(require) import "core:strings"
@(require) import win "core:sys/windows"
@(require) import "vendor/pdb/pdb"

import pc "../printcolor"

when !USE_FALLBACK {

	_Trace_Entry :: pdb.StackFrame

	_trace :: proc(buf: Trace) -> (n: int) {
		return int(pdb.capture_stack_trace(buf))
	}

	_lines_destroy :: proc(msgs: []Line) {
		for msg in msgs {
			delete(msg.location)
			delete(msg.symbol)
		}
		delete(msgs)
	}

	_lines :: proc(bt: Trace) -> (out: []Line, err: Lines_Error) {
		// Debug info is needed, if we call pdb parser with out-of-date debug symbols it might panic to, so better to short-circuit right away.
		when !ODIN_DEBUG {
			return nil, .Info_Not_Found
		}

		runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
			ignore = context.allocator == context.temp_allocator,
		)

		rb: pdb.RingBuffer(runtime.Source_Code_Location)
		pdb.init_rb(&rb, len(bt))
		defer delete(rb.data)

		{
			context.allocator = context.temp_allocator
			if pdb.parse_stack_trace(bt, true, &rb) {
				err = .Info_Not_Found
				return
			}
		}

		out = make([]Line, len(bt))
		for &msg, i in out {
			loc := pdb.get_rb(&rb, i)
			msg.symbol = strings.clone(loc.procedure)

			lb := strings.builder_make_len_cap(0, len(loc.file_path) + 5)
			strings.write_string(&lb, loc.file_path)
			strings.write_byte(&lb, ':')
			strings.write_int(&lb, int(loc.line))
			msg.location = strings.to_string(lb)
		}

		return
	}

	_register_segfault_handler :: proc() {

		pdb.SetUnhandledExceptionFilter(
			proc "stdcall" (exception_info: ^win.EXCEPTION_POINTERS) -> win.LONG {
				context = runtime.default_context()
				context.allocator = context.temp_allocator
				pc.printc_error("Exception ")
				if exception_info.ExceptionRecord != nil {
					pc.printc_warn(
						fmt.aprintf(
							"(Type: %x, Flags: %x)\n",
							exception_info.ExceptionRecord.ExceptionCode,
							exception_info.ExceptionRecord.ExceptionFlags,
						)
					)
				}
				ctxt := cast(^pdb.CONTEXT)exception_info.ContextRecord
				trace_buf: [BACKTRACE_SIZE]pdb.StackFrame
				trace_count := pdb.capture_stack_trace_from_context(ctxt, trace_buf[:])
				src_code_locs: pdb.RingBuffer(runtime.Source_Code_Location)
				pdb.init_rb(&src_code_locs, BACKTRACE_SIZE)

				// si no obtuvimos nada, capturar desde aquí (frames de Odin)
				if trace_count == 0 {
					pc.printc_info(
						fmt.aprintf("capture_stack_trace_from_context() > trace_count : %v calling Odin stack trace...\n",
						trace_count)
					)
					trace_count = pdb.capture_stack_trace(trace_buf[:])
					pc.printc_info(
						fmt.aprintf(
						"capture_stack_trace() > trace_count : %v\n", trace_count
						)
					)
				}

				no_debug_info_found := pdb.parse_stack_trace(
					trace_buf[:trace_count],
					true,
					&src_code_locs,
				)
				if no_debug_info_found {
					pc.printc_error("Could not get backtrace: pdb file not found, compile with `-debug` to generate pdb files and get a back trace.")
					return win.EXCEPTION_CONTINUE_SEARCH
				}

				pc.printc_info("[--------------------- back trace ---------------------]\n")

				lines: [BACKTRACE_SIZE]Line
				for i in 0 ..< src_code_locs.len {
					loc := pdb.get_rb(&src_code_locs, i)

					lb := strings.builder_make_len_cap(0, len(loc.file_path) + 5)
					strings.write_string(&lb, loc.file_path)
					strings.write_byte(&lb, ':')
					strings.write_int(&lb, int(loc.line))

					lines[i] = {
						location = strings.to_string(lb),
						symbol   = loc.procedure,
					}
				}
				print(lines[:src_code_locs.len])

				return win.EXCEPTION_CONTINUE_SEARCH
			},
		)
	}

}
