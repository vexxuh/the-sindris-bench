package password

import "core:strings"
import "core:testing"

@(test)
test_words_loads_a_large_wordlist_with_no_blank_entries :: proc(t: ^testing.T) {
	list := words()
	defer delete(list)

	testing.expect(t, len(list) > 1000, "expected a sizeable wordlist")

	for word in list {
		testing.expectf(t, word != "", "wordlist contained a blank entry")
	}
}

@(test)
test_words_entries_are_lowercase_alphabetic :: proc(t: ^testing.T) {
	list := words()
	defer delete(list)

	for word in list {
		testing.expectf(t, len(word) >= 4 && len(word) <= 8, "word %q outside expected length range", word)
		for c in word {
			is_lower := c >= 'a' && c <= 'z'
			testing.expectf(t, is_lower, "word %q contains a non-lowercase-alphabetic byte", word)
		}
	}
}

@(test)
test_generate_default_options_has_four_words :: proc(t: ^testing.T) {
	phrase, err := generate()
	defer delete(phrase)

	testing.expect_value(t, err, Error.None)
	parts := strings.split(phrase, "-")
	defer delete(parts)
	testing.expect_value(t, len(parts), 4)

	for part in parts {
		testing.expectf(t, part != "", "phrase %q had an empty segment", phrase)
	}
}

@(test)
test_generate_rejects_non_positive_word_count :: proc(t: ^testing.T) {
	phrase, err := generate(Options{word_count = 0, separator = "-"})
	testing.expect_value(t, err, Error.Invalid_Word_Count)
	testing.expect_value(t, phrase, "")

	phrase2, err2 := generate(Options{word_count = -3, separator = "-"})
	testing.expect_value(t, err2, Error.Invalid_Word_Count)
	testing.expect_value(t, phrase2, "")
}

@(test)
test_generate_respects_word_count_and_separator :: proc(t: ^testing.T) {
	phrase, err := generate(Options{word_count = 6, separator = "_"})
	defer delete(phrase)

	testing.expect_value(t, err, Error.None)
	parts := strings.split(phrase, "_")
	defer delete(parts)
	testing.expect_value(t, len(parts), 6)
}

@(test)
test_generate_capitalizes_each_word_when_requested :: proc(t: ^testing.T) {
	phrase, err := generate(Options{word_count = 3, separator = "-", capitalize = true})
	defer delete(phrase)

	testing.expect_value(t, err, Error.None)
	parts := strings.split(phrase, "-")
	defer delete(parts)
	testing.expect_value(t, len(parts), 3)

	for part in parts {
		first := part[0]
		testing.expectf(t, first >= 'A' && first <= 'Z', "expected %q to start with an uppercase letter", part)
	}
}

@(test)
test_generate_produces_varying_output :: proc(t: ^testing.T) {
	// Not a statistical test of the RNG itself -- just a smoke check that
	// successive calls aren't returning the same fixed phrase.
	seen := make(map[string]bool)
	defer delete(seen)

	// Keep every phrase alive until after we're done using them as map
	// keys (Odin map keys for `string` just alias the header, they don't
	// clone the bytes), then free them all at once.
	phrases := make([dynamic]string, 0, 20)
	defer {
		for phrase in phrases {
			delete(phrase)
		}
		delete(phrases)
	}

	for _ in 0 ..< 20 {
		phrase, err := generate(Options{word_count = 5, separator = "-"})
		testing.expect_value(t, err, Error.None)
		append(&phrases, phrase)
		seen[phrase] = true
	}

	testing.expectf(t, len(seen) > 1, "expected varying output across calls, got the same phrase every time")
}
