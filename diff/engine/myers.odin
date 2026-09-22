package engine

// Myers' O(ND) shortest-edit-script algorithm. This is the default algorithm.
//
// The forward pass finds the shortest edit distance D by tracing furthest
// reaching diagonals in the edit graph, snapshotting the "V" array at the
// start of every round so the backward pass can recover the actual path.
//
// Reference: E. Myers, "An O(ND) Difference Algorithm and Its Variations" (1986).

myers :: proc(a, b: []u32, allocator := context.allocator) -> (ops: []Op, err: Error) {
	n, m := len(a), len(b)

	if n == 0 && m == 0 {
		return nil, .None
	}

	max := n + m
	width := 2 * max + 1

	v := make([]int, width, allocator)
	defer delete(v, allocator)

	trace := make([dynamic][]int, 0, max + 1, allocator)
	defer {
		for row in trace {
			delete(row, allocator)
		}
		delete(trace)
	}

	final_d := -1

	trace_loop: for d in 0 ..= max {
		snapshot := make([]int, width, allocator)
		copy(snapshot, v)
		append(&trace, snapshot)

		for k := -d; k <= d; k += 2 {
			x: int
			if k == -d || (k != d && v[k - 1 + max] < v[k + 1 + max]) {
				x = v[k + 1 + max]
			} else {
				x = v[k - 1 + max] + 1
			}
			y := x - k

			for x < n && y < m && a[x] == b[y] {
				x += 1
				y += 1
			}

			v[k + max] = x

			if x >= n && y >= m {
				final_d = d
				break trace_loop
			}
		}
	}

	if final_d < 0 {
		// Unreachable: max = n + m is always a large enough bound for the
		// edit distance between two sequences of those lengths.
		return nil, .Invalid_Ops
	}

	Move :: struct {
		kind:             Op_Kind,
		old_pos, new_pos: int,
	}

	moves := make([dynamic]Move, 0, final_d + max, allocator)
	defer delete(moves)

	x, y := n, m
	for d := final_d; d >= 0; d -= 1 {
		row := trace[d]
		k := x - y

		prev_k: int
		if k == -d || (k != d && row[k - 1 + max] < row[k + 1 + max]) {
			prev_k = k + 1
		} else {
			prev_k = k - 1
		}

		prev_x := row[prev_k + max]
		prev_y := prev_x - prev_k

		for x > prev_x && y > prev_y {
			x -= 1
			y -= 1
			append(&moves, Move{kind = .Equal, old_pos = x, new_pos = y})
		}

		if d > 0 {
			if x == prev_x {
				y -= 1
				append(&moves, Move{kind = .Insert, old_pos = x, new_pos = y})
			} else {
				x -= 1
				append(&moves, Move{kind = .Delete, old_pos = x, new_pos = y})
			}
		}

		x, y = prev_x, prev_y
	}

	builder: Op_Builder
	builder_init(&builder, len(moves), allocator)

	#reverse for move in moves {
		switch move.kind {
		case .Equal:
			builder_equal(&builder, move.old_pos, move.new_pos, 1)
		case .Delete:
			builder_delete(&builder, move.old_pos, move.new_pos, 1)
		case .Insert:
			builder_insert(&builder, move.old_pos, move.new_pos, 1)
		}
	}

	return builder_finish(&builder), .None
}
