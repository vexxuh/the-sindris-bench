package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "../json"

pretty_usage :: proc(prog: string) {
	fmt.eprintfln("usage: %s --pretty <file.json> [--indent=N]", prog)
}

// Converts a byte offset into `source` to a 1-based (line, column) pair,
// for error messages a human can actually act on.
line_col_at :: proc(source: string, pos: int) -> (line, col: int) {
	line, col = 1, 1
	end := min(pos, len(source))
	for i in 0 ..< end {
		if source[i] == '\n' {
			line += 1
			col = 1
		} else {
			col += 1
		}
	}
	return
}

run_pretty :: proc(prog: string, args: []string) {
	path := ""
	indent := 2

	positional := 0
	for arg in args {
		if arg == "--pretty" {
			continue
		}
		if strings.has_prefix(arg, "--indent=") {
			text := arg[len("--indent="):]
			n, ok := strconv.parse_int(text)
			if !ok || n <= 0 {
				fmt.eprintfln("error: invalid --indent value %q (expected a positive integer)", text)
				os.exit(2)
			}
			indent = n
			continue
		}

		switch positional {
		case 0:
			path = arg
		case:
			pretty_usage(prog)
			os.exit(2)
		}
		positional += 1
	}

	if positional != 1 {
		pretty_usage(prog)
		os.exit(2)
	}

	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("error: could not read %q: %v", path, read_err)
		os.exit(1)
	}
	defer delete(data)

	source := string(data)
	value, parse_err, pos := json.parse(source)
	if parse_err != .None {
		line, col := line_col_at(source, pos)
		fmt.eprintfln("error: invalid JSON in %q at line %d, column %d: %v", path, line, col, parse_err)
		os.exit(1)
	}
	defer json.value_destroy(value)

	output := json.pretty_print(value, json.Pretty_Options{indent_width = indent})
	defer delete(output)

	fmt.println(output)
}
