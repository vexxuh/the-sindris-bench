package engine

// Patience diff: anchor on tokens that occur exactly once on both sides,
// take the longest increasing subsequence of those anchors (so they never
// cross), and recurse on the gaps between them. Falls back to Myers for any
// gap that has no unique anchors of its own (e.g. a block with no unique
// lines at all, or the two inputs share nothing in common).
//
// Reference: Bram Cohen's "patience diff" algorithm.

patience :: proc(a, b: []u32, allocator := context.allocator) -> (ops: []Op, err: Error) {
	n, m := len(a), len(b)
	if n == 0 && m == 0 {
		return nil, .None
	}

	builder: Op_Builder
	builder_init(&builder, n + m, allocator)

	patience_recurse(&builder, a, b, 0, n, 0, m, allocator)

	return builder_finish(&builder), .None
}

@(private)
patience_recurse :: proc(builder: ^Op_Builder, a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) {
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

	anchors, found := patience_find_anchors(a, b, al, ah, bl, bh, allocator)
	defer delete(anchors, allocator)

	if !found {
		patience_fallback(builder, a, b, al, ah, bl, bh, allocator)
		return
	}

	prev_a, prev_b := al, bl
	for anchor in anchors {
		patience_recurse(builder, a, b, prev_a, anchor.a_index, prev_b, anchor.b_index, allocator)
		builder_equal(builder, anchor.a_index, anchor.b_index, 1)
		prev_a = anchor.a_index + 1
		prev_b = anchor.b_index + 1
	}
	patience_recurse(builder, a, b, prev_a, ah, prev_b, bh, allocator)
}

@(private)
patience_fallback :: proc(builder: ^Op_Builder, a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) {
	sub_ops, err := myers(a[al:ah], b[bl:bh], allocator)
	defer delete(sub_ops, allocator)

	if err != .None {
		// Extremely unlikely (myers only fails on an unreachable internal
		// invariant); treat the whole gap as a wholesale replacement.
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
Patience_Anchor :: struct {
	a_index, b_index: int,
}

@(private)
patience_find_anchors :: proc(a, b: []u32, al, ah, bl, bh: int, allocator := context.allocator) -> (anchors: []Patience_Anchor, found: bool) {
	count_a := make(map[u32]int, allocator)
	defer delete(count_a)
	pos_a := make(map[u32]int, allocator)
	defer delete(pos_a)

	for i in al ..< ah {
		token := a[i]
		count_a[token] = count_a[token] + 1
		pos_a[token] = i
	}

	count_b := make(map[u32]int, allocator)
	defer delete(count_b)

	for i in bl ..< bh {
		token := b[i]
		count_b[token] = count_b[token] + 1
	}

	// Scanning b left to right means candidates come out already sorted
	// ascending by b_index.
	candidates := make([dynamic]Patience_Anchor, 0, bh - bl, allocator)
	defer delete(candidates)

	for i in bl ..< bh {
		token := b[i]
		if count_b[token] != 1 || count_a[token] != 1 {
			continue
		}
		ai, ok := pos_a[token]
		if !ok {
			continue
		}
		append(&candidates, Patience_Anchor{a_index = ai, b_index = i})
	}

	if len(candidates) == 0 {
		return nil, false
	}

	// Take the longest increasing subsequence of a_index so the chosen
	// anchors are monotonic in both a and b (i.e. never cross).
	order := patience_lis_by_a_index(candidates[:], allocator)
	defer delete(order, allocator)

	result := make([]Patience_Anchor, len(order), allocator)
	for idx, i in order {
		result[i] = candidates[idx]
	}

	return result, true
}

// Longest increasing subsequence (by a_index) over candidates, O(n log n).
// Returns indices into `candidates`, in ascending order.
@(private)
patience_lis_by_a_index :: proc(candidates: []Patience_Anchor, allocator := context.allocator) -> []int {
	n := len(candidates)

	// tails[k] = index (into candidates) of the smallest possible tail
	// value for an increasing subsequence of length k + 1.
	tails := make([dynamic]int, 0, n, allocator)
	defer delete(tails)

	prev := make([]int, n, allocator)
	defer delete(prev, allocator)

	for i in 0 ..< n {
		prev[i] = -1
	}

	for i in 0 ..< n {
		value := candidates[i].a_index

		lo, hi := 0, len(tails)
		for lo < hi {
			mid := (lo + hi) / 2
			if candidates[tails[mid]].a_index < value {
				lo = mid + 1
			} else {
				hi = mid
			}
		}

		if lo > 0 {
			prev[i] = tails[lo - 1]
		}

		if lo == len(tails) {
			append(&tails, i)
		} else {
			tails[lo] = i
		}
	}

	chain := make([dynamic]int, 0, len(tails), allocator)
	defer delete(chain)

	if len(tails) > 0 {
		k := tails[len(tails) - 1]
		for k != -1 {
			append(&chain, k)
			k = prev[k]
		}
	}

	out := make([]int, len(chain), allocator)
	count := len(chain)
	for i in 0 ..< count {
		out[i] = chain[count - 1 - i]
	}

	return out
}
