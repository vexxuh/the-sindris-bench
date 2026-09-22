package main

import "core:testing"

@(test)
test_tokenize_empty_text_yields_no_tokens :: proc(t: ^testing.T) {
	table := line_table_init()
	defer line_table_destroy(&table)

	tokens := tokenize_lines(&table, "")
	defer delete(tokens)

	testing.expect_value(t, len(tokens), 0)
}

@(test)
test_tokenize_drops_phantom_trailing_line :: proc(t: ^testing.T) {
	table := line_table_init()
	defer line_table_destroy(&table)

	with_newline := tokenize_lines(&table, "a\nb\nc\n")
	defer delete(with_newline)
	testing.expect_value(t, len(with_newline), 3)

	without_newline := tokenize_lines(&table, "a\nb\nc")
	defer delete(without_newline)
	testing.expect_value(t, len(without_newline), 3)
}

@(test)
test_tokenize_interns_repeated_lines_to_the_same_id :: proc(t: ^testing.T) {
	table := line_table_init()
	defer line_table_destroy(&table)

	tokens := tokenize_lines(&table, "a\nb\na\n")
	defer delete(tokens)

	testing.expect_value(t, len(tokens), 3)
	testing.expect_value(t, tokens[0], tokens[2])
	testing.expect(t, tokens[0] != tokens[1])
	testing.expect_value(t, table.lines[tokens[0]], "a")
	testing.expect_value(t, table.lines[tokens[1]], "b")
}

@(test)
test_tokenize_shares_ids_across_both_sides :: proc(t: ^testing.T) {
	table := line_table_init()
	defer line_table_destroy(&table)

	old_tokens := tokenize_lines(&table, "a\nb\nc\n")
	defer delete(old_tokens)
	new_tokens := tokenize_lines(&table, "b\nz\n")
	defer delete(new_tokens)

	// "b" appears in both texts and must intern to the same id.
	testing.expect_value(t, old_tokens[1], new_tokens[0])
	testing.expect(t, new_tokens[1] != old_tokens[1])
}
