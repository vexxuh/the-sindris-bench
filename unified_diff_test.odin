package main

import "core:testing"
import "diff/engine"

// A small shared intern table: token id == its index, so old_tokens /
// new_tokens can just be identity ranges into it for these tests.
test_lines :: []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"}

@(test)
test_build_hunks_single_change_becomes_one_hunk :: proc(t: ^testing.T) {
	// old: a b c d e   new: a b X d e
	old_tokens := []u32{0, 1, 2, 3, 4}
	new_tokens := []u32{0, 1, 5, 3, 4}

	ops := []engine.Op{
		engine.op_equal(0, 0, 2),
		engine.op_delete(2, 1, 2),
		engine.op_insert(3, 1, 2),
		engine.op_equal(3, 3, 2),
	}

	hunks := build_hunks(ops, old_tokens, new_tokens, test_lines)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 1)
	testing.expect_value(t, hunks[0].old_start, 0)
	testing.expect_value(t, hunks[0].new_start, 0)
	testing.expect_value(t, hunks[0].old_count, 5)
	testing.expect_value(t, hunks[0].new_count, 5)
}

@(test)
test_build_hunks_splits_far_apart_changes :: proc(t: ^testing.T) {
	// old: a b c d e f g h i j (10 lines), change at index 0 and index 9,
	// with a big untouched gap between them -> two separate hunks.
	old_tokens := []u32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
	new_tokens := []u32{6, 1, 2, 3, 4, 5, 6, 7, 8, 7}

	ops := []engine.Op{
		engine.op_delete(0, 1, 0),
		engine.op_insert(1, 1, 0),
		engine.op_equal(1, 1, 8),
		engine.op_delete(9, 1, 9),
		engine.op_insert(10, 1, 9),
	}

	hunks := build_hunks(ops, old_tokens, new_tokens, test_lines)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 2)
}

@(test)
test_build_hunks_merges_nearby_changes :: proc(t: ^testing.T) {
	// Two single-line changes separated by only 2 unchanged lines (less
	// than 2 * CONTEXT_LINES) must land in the same hunk.
	old_tokens := []u32{0, 1, 2, 3, 4, 5, 6}
	new_tokens := []u32{7, 1, 2, 3, 4, 5, 8}

	ops := []engine.Op{
		engine.op_delete(0, 1, 0),
		engine.op_insert(1, 1, 0),
		engine.op_equal(1, 1, 5),
		engine.op_delete(6, 1, 6),
		engine.op_insert(7, 1, 6),
	}

	hunks := build_hunks(ops, old_tokens, new_tokens, test_lines)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 1)
	testing.expect_value(t, hunks[0].old_count, 7)
	testing.expect_value(t, hunks[0].new_count, 7)
}

@(test)
test_build_hunks_pure_insert_at_start_has_zero_old_count :: proc(t: ^testing.T) {
	new_tokens := []u32{0, 1}

	ops := []engine.Op{engine.op_insert(0, 2, 0)}

	hunks := build_hunks(ops, nil, new_tokens, test_lines)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 1)
	testing.expect_value(t, hunks[0].old_count, 0)
	testing.expect_value(t, hunks[0].old_start, 0)
	testing.expect_value(t, hunks[0].new_count, 2)
}

@(test)
test_build_hunks_identical_ops_produce_no_hunks :: proc(t: ^testing.T) {
	tokens := []u32{0, 1, 2}
	ops := []engine.Op{engine.op_equal(0, 0, 3)}

	hunks := build_hunks(ops, tokens, tokens, test_lines)
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 0)
}
