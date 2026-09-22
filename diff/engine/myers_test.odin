package engine

import "core:testing"

@(test)
test_myers_empty_vs_empty :: proc(t: ^testing.T) {
	ops, err := myers(nil, nil)
	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops == nil)
}

@(test)
test_myers_identical :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3, 4, 5}
	ops, err := myers(tokens, tokens)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, len(ops), 1)
	testing.expect(t, ops_identical(ops))
	testing.expect(t, ops_round_trip_ok(tokens, tokens, ops))
}

@(test)
test_myers_pure_insert :: proc(t: ^testing.T) {
	b := []u32{1, 2, 3}
	ops, err := myers(nil, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_round_trip_ok(nil, b, ops))

	stats := ops_stats(ops)
	testing.expect_value(t, stats.tokens_added, 3)
	testing.expect_value(t, stats.tokens_delete, 0)
	testing.expect_value(t, stats.tokens_equal, 0)
}

@(test)
test_myers_pure_delete :: proc(t: ^testing.T) {
	a := []u32{1, 2, 3}
	ops, err := myers(a, nil)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_round_trip_ok(a, nil, ops))

	stats := ops_stats(ops)
	testing.expect_value(t, stats.tokens_delete, 3)
	testing.expect_value(t, stats.tokens_added, 0)
}

@(test)
test_myers_classic_example :: proc(t: ^testing.T) {
	// The worked example from Myers' 1986 paper: shortest edit script
	// between "ABCABBA" and "CBABAC" has length D = 5.
	a := []u32{'A', 'B', 'C', 'A', 'B', 'B', 'A'}
	b := []u32{'C', 'B', 'A', 'B', 'A', 'C'}

	ops, err := myers(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))

	stats := ops_stats(ops)
	testing.expect_value(t, stats.tokens_delete + stats.tokens_added, 5)
}

@(test)
test_myers_matches_optimal_lcs_length :: proc(t: ^testing.T) {
	// Myers is an exact (not heuristic) algorithm, so its equal-token count
	// must always match the reference O(n*m) DP algorithm's.
	cases := [][2][]u32{
		{[]u32{1, 2, 3, 4, 5}, []u32{1, 2, 3, 4, 5}},
		{[]u32{1, 2, 3}, []u32{4, 5, 6}},
		{[]u32{1, 2, 3, 4, 5}, []u32{2, 4}},
		{[]u32{1, 1, 1, 1}, []u32{1, 1}},
		{[]u32{1, 2, 1, 2, 1, 2}, []u32{2, 1, 2, 1, 2, 1}},
	}

	for pair in cases {
		a, b := pair[0], pair[1]

		myers_ops, myers_err := myers(a, b)
		defer delete(myers_ops)
		dp_ops, dp_err := lcs_dp(a, b)
		defer delete(dp_ops)

		testing.expect_value(t, myers_err, Error.None)
		testing.expect_value(t, dp_err, Error.None)

		testing.expect(t, ops_round_trip_ok(a, b, myers_ops))
		testing.expect_value(t, ops_stats(myers_ops).tokens_equal, ops_stats(dp_ops).tokens_equal)
	}
}

@(test)
test_myers_fuzz_against_lcs_dp :: proc(t: ^testing.T) {
	gen := new_test_rand(0xC0FFEE)

	for trial in 0 ..< 200 {
		a := random_tokens(&gen, 10, 4)
		defer delete(a)
		b := random_tokens(&gen, 10, 4)
		defer delete(b)

		myers_ops, myers_err := myers(a, b)
		defer delete(myers_ops)
		dp_ops, dp_err := lcs_dp(a, b)
		defer delete(dp_ops)

		testing.expectf(t, myers_err == .None, "trial %d: myers returned %v", trial, myers_err)
		testing.expectf(t, dp_err == .None, "trial %d: lcs_dp returned %v", trial, dp_err)

		testing.expectf(t, ops_round_trip_ok(a, b, myers_ops), "trial %d: myers ops did not round-trip", trial)

		myers_equal := ops_stats(myers_ops).tokens_equal
		dp_equal := ops_stats(dp_ops).tokens_equal
		testing.expectf(t, myers_equal == dp_equal, "trial %d: myers found LCS length %d, expected optimal %d", trial, myers_equal, dp_equal)
	}
}
