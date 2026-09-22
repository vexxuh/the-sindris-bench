package engine

// Histogram diff: like patience, but the anchor doesn't need to be unique on
// both sides, just low-occurrence. For every token shared between the two
// ranges we extend the match as far as it will go in both directions, and
// keep the longest run, preferring the one anchored on the rarer token when
// two runs tie in length. Tokens that occur more than HISTOGRAM_MAX_CHAIN
// times in the `a` range are treated as noise and ignored as anchors, same
// as git's implementation does, to keep this from going quadratic on
// degenerate input (e.g. a file of blank lines).
//
// Falls back to Myers for any gap with no viable anchor.

HISTOGRAM_MAX_CHAIN :: 64

histogram :: proc(a, b: []u32, allocator := context.allocator) -> (ops: []Op, err: Error) {
	n, m := len(a), len(b)
	if n == 0 && m == 0 {
		return nil, .None
	}

	builder: Op_Builder
	builder_init(&builder, n + m, allocator)

	histogram_recurse(&builder, a, b, 0, n, 0, m, allocator)

	return builder_finish(&builder), .None
}

@(private)
Histogram_Anchor :: struct {
	a_start, b_start, length: int,
}

@(private)
histogram_recurse :: proc(builder: ^Op_Builder, a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) {
	if al == ah && bl == bh {
		return
	}
	if al == ah {
		builder_insert(builder, al, bl, bh - bl)
		return
	}
	if bl == bh {
		builder_delete(builder, al, bl, ah - al)
		return
	}

	anchor, found := histogram_find_anchor(a, b, al, ah, bl, bh, allocator)

	if !found {
		histogram_fallback(builder, a, b, al, ah, bl, bh, allocator)
		return
	}

	histogram_recurse(builder, a, b, al, anchor.a_start, bl, anchor.b_start, allocator)
	builder_equal(builder, anchor.a_start, anchor.b_start, anchor.length)
	histogram_recurse(builder, a, b, anchor.a_start + anchor.length, ah, anchor.b_start + anchor.length, bh, allocator)
}

@(private)
histogram_fallback :: proc(builder: ^Op_Builder, a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) {
	sub_ops, err := myers(a[al:ah], b[bl:bh], allocator)
	defer delete(sub_ops, allocator)

	if err != .None {
		builder_delete(builder, al, bl, ah - al)
		builder_insert(builder, al, bl, bh - bl)
		return
	}

	ops_offset(sub_ops, al, bl)
	for op in sub_ops {
		builder_push(builder, op)
	}
}

@(private)
histogram_find_anchor :: proc(a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) -> (anchor: Histogram_Anchor, found: bool) {
	counts := make(map[u32]int, allocator)
	defer delete(counts)

	positions := make(map[u32][dynamic]int, allocator)
	defer {
		for _, list in positions {
			l := list
			delete(l)
		}
		delete(positions)
	}

	for i in al ..< ah {
		token := a[i]
		counts[token] = counts[token] + 1
		if counts[token] > HISTOGRAM_MAX_CHAIN {
			continue
		}
		list := positions[token]
		append(&list, i)
		positions[token] = list
	}

	best_length := 0
	best_count := 0

	for bi in bl ..< bh {
		token := b[bi]
		count := counts[token]
		if count == 0 || count > HISTOGRAM_MAX_CHAIN {
			continue
		}

		list := positions[token]
		for ai in list {
			start_a, start_b := ai, bi
			for start_a > al && start_b > bl && a[start_a - 1] == b[start_b - 1] {
				start_a -= 1
				start_b -= 1
			}
			end_a, end_b := ai, bi
			for end_a + 1 < ah && end_b + 1 < bh && a[end_a + 1] == b[end_b + 1] {
				end_a += 1
				end_b += 1
			}

			length := end_a - start_a + 1
			better := length > best_length || (length == best_length && count < best_count)
			if better {
				best_length = length
				best_count = count
				anchor = Histogram_Anchor{a_start = start_a, b_start = start_b, length = length}
			}
		}
	}

	return anchor, best_length > 0
}
