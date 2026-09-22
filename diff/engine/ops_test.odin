package engine

import "core:testing"

@(test)
test_op_constructors :: proc(t: ^testing.T) {
	e := op_equal(2, 5, 3)
	testing.expect_value(t, e.kind, Op_Kind.Equal)
	testing.expect_value(t, e.old_start, 2)
	testing.expect_value(t, e.old_len, 3)
	testing.expect_value(t, e.new_start, 5)
	testing.expect_value(t, e.new_len, 3)
	testing.expect(t, !op_is_change(e))
	testing.expect_value(t, op_output_len(e), 3)

	d := op_delete(2, 3, 5)
	testing.expect_value(t, d.kind, Op_Kind.Delete)
	testing.expect_value(t, d.old_start, 2)
	testing.expect_value(t, d.old_len, 3)
	testing.expect_value(t, d.new_start, 5)
	testing.expect_value(t, d.new_len, 0)
	testing.expect(t, op_is_change(d))
	testing.expect_value(t, op_output_len(d), 0)

	i := op_insert(2, 3, 5)
	testing.expect_value(t, i.kind, Op_Kind.Insert)
	testing.expect_value(t, i.old_start, 2)
	testing.expect_value(t, i.old_len, 0)
	testing.expect_value(t, i.new_start, 5)
	testing.expect_value(t, i.new_len, 3)
	testing.expect(t, op_is_change(i))
	testing.expect_value(t, op_output_len(i), 3)
}

@(test)
test_builder_merges_adjacent_same_kind_ops :: proc(t: ^testing.T) {
	builder: Op_Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	builder_equal(&builder, 0, 0, 2)
	builder_equal(&builder, 2, 2, 3)
	testing.expect_value(t, builder_len(&builder), 1)

	ops := builder_finish(&builder)
	testing.expect_value(t, len(ops), 1)
	testing.expect_value(t, ops[0].old_len, 5)
	testing.expect_value(t, ops[0].new_len, 5)
}

@(test)
test_builder_does_not_merge_different_kinds_or_gaps :: proc(t: ^testing.T) {
	builder: Op_Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	builder_delete(&builder, 0, 0, 2)
	builder_insert(&builder, 2, 0, 3)
	testing.expect_value(t, builder_len(&builder), 2)

	// same kind, but not adjacent -> should not merge
	builder_equal(&builder, 10, 10, 1)
	builder_equal(&builder, 20, 20, 1)
	testing.expect_value(t, builder_len(&builder), 4)
}

@(test)
test_builder_skips_zero_length_ops :: proc(t: ^testing.T) {
	builder: Op_Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	builder_push(&builder, Op{kind = .Equal, old_start = 0, old_len = 0, new_start = 0, new_len = 0})
	testing.expect_value(t, builder_len(&builder), 0)
}

@(test)
test_builder_reset :: proc(t: ^testing.T) {
	builder: Op_Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	builder_equal(&builder, 0, 0, 2)
	testing.expect_value(t, builder_len(&builder), 1)

	builder_reset(&builder)
	testing.expect_value(t, builder_len(&builder), 0)
}

@(test)
test_ops_offset :: proc(t: ^testing.T) {
	ops := []Op{op_equal(0, 0, 2), op_delete(2, 1, 2)}
	ops_offset(ops, 10, 20)

	testing.expect_value(t, ops[0].old_start, 10)
	testing.expect_value(t, ops[0].new_start, 20)
	testing.expect_value(t, ops[1].old_start, 12)
	testing.expect_value(t, ops[1].new_start, 22)
}

@(test)
test_ops_canonicalize_reorders_insert_then_delete :: proc(t: ^testing.T) {
	// "insert 1 new token, then delete 2 old tokens" should become
	// "delete 2 old tokens, then insert 1 new token" with positions
	// adjusted so the run is still contiguous.
	ops := []Op{op_insert(5, 3, 10), op_delete(5, 2, 13)}
	ops_canonicalize(ops)

	testing.expect_value(t, ops[0].kind, Op_Kind.Delete)
	testing.expect_value(t, ops[0].old_start, 5)
	testing.expect_value(t, ops[0].old_len, 2)
	testing.expect_value(t, ops[0].new_start, 10)

	testing.expect_value(t, ops[1].kind, Op_Kind.Insert)
	testing.expect_value(t, ops[1].old_start, 7)
	testing.expect_value(t, ops[1].new_start, 10)
	testing.expect_value(t, ops[1].new_len, 3)
}

