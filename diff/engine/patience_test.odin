package engine

import "core:testing"

@(test)
test_patience_empty_vs_empty :: proc(t: ^testing.T) {
	ops, err := patience(nil, nil)
	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops == nil)
}

@(test)
test_patience_identical :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3, 4, 5}
	ops, err := patience(tokens, tokens)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_identical(ops))
	testing.expect(t, ops_round_trip_ok(tokens, tokens, ops))
}

@(test)
test_patience_pure_insert_and_delete :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3}

	ins_ops, ins_err := patience(nil, tokens)
	defer delete(ins_ops)
	testing.expect_value(t, ins_err, Error.None)
	testing.expect(t, ops_round_trip_ok(nil, tokens, ins_ops))

	del_ops, del_err := patience(tokens, nil)
	defer delete(del_ops)
	testing.expect_value(t, del_err, Error.None)
	testing.expect(t, ops_round_trip_ok(tokens, nil, del_ops))
}

@(test)
test_patience_anchors_on_unique_common_lines :: proc(t: ^testing.T) {
	// '3' is the only token that's unique on both sides, so it should
	// anchor the diff and split the noisy runs either side of it into
	// their own (myers-fallback) sub-diffs.
	a := []u32{9, 9, 3, 8, 8}
	b := []u32{7, 7, 3, 6, 6}

	ops, err := patience(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))

	found_anchor := false
	for op in ops {
		if op.kind == .Equal && op.old_start == 2 && op.new_start == 2 && op.old_len == 1 {
			found_anchor = true
		}
	}
	testing.expect(t, found_anchor, "expected the unique token '3' to survive as an equal op at position 2")
}

@(test)
test_patience_falls_back_when_no_unique_tokens_exist :: proc(t: ^testing.T) {
	// Every token is repeated, so there's no unique anchor anywhere;
	// patience must fall back to myers for the whole thing and still
	// produce a valid, round-tripping diff.
	a := []u32{1, 1, 2, 2}
	b := []u32{2, 2, 1, 1}

	ops, err := patience(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))
}

@(test)
test_patience_fuzz_always_valid_and_round_trips :: proc(t: ^testing.T) {
	gen := new_test_rand(0xBADC0DE)

	for trial in 0 ..< 200 {
		a := random_tokens(&gen, 12, 3)
		defer delete(a)
		b := random_tokens(&gen, 12, 3)
		defer delete(b)

		ops, err := patience(a, b)
		defer delete(ops)

		testing.expectf(t, err == .None, "trial %d: patience returned %v", trial, err)
		testing.expectf(t, ops_validate(ops, len(a), len(b)) == .None, "trial %d: ops failed validation", trial)
		testing.expectf(t, ops_round_trip_ok(a, b, ops), "trial %d: patience ops did not round-trip", trial)
	}
}
