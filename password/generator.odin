package password

// A "correct horse battery staple" (xkcd #936) style passphrase generator:
// draw a handful of common words independently and uniformly at random and
// join them together. Entropy is `word_count * log2(len(wordlist))` bits,
// since each word is drawn independently and with replacement.
//
// The wordlist is compiled into the binary (see wordlist.txt): lowercase
// English dictionary words, 4-8 letters, derived from a system spellchecker
// dictionary and filtered down to plain alphabetic entries.

import "core:crypto"
import "core:math/rand"
import "core:strings"

@(private)
WORDLIST_TEXT := #load("wordlist.txt", string)

Error :: enum u8 {
	None = 0,
	Invalid_Word_Count,
}

Options :: struct {
	word_count: int,
	separator:  string,
	capitalize: bool,
}

DEFAULT_OPTIONS :: Options{word_count = 4, separator = "-", capitalize = false}

// Returns the bundled wordlist, one word per line, trailing blank line
// (from the file's final newline) dropped. The result must be freed with
// `delete` once the caller is done with it.
words :: proc(allocator := context.allocator) -> []string {
	raw := strings.split_lines(WORDLIST_TEXT, allocator)

	n := len(raw)
	if n == 0 || raw[n - 1] != "" {
		return raw
	}

	// Re-copy into a correctly-sized allocation rather than just
	// returning `raw[:n-1]`: a re-slice would still report the smaller
	// length to `delete`, which frees based on the slice it's given and
	// would under-free the original (larger) allocation.
	trimmed := make([]string, n - 1, allocator)
	copy(trimmed, raw[:n - 1])
	delete(raw, allocator)
	return trimmed
}

// Generates a passphrase like "correct-horse-battery-staple" using a
// cryptographically secure entropy source.
generate :: proc(options := DEFAULT_OPTIONS, allocator := context.allocator) -> (passphrase: string, err: Error) {
	if options.word_count <= 0 {
		return "", .Invalid_Word_Count
	}

	list := words(context.allocator)
	defer delete(list, context.allocator)

	gen := crypto.random_generator()

	b := strings.builder_make(allocator)
	for i in 0 ..< options.word_count {
		if i > 0 {
			strings.write_string(&b, options.separator)
		}

		word := list[rand.int_max(len(list), gen)]
		if options.capitalize {
			strings.write_byte(&b, to_upper_ascii(word[0]))
			strings.write_string(&b, word[1:])
		} else {
			strings.write_string(&b, word)
		}
	}

	return strings.to_string(b), .None
}

@(private)
to_upper_ascii :: proc(c: u8) -> u8 {
	if c >= 'a' && c <= 'z' {
		return c - 'a' + 'A'
	}
	return c
}
