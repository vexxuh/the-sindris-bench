package engine

import "core:testing"

ALL_ALGORITHMS :: []Algorithm{.Myers, .Patience, .Histogram, .Lcs_Dp}

@(test)
test_diff_dispatches_to_every_algorithm :: proc(t: ^testing.T) {
	a := []u32{1, 2, 3, 4, 5}
	b := []u32{1, 9, 3, 4, 8}

	for algorithm in ALL_ALGORITHMS {
		ops, err := diff(a, b, algorithm)
		defer delete(ops)

		testing.expectf(t, err == .None, "%v: diff returned %v", algorithm, err)
		testing.expectf(t, ops_validate(ops, len(a), len(b)) == .None, "%v: ops failed validation", algorithm)
		testing.expectf(t, ops_round_trip_ok(a, b, ops), "%v: ops did not round-trip", algorithm)
	}
}

@(test)
test_diff_fuzz_all_algorithms_agree_on_correctness :: proc(t: ^testing.T) {
	gen := new_test_rand(0x5EED)

	for trial in 0 ..< 100 {
		a := random_tokens(&gen, 14, 4)
		defer delete(a)
		b := random_tokens(&gen, 14, 4)
		defer delete(b)

		// Myers and the reference DP algorithm are both exact, so they must
		// agree on the optimal LCS length for every input.
		myers_ops, myers_err := diff(a, b, .Myers)
		defer delete(myers_ops)
		dp_ops, dp_err := diff(a, b, .Lcs_Dp)
		defer delete(dp_ops)

		testing.expectf(t, myers_err == .None && dp_err == .None, "trial %d: exact algorithms failed (%v, %v)", trial, myers_err, dp_err)
		testing.expectf(
			t,
			ops_stats(myers_ops).tokens_equal == ops_stats(dp_ops).tokens_equal,
			"trial %d: myers/lcs_dp disagree on optimal LCS length",
			trial,
		)

		// Patience and histogram are heuristics: they may not find the
		// globally optimal LCS, but every diff they produce must still be
		// a structurally valid, round-tripping edit script.
		for algorithm in ALL_ALGORITHMS {
			ops, err := diff(a, b, algorithm)
			defer delete(ops)

			testing.expectf(t, err == .None, "trial %d: %v returned %v", trial, algorithm, err)
			testing.expectf(t, ops_validate(ops, len(a), len(b)) == .None, "trial %d: %v ops failed validation", trial, algorithm)
			testing.expectf(t, ops_round_trip_ok(a, b, ops), "trial %d: %v ops did not round-trip", trial, algorithm)
		}
	}
}
