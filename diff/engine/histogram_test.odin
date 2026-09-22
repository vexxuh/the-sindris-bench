package engine

import "core:testing"

@(test)
test_histogram_empty_vs_empty :: proc(t: ^testing.T) {
	ops, err := histogram(nil, nil)
	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops == nil)
}

@(test)
test_histogram_identical :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3, 4, 5}
	ops, err := histogram(tokens, tokens)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_identical(ops))
	testing.expect(t, ops_round_trip_ok(tokens, tokens, ops))
}

@(test)
test_histogram_pure_insert_and_delete :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3}

	ins_ops, ins_err := histogram(nil, tokens)
	defer delete(ins_ops)
	testing.expect_value(t, ins_err, Error.None)
	testing.expect(t, ops_round_trip_ok(nil, tokens, ins_ops))

	del_ops, del_err := histogram(tokens, nil)
	defer delete(del_ops)
	testing.expect_value(t, del_err, Error.None)
	testing.expect(t, ops_round_trip_ok(tokens, nil, del_ops))
}

@(test)
test_histogram_anchors_on_lowest_occurrence_token :: proc(t: ^testing.T) {
	// token 2 occurs once on each side amid heavily repeated noise (1s);
	// it should be picked as the anchor even though it's not unique in
	// the "occurs exactly once overall" sense patience requires.
	a := []u32{1, 1, 1, 2, 1, 1}
	b := []u32{9, 9, 2, 9, 9, 9}

	ops, err := histogram(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))

	found_anchor := false
	for op in ops {
		if op.kind == .Equal && op.old_start == 3 && op.new_start == 2 && op.old_len == 1 {
			found_anchor = true
		}
	}
	testing.expect(t, found_anchor, "expected token '2' to anchor the diff")
}

@(test)
test_histogram_ignores_tokens_past_max_chain :: proc(t: ^testing.T) {
	// A token repeated far more than HISTOGRAM_MAX_CHAIN times must not be
	// picked as an anchor; the algorithm should still fall back to myers
	// for the region and produce a correct, round-tripping diff.
	noisy := HISTOGRAM_MAX_CHAIN * 2
	a := make([dynamic]u32, 0, noisy + 2)
	defer delete(a)
	b := make([dynamic]u32, 0, noisy + 2)
	defer delete(b)

	for _ in 0 ..< noisy {
		append(&a, u32(1))
		append(&b, u32(1))
	}
	append(&a, 2)
	append(&b, 3)

	ops, err := histogram(a[:], b[:])
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a[:], b[:], ops))
}

@(test)
test_histogram_fuzz_always_valid_and_round_trips :: proc(t: ^testing.T) {
	gen := new_test_rand(0xFACADE)

	for trial in 0 ..< 200 {
		a := random_tokens(&gen, 12, 3)
		defer delete(a)
		b := random_tokens(&gen, 12, 3)
		defer delete(b)

		ops, err := histogram(a, b)
		defer delete(ops)

		testing.expectf(t, err == .None, "trial %d: histogram returned %v", trial, err)
		testing.expectf(t, ops_validate(ops, len(a), len(b)) == .None, "trial %d: ops failed validation", trial)
		testing.expectf(t, ops_round_trip_ok(a, b, ops), "trial %d: histogram ops did not round-trip", trial)
	}
}
