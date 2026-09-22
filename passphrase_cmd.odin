package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "password"

passphrase_usage :: proc(prog: string) {
	fmt.eprintfln("usage: %s --passphrase [--words=N] [--separator=SEP] [--capitalize]", prog)
}

run_passphrase :: proc(prog: string, args: []string) {
	options := password.DEFAULT_OPTIONS

	for arg in args {
		switch {
		case arg == "--passphrase":
			continue
		case arg == "--capitalize":
			options.capitalize = true
		case strings.has_prefix(arg, "--words="):
			text := arg[len("--words="):]
			n, ok := strconv.parse_int(text)
			if !ok || n <= 0 {
				fmt.eprintfln("error: invalid --words value %q (expected a positive integer)", text)
				os.exit(2)
			}
			options.word_count = n
		case strings.has_prefix(arg, "--separator="):
			options.separator = arg[len("--separator="):]
		case:
			passphrase_usage(prog)
			os.exit(2)
		}
	}

	phrase, err := password.generate(options)
	if err != .None {
		fmt.eprintfln("error: could not generate passphrase: %v", err)
		os.exit(1)
	}
	defer delete(phrase)

	fmt.println(phrase)
}
