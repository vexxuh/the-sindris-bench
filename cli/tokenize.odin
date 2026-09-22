package main

import "core:strings"

// Interns lines of text into small u32 ids so the diff engine (which only
// knows about []u32 token streams) can compare them cheaply. The original
// line strings are kept around so the CLI can print them back out.
Line_Table :: struct {
	ids:   map[string]u32,
	lines: [dynamic]string,
}

line_table_init :: proc(allocator := context.allocator) -> Line_Table {
	return Line_Table{
		ids = make(map[string]u32, allocator),
		lines = make([dynamic]string, 0, 64, allocator),
	}
}

line_table_destroy :: proc(table: ^Line_Table) {
	delete(table.ids)
	delete(table.lines)
}

line_table_intern :: proc(table: ^Line_Table, line: string) -> u32 {
	if id, ok := table.ids[line]; ok {
		return id
	}

	id := u32(len(table.lines))
	append(&table.lines, line)
	table.ids[line] = id
	return id
}

// Splits `text` into lines (without the trailing newline) and interns each
// one into `table`, returning the resulting token stream.
tokenize_lines :: proc(table: ^Line_Table, text: string, allocator := context.allocator) -> []u32 {
	if len(text) == 0 {
		return nil
	}

	raw_lines := strings.split_lines(text, allocator)
	defer delete(raw_lines, allocator)

	// `split_lines` on a string ending in "\n" yields a trailing empty
	// string for the phantom line after the last newline; drop it so a
	// file ending in a newline doesn't get reported as having one more
	// (empty) line than it does.
	line_count := len(raw_lines)
	if line_count > 0 && raw_lines[line_count - 1] == "" && strings.has_suffix(text, "\n") {
		line_count -= 1
	}

	tokens := make([]u32, line_count, allocator)
	for i in 0 ..< line_count {
		tokens[i] = line_table_intern(table, raw_lines[i])
	}

	return tokens
}