@(test)
test_ops_stats :: proc(t: ^testing.T) {
	ops := []Op{op_equal(0, 0, 3), op_delete(3, 2, 3), op_insert(5, 4, 3)}
	stats := ops_stats(ops)

	testing.expect_value(t, stats.equal_ops, 1)
	testing.expect_value(t, stats.delete_ops, 1)
	testing.expect_value(t, stats.insert_ops, 1)
	testing.expect_value(t, stats.tokens_equal, 3)
	testing.expect_value(t, stats.tokens_delete, 2)
	testing.expect_value(t, stats.tokens_added, 4)
}

@(test)
test_ops_identical :: proc(t: ^testing.T) {
	testing.expect(t, ops_identical([]Op{op_equal(0, 0, 3)}))
	testing.expect(t, ops_identical(nil))
	testing.expect(t, !ops_identical([]Op{op_equal(0, 0, 3), op_delete(3, 1, 3)}))
}

@(test)
test_ops_validate_accepts_well_formed_ops :: proc(t: ^testing.T) {
	ops := []Op{op_equal(0, 0, 2), op_delete(2, 1, 2), op_insert(3, 2, 2), op_equal(3, 4, 1)}
	testing.expect_value(t, ops_validate(ops, 4, 5), Error.None)
}

@(test)
test_ops_validate_rejects_bad_totals :: proc(t: ^testing.T) {
	ops := []Op{op_equal(0, 0, 2)}
	testing.expect_value(t, ops_validate(ops, 3, 2), Error.Invalid_Ops)
	testing.expect_value(t, ops_validate(ops, 2, 3), Error.Invalid_Ops)
}

@(test)
test_ops_validate_rejects_malformed_kinds :: proc(t: ^testing.T) {
	bad_equal := []Op{Op{kind = .Equal, old_start = 0, old_len = 2, new_start = 0, new_len = 1}}
	testing.expect_value(t, ops_validate(bad_equal, 2, 1), Error.Invalid_Ops)

	bad_delete := []Op{Op{kind = .Delete, old_start = 0, old_len = 1, new_start = 0, new_len = 1}}
	testing.expect_value(t, ops_validate(bad_delete, 1, 1), Error.Invalid_Ops)

	bad_insert := []Op{Op{kind = .Insert, old_start = 0, old_len = 1, new_start = 0, new_len = 1}}
	testing.expect_value(t, ops_validate(bad_insert, 1, 1), Error.Invalid_Ops)

	zero_len := []Op{Op{kind = .Equal, old_start = 0, old_len = 0, new_start = 0, new_len = 0}}
	testing.expect_value(t, ops_validate(zero_len, 0, 0), Error.Invalid_Ops)
}

@(test)
test_ops_apply_roundtrip :: proc(t: ^testing.T) {
	old_tokens := []u32{1, 2, 3, 4}
	new_tokens := []u32{1, 9, 3, 4, 9}

	ops := []Op{
		op_equal(0, 0, 1),
		op_delete(1, 1, 1),
		op_insert(2, 1, 1),
		op_equal(2, 2, 2),
		op_insert(4, 1, 4),
	}

	testing.expect_value(t, ops_validate(ops, len(old_tokens), len(new_tokens)), Error.None)

	result, err := ops_apply(old_tokens, new_tokens, ops)
	defer delete(result)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, len(result), len(new_tokens))
	for token, i in result {
		testing.expect_value(t, token, new_tokens[i])
	}

	testing.expect(t, ops_round_trip_ok(old_tokens, new_tokens, ops))
}

@(test)
test_ops_apply_detects_equal_mismatch :: proc(t: ^testing.T) {
	old_tokens := []u32{1, 2, 3}
	new_tokens := []u32{9, 2, 3}

	// Claims position 0 is equal when it isn't.
	ops := []Op{op_equal(0, 0, 3)}

	result, err := ops_apply(old_tokens, new_tokens, ops)
	testing.expect_value(t, err, Error.Apply_Mismatch)
	testing.expect(t, result == nil)

	testing.expect(t, !ops_round_trip_ok(old_tokens, new_tokens, ops))
}
