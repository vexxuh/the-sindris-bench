package engine

// Reference O(n*m) time and space dynamic-programming LCS diff.
//
// This exists purely so the fast algorithms (Myers, Patience, Histogram) have
// something to be checked against in tests. It is deliberately not tuned and
// must never be reached for by the CLI or any real workload.

// we will refuse to allocate a table larger than this. In total this is about 16 million cells of u32 which is about 64MB of memory.
// which is well past the recommended usage of using Myers
LCS_DP_MAX_CELLS :: 16 * 1024 * 1024

lcs_dp :: proc(a, b: []u32, allocator := context.allocator) -> (ops: []Op, err: Error) {
	n, m := len(a), len(b)

	// simply don't handle cases where both are empty
	if n == 0 && m == 0 {
		return nil, .None
	}

	cells := (n + 1) * (m + 1)
	if cells > LCS_DP_MAX_CELLS {
		return nil, .Too_Large
	}

	// dp[i * (m + 1) + j] == length of the LCS of a[:i] and b[:j]
	stride := m + 1
	dp := make([]u32, cells, allocator)
	defer delete(dp, allocator)

	for i in 1 ..= n {
		row := i * stride
		prev_row := (i - 1) * stride
		for j in 1 ..= m {
			if a[i - 1] == b[j - 1] {
				dp[row + j] = dp[prev_row + (j - 1)] + 1
			} else {
				dp[row + j] = max(dp[prev_row + j], dp[row + (j - 1)])
			}
		}
	}

	builder: Op_Builder
	builder_init(&builder, n + m, allocator)

	// walk the table backwards from (n, m) to (0, 0), then push moves onto
	// the builder in forward order via #reverse.
	Move :: struct {
		kind:              Op_Kind,
		old_pos, new_pos:  int,
	}

	moves := make([dynamic]Move, 0, n + m, allocator)
	defer delete(moves)

	i, j := n, m
	for i > 0 || j > 0 {
		row := i * stride
		prev_row := (i - 1) * stride

		switch {
		case i > 0 && j > 0 && a[i - 1] == b[j - 1] && dp[row + j] == dp[prev_row + (j - 1)] + 1:
			i -= 1
			j -= 1
			append(&moves, Move{kind = .Equal, old_pos = i, new_pos = j})
		case j > 0 && (i == 0 || dp[row + (j - 1)] >= dp[prev_row + j]):
			j -= 1
			append(&moves, Move{kind = .Insert, old_pos = i, new_pos = j})
		case:
			i -= 1
			append(&moves, Move{kind = .Delete, old_pos = i, new_pos = j})
		}
	}

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
