package engine

Error :: enum u8 {
	None = 0,
	Invalid_Ops,
	Apply_Mismatch,
	Too_Large,
	Out_Of_Memory,
}

// things that can be said about a run of tokens being processed
Op_Kind :: enum u8 {
	Equal = 0,
	Delete = 1,
	Insert = 2,
}

Op :: struct {
	kind: Op_Kind,
	old_start: int,
	old_len: int,
	new_start: int,
	new_len: int,
}

Algorithm :: enum u8 {
	// O(ND) time, O(N) space. This is the default.
	Myers = 0,

	// anchors on tokens unique to both sides, then recurses. This is slower than myers but produces chunks that can read better when code has moved
	Patience,

	// this is just the same patience algorithm but also uses low-occurrence tokens, not just unique ones
	Histogram,

	// O(n*m) time and memory dynamic THIS IS NOT TO BE USED FOR ACTUAL IMPLEMENTATION. This is just for reference when testing speed for testing
	Lcs_Dp,
}

op_equal :: proc "contextless" (old_start, new_start, length: int) -> Op {
	return Op {
		kind = .Equal,
		old_start = old_start,
		old_len = length,
		new_start = new_start,
		new_len = length,
	}
}

op_delete :: proc "contextless" (old_start, length, new_start: int) -> Op {
	return Op {
		kind = .Delete,
		old_start = old_start,
		old_len = length,
		new_start = new_start,
		new_len = 0,
	}
}

op_insert :: proc "contextless" (old_start, length, new_start: int) -> Op {
	return Op {
		kind = .Insert,
		old_start = old_start,
		old_len = 0,
		new_start = new_start,
		new_len = length,
	}
}

op_is_change :: proc "contextless" (op: Op) -> bool {
	return op.kind != .Equal
}

op_output_len :: proc "contextless" (op: Op) -> int {
	return op.old_len if op.kind == .Equal else op.new_len
}



//BUILDER STRUCTURES

Op_Builder :: struct {
	ops: [dynamic]Op,
}

builder_init :: proc(builder: ^Op_Builder, capacity := 64, allocator := context.allocator) {
	builder.ops = make([dynamic]Op, 0, capacity, allocator)
}

builder_destroy :: proc(builder: ^Op_Builder) {
	delete(builder.ops)
	builder.ops = nil
}

builder_reset :: proc(builder: ^Op_Builder) {
	clear(&builder.ops)
}

builder_len :: proc "contextless" (builder: ^Op_Builder) -> int {
	return len(builder.ops)
}

builder_push :: proc(builder: ^Op_Builder, op: Op) {
	if op.old_len == 0 && op.new_len == 0 {
		return
	}

	if len(builder.ops) > 0 {
		previous := &builder.ops[len(builder.ops) - 1]
		is_adjacent := previous.old_start + previous.old_len == op.old_start && previous.new_start + previous.new_len == op.new_start

		if previous.kind == op.kind && is_adjacent {
			previous.old_len += op.old_len
			previous.new_len += op.new_len
			return
		}
	}

	append(&builder.ops, op)
}


builder_equal :: proc(builder: ^Op_Builder, old_start, new_start, length: int) {
	builder_push(builder, op_equal(old_start, new_start, length))
}

builder_delete :: proc(builder: ^Op_Builder, old_start, new_start, length: int) {
	builder_push(builder, op_delete(old_start, length, new_start))
}

builder_insert :: proc(builder: ^Op_Builder, old_start, new_start, length: int) {
	builder_push(builder, op_insert(old_start, length, new_start))
}

builder_finish :: proc(builder: ^Op_Builder) -> []Op {
	return builder.ops[:]
}

// POST-PROCESSING OPERATIONS

// put every adjacent insert then delte pair into the canonical order. This matters because the diff algorithm may emit a different order dpening on which path it takes
ops_offset :: proc(ops: []Op, old_delta, new_delta: int) {
	for &op in ops {
		op.old_start += old_delta
		op.new_start += new_delta
	}
}

ops_canonicalize :: proc(ops: []Op) {
	index := 0
	for index < len(ops) - 1 {
		if ops[index].kind != .Insert || ops[index + 1].kind != .Delete {
			index += 1
			continue
		}

		insert_op := ops[index]
		delete_op := ops[index + 1]

		delete_op.new_start = insert_op.new_start
		insert_op.old_start = delete_op.old_start + delete_op.old_len

		ops[index] = delete_op
		ops[index + 1] = insert_op

		if index > 0 {
			index -= 1
		}
	}
}

Stats :: struct {
	equal_ops: int,
	delete_ops: int,
	insert_ops: int,
	tokens_equal: int,
	tokens_delete: int,
	tokens_added: int,
}

ops_stats :: proc(ops: []Op) -> (stats: Stats) {
	for op in ops {
		switch op.kind {
		case .Equal:
			stats.equal_ops += 1
			stats.tokens_equal += op.old_len
		case .Delete:
			stats.delete_ops += 1
			stats.tokens_delete += op.old_len
		case .Insert:
			stats.insert_ops += 1
			stats.tokens_added += op.new_len
		}
	}
	return
}

ops_identical :: proc(ops: []Op) -> bool {
	for op in ops {
		if op.kind != .Equal {
			return false
		}
	}

	return true
}

ops_validate :: proc(ops: []Op, old_count, new_count: int) -> Error {
	old_cursor, new_cursor := 0, 0

	for op in ops {
		if op.old_len < 0 || op.new_len < 0 {
			return .Invalid_Ops
		}
		if op.old_len == 0 && op.new_len == 0 {
			return .Invalid_Ops
		}

		switch op.kind {
			case .Equal:
				if op.old_len != op.new_len {
					return .Invalid_Ops
				}
		    case .Delete:
				if op.new_len != 0 || op.old_len == 0 {
					return .Invalid_Ops
				}
		    case .Insert:
				if op.old_len != 0 || op.new_len == 0 {
					return .Invalid_Ops
				}
		}

		old_cursor += op.old_len
		new_cursor += op.new_len
	}
	if old_cursor != old_count || new_cursor != new_count {
		return .Invalid_Ops
	}

	return .None
}


ops_apply :: proc(old_tokens, new_tokens: []u32, ops: []Op, allocator := context.allocator) -> (result: []u32, err: Error) {
	if validation := ops_validate(ops, len(old_tokens), len(new_tokens)); validation != .None {
		return nil, validation
	}

	output := make([dynamic]u32, 0, len(new_tokens), allocator)

	for op in ops {
		switch op.kind {
		case .Equal:
			for offset in 0..< op.old_len {
				if old_tokens[op.old_start + offset] != new_tokens[op.new_start + offset] {
					delete(output)
					return nil, .Apply_Mismatch
				}

				append(&output, new_tokens[op.new_start + offset])
			}
		case .Delete:
			// does not help with output in this case
			{}
		case .Insert:
			for offset in 0..< op.new_len {
				append(&output, new_tokens[op.new_start + offset])
			}
		}
	}

	if len(output) != len(new_tokens) {
		delete(output)
		return nil, .Apply_Mismatch
	}

	return output[:], .None
}

ops_round_trip_ok :: proc(old_tokens, new_tokens: []u32, ops: []Op, allocator := context.allocator) -> bool {
	result, err := ops_apply(old_tokens, new_tokens, ops, allocator)
	if err != .None {
		return false
	}
    defer delete(result, allocator)

    if len(result) != len(new_tokens) {
    	return false
    }

    for token, index in result {
    	if token != new_tokens[index] {
    		return false
    	}
    }

    return true
}
