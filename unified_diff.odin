package main

import "core:fmt"
import "diff/engine"

// Number of unchanged lines shown around each change, same default as `diff -u`.
CONTEXT_LINES :: 3

Hunk_Line_Kind :: enum u8 {
	Context,
	Delete,
	Insert,
}

Hunk_Line :: struct {
	kind: Hunk_Line_Kind,
	text: string,
}

Hunk :: struct {
	old_start, old_count: int,
	new_start, new_count: int,
	lines:                [dynamic]Hunk_Line,
}

hunks_destroy :: proc(hunks: []Hunk) {
	for hunk in hunks {
		delete(hunk.lines)
	}
}

// Groups a canonical op list into unified-diff hunks: each change gets up to
// `context_lines` of surrounding context, and hunks whose context would
// overlap (gap between changes <= 2 * context_lines) are merged into one.
//
// `lines` is the shared intern table; old_tokens[i] / new_tokens[j] are ids
// into it.
build_hunks :: proc(
	ops: []engine.Op,
	old_tokens, new_tokens: []u32,
	lines: []string,
	context_lines := CONTEXT_LINES,
	allocator := context.allocator,
) -> [dynamic]Hunk {
	hunks := make([dynamic]Hunk, 0, 4, allocator)

	old_line :: proc(old_tokens: []u32, lines: []string, pos: int) -> string {
		return lines[old_tokens[pos]]
	}
	new_line :: proc(new_tokens: []u32, lines: []string, pos: int) -> string {
		return lines[new_tokens[pos]]
	}

	i := 0
	for i < len(ops) {
		if ops[i].kind == .Equal {
			i += 1
			continue
		}

		hunk: Hunk
		hunk.lines = make([dynamic]Hunk_Line, 0, 16, allocator)

		// leading context borrowed from the tail of the previous equal run
		if i > 0 && ops[i - 1].kind == .Equal {
			prev := ops[i - 1]
			take := min(context_lines, prev.old_len)
			skip := prev.old_len - take

			hunk.old_start = prev.old_start + skip
			hunk.new_start = prev.new_start + skip

			for k in 0 ..< take {
				append(&hunk.lines, Hunk_Line{kind = .Context, text = old_line(old_tokens, lines, prev.old_start + skip + k)})
			}
			hunk.old_count += take
			hunk.new_count += take
		} else {
			hunk.old_start = ops[i].old_start
			hunk.new_start = ops[i].new_start
		}

		// consume every change op that belongs to this hunk, folding in any
		// equal run short enough to just be connective context
		for i < len(ops) {
			op := ops[i]

			if op.kind == .Equal {
				more_changes_follow := i + 1 < len(ops)
				if !more_changes_follow || op.old_len > 2 * context_lines {
					break
				}

				for k in 0 ..< op.old_len {
					append(&hunk.lines, Hunk_Line{kind = .Context, text = old_line(old_tokens, lines, op.old_start + k)})
				}
				hunk.old_count += op.old_len
				hunk.new_count += op.old_len
				i += 1
				continue
			}

			switch op.kind {
			case .Delete:
				for k in 0 ..< op.old_len {
					append(&hunk.lines, Hunk_Line{kind = .Delete, text = old_line(old_tokens, lines, op.old_start + k)})
				}
				hunk.old_count += op.old_len
			case .Insert:
				for k in 0 ..< op.new_len {
					append(&hunk.lines, Hunk_Line{kind = .Insert, text = new_line(new_tokens, lines, op.new_start + k)})
				}
				hunk.new_count += op.new_len
			case .Equal:
			// unreachable; handled above
			}
			i += 1
		}

		// trailing context from the head of whatever equal run we stopped at
		if i < len(ops) && ops[i].kind == .Equal {
			trailing := ops[i]
			take := min(context_lines, trailing.old_len)

			for k in 0 ..< take {
				append(&hunk.lines, Hunk_Line{kind = .Context, text = old_line(old_tokens, lines, trailing.old_start + k)})
			}
			hunk.old_count += take
			hunk.new_count += take
		}

		append(&hunks, hunk)
	}

	return hunks
}

print_unified_diff :: proc(old_path, new_path: string, ops: []engine.Op, old_tokens, new_tokens: []u32, lines: []string, allocator := context.allocator) {
	hunks := build_hunks(ops, old_tokens, new_tokens, lines, CONTEXT_LINES, allocator)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	if len(hunks) == 0 {
		return
	}

	fmt.printf("--- %s\n", old_path)
	fmt.printf("+++ %s\n", new_path)

	for hunk in hunks {
		print_hunk(hunk)
	}
}

print_hunk :: proc(hunk: Hunk) {
	// GNU diff quirk: a zero-length side reports the 0-based position as-is
	// (i.e. "the line after which this happens"), a non-empty side reports
	// the usual 1-based line number.
	old_display := hunk.old_start + 1 if hunk.old_count > 0 else hunk.old_start
	new_display := hunk.new_start + 1 if hunk.new_count > 0 else hunk.new_start

	fmt.print("@@ -")
	if hunk.old_count == 1 {
		fmt.printf("%d", old_display)
	} else {
		fmt.printf("%d,%d", old_display, hunk.old_count)
	}

	fmt.print(" +")
	if hunk.new_count == 1 {
		fmt.printf("%d", new_display)
	} else {
		fmt.printf("%d,%d", new_display, hunk.new_count)
	}
	fmt.print(" @@\n")

	for line in hunk.lines {
		switch line.kind {
		case .Context:
			fmt.printf(" %s\n", line.text)
		case .Delete:
			fmt.printf("-%s\n", line.text)
		case .Insert:
			fmt.printf("+%s\n", line.text)
		}
	}
}
