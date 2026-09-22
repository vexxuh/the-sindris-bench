package engine

import "core:testing"

@(test)
test_lcs_dp_empty_vs_empty :: proc(t: ^testing.T) {
	ops, err := lcs_dp(nil, nil)
	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops == nil)
}

@(test)
test_lcs_dp_identical :: proc(t: ^testing.T) {
	tokens := []u32{1, 2, 3}
	ops, err := lcs_dp(tokens, tokens)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_identical(ops))
	testing.expect(t, ops_round_trip_ok(tokens, tokens, ops))
}

@(test)
test_lcs_dp_finds_optimal_lcs :: proc(t: ^testing.T) {
	// classic example: LCS("ABCBDAB", "BDCABA") = "BCBA" or "BDAB", length 4
	a := []u32{'A', 'B', 'C', 'B', 'D', 'A', 'B'}
	b := []u32{'B', 'D', 'C', 'A', 'B', 'A'}

	ops, err := lcs_dp(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, ops_validate(ops, len(a), len(b)), Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))

	stats := ops_stats(ops)
	testing.expect_value(t, stats.tokens_equal, 4)
}

@(test)
test_lcs_dp_disjoint_sequences :: proc(t: ^testing.T) {
	a := []u32{1, 2, 3}
	b := []u32{4, 5, 6, 7}

	ops, err := lcs_dp(a, b)
	defer delete(ops)

	testing.expect_value(t, err, Error.None)
	testing.expect(t, ops_round_trip_ok(a, b, ops))

	stats := ops_stats(ops)
	testing.expect_value(t, stats.tokens_equal, 0)
	testing.expect_value(t, stats.tokens_delete, 3)
	testing.expect_value(t, stats.tokens_added, 4)
}

@(test)
test_lcs_dp_refuses_oversized_tables :: proc(t: ^testing.T) {
	// (n + 1) * (m + 1) must exceed LCS_DP_MAX_CELLS without actually
	// needing to allocate anything close to that much memory for the
	// input slices themselves.
	n := 4100
	m := 4100
	a := make([]u32, n)
	defer delete(a)
	b := make([]u32, m)
	defer delete(b)

	_, err := lcs_dp(a, b)
	testing.expect_value(t, err, Error.Too_Large)
}
