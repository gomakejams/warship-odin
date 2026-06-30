// v0.0.1
package gluelib

import "back"
import "base:runtime"
import "core:sys/windows"
import pc "printcolor"

crash_handler_type :: enum {
	MINIDUMP,
	CUSTOMTEST,
	BACKTRACE,
}

set_crash_handler :: proc(handler: crash_handler_type ) { // , set_assertion_handler : bool = false
	switch handler {
		case .MINIDUMP:
			windows.SetUnhandledExceptionFilter(exception_handler_minidump)
		case .CUSTOMTEST:
			windows.SetUnhandledExceptionFilter(exception_handler_custom)
		case .BACKTRACE:
			back.register_segfault_handler()
	}
	// if set_assertion_handler {
	// 	context.assertion_failure_proc = back.assertion_failure_proc
	// }
}

// custom minimal crash handler to test
exception_handler_custom :: proc "stdcall" (e: ^windows.EXCEPTION_POINTERS) -> windows.LONG {
	context = runtime.default_context()
	pc.printc_info("CODE:", e.ExceptionRecord.ExceptionCode)
	pc.printc_error("CONTEXT:", e.ContextRecord)
	return windows.EXCEPTION_EXECUTE_HANDLER
}

// crash handler to generate a windbg .dmp file
exception_handler_minidump :: proc "system" (pException: ^windows.EXCEPTION_POINTERS,) -> windows.LONG {
	context = runtime.default_context()
	context.allocator = context.temp_allocator
	defer free_all()
	pc.printc_error("crash detected, pep: %v\n", pException)
	hDumpFile: windows.HANDLE = windows.CreateFileW(
		windows.L("dumpfile.dmp"),
		windows.GENERIC_WRITE,
		0,
		nil,
		windows.CREATE_ALWAYS,
		windows.FILE_ATTRIBUTE_NORMAL,
		nil,
	)
	if hDumpFile == windows.INVALID_HANDLE_VALUE {
		pc.printc_error("failed to create dump file")
		return windows.EXCEPTION_EXECUTE_HANDLER
	}
	defer {
		pc.printc_info("closing dump file ...\n")
		windows.CloseHandle(hDumpFile)
	}
	pc.printc_info("opened dumpfile, handle: %v\n", hDumpFile)
	mdei: windows.MINIDUMP_EXCEPTION_INFORMATION
	mdei.ThreadId = windows.GetCurrentThreadId()
	mdei.ExceptionPointers = pException // pass in 'nil' would make MiniDumpWriteDump() return TRUE
	mdei.ClientPointers = windows.FALSE
	process_handle := windows.GetCurrentProcess()
	process_id := windows.GetCurrentProcessId()
	pc.printc_info(
		"writing dumpfile\n\tprocess_handle: %v\n\tprocess_id: %v\n\tmdei: %v ...\n",
		process_handle,
		process_id,
		mdei,
	)
	succ := windows.MiniDumpWriteDump(
		process_handle,
		process_id,
		hDumpFile,
		.Normal | .WithDataSegs | .WithFullMemoryInfo | .WithIndirectlyReferencedMemory,
		ExceptionParam = &mdei,
		UserStreamParam = nil,
		CallbackPara = nil,
	)
	pc.printc_info("MiniDumpWriteDump() result: %v\n", succ)
	if !succ {
		code := windows.GetLastError()
		pc.printc_error("MiniDumpWriteDump() error code: %v\n", code)
		message_buf: []u16 = make([]u16, 1024)
		defer delete(message_buf)
		windows.FormatMessageW(
			windows.FORMAT_MESSAGE_FROM_SYSTEM | windows.FORMAT_MESSAGE_IGNORE_INSERTS,
			nil,
			code,
			windows.MAKELANGID(0x09, 0x01), // English
			raw_data(message_buf),
			1024,
			nil,
		)
		message_u8, err := windows.utf16_to_utf8(message_buf)
		if err != nil {
			pc.printc_error("error converting utf-16 to utf-8: %v", err)
		} else {
			pc.printc_error("error message: %v\n", message_u8)
		}
	}
	return windows.EXCEPTION_EXECUTE_HANDLER
}

// see https://github.com/laytan/back to use without crash
// print :: proc(bt: back.Trace) {
// 	lines, err := back.lines(bt)
// 	if err != nil {
// 		pc.printc_error("Could not retrieve backtrace lines: %v\n", err)
// 	} else {
// 		defer back.lines_destroy(lines)
// 		pc.printc_info("[ --------------------- back trace ---------------------]")
// 		back.print(lines)
// 	}
// }
