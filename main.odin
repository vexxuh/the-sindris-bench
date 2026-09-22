package main

import "core:fmt"
import "core:os"
import "core:strings"
import "diff/engine"

usage :: proc(prog: string) {
	fmt.eprintfln("usage: %s <old-file> <new-file> [--algorithm=myers|patience|histogram]", prog)
	fmt.eprintfln("       %s --pretty <file.json> [--indent=N]", prog)
	fmt.eprintfln("       %s --passphrase [--words=N] [--separator=SEP] [--capitalize]", prog)
}

parse_algorithm :: proc(flag: string) -> (algorithm: engine.Algorithm, ok: bool) {
	switch flag {
	case "myers":
		return .Myers, true
	case "patience":
		return .Patience, true
	case "histogram":
		return .Histogram, true
	}
	return .Myers, false
}

main :: proc() {
	args := os.args
	prog := args[0] if len(args) > 0 else "diff"

	for arg in args[1:] {
		if arg == "--pretty" {
			run_pretty(prog, args[1:])
			return
		}
		if arg == "--passphrase" {
			run_passphrase(prog, args[1:])
			return
		}
	}

	run_diff(prog, args[1:])
}

run_diff :: proc(prog: string, args: []string) {
	old_path, new_path: string
	algorithm := engine.Algorithm.Myers

	positional := 0
	for arg in args {
		if strings.has_prefix(arg, "--algorithm=") {
			flag := arg[len("--algorithm="):]
			parsed, ok := parse_algorithm(flag)
			if !ok {
				fmt.eprintfln("error: unknown algorithm %q (expected myers, patience, or histogram)", flag)
				os.exit(2)
			}
			algorithm = parsed
			continue
		}

		switch positional {
		case 0:
			old_path = arg
		case 1:
			new_path = arg
		case:
			usage(prog)
			os.exit(2)
		}
		positional += 1
	}

	if positional != 2 {
		usage(prog)
		os.exit(2)
	}

	old_bytes, old_err := os.read_entire_file(old_path, context.allocator)
	if old_err != nil {
		fmt.eprintfln("error: could not read %q: %v", old_path, old_err)
		os.exit(1)
	}
	defer delete(old_bytes)

	new_bytes, new_err := os.read_entire_file(new_path, context.allocator)
	if new_err != nil {
		fmt.eprintfln("error: could not read %q: %v", new_path, new_err)
		os.exit(1)
	}
	defer delete(new_bytes)

	table := line_table_init()
	defer line_table_destroy(&table)

	old_tokens := tokenize_lines(&table, string(old_bytes))
	defer delete(old_tokens)
	new_tokens := tokenize_lines(&table, string(new_bytes))
	defer delete(new_tokens)

	ops, err := engine.diff(old_tokens, new_tokens, algorithm)
	if err != .None {
		fmt.eprintfln("error: diff failed: %v", err)
		os.exit(1)
	}
	defer delete(ops)

	print_unified_diff(old_path, new_path, ops, old_tokens, new_tokens, table.lines[:])

	// Mimic `diff`'s exit status: 0 when identical, 1 when they differ.
	if !engine.ops_identical(ops) {
		os.exit(1)
	}
}
