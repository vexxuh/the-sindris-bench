package engine

// Shared helpers for the algorithm test suites: a small deterministic PRNG
// wrapper so fuzz tests are reproducible across runs.

import "base:runtime"
import "core:math/rand"

new_test_rand :: proc(seed: u64) -> runtime.Default_Random_State {
	return rand.create_u64(seed)
}

// Generates a random token stream of length [0, max_len], drawn from a
// small alphabet so sequences being compared are likely to share tokens
// (a wide-open alphabet would make almost every pair disjoint, which
// exercises far less of the algorithms' matching logic).
random_tokens :: proc(state: ^runtime.Default_Random_State, max_len, alphabet: int, allocator := context.allocator) -> []u32 {
	gen := runtime.default_random_generator(state)

	n := rand.int_max(max_len + 1, gen)
	tokens := make([]u32, n, allocator)
	for i in 0 ..< n {
		tokens[i] = u32(rand.int_max(alphabet, gen))
	}
	return tokens
}
