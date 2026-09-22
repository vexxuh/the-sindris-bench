package main

// Everything else in this package tests the pipeline in memory (strings
// straight into tokenize_lines). These tests instead go through real files
// on disk end to end: write -> os.read_entire_file -> tokenize -> diff ->
// build_hunks, the same path main() itself takes.

import "core:os"
import "core:path/filepath"
import "core:testing"
import "../diff/engine"

@(private)
write_fixture :: proc(t: ^testing.T, dir, name, content: string) -> string {
	path, _ := filepath.join([]string{dir, name})
	err := os.write_entire_file(path, transmute([]byte)content)
	testing.expectf(t, err == nil, "failed to write fixture %q: %v", path, err)
	return path
}

@(test)
test_diff_pipeline_reads_real_files_and_finds_changes :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	old_path := write_fixture(t, dir, "sindri_old.txt", "a\nb\nc\nd\ne\n")
	defer delete(old_path)
	defer os.remove(old_path)
	new_path := write_fixture(t, dir, "sindri_new.txt", "a\nb\nX\nd\ne\n")
	defer delete(new_path)
	defer os.remove(new_path)

	old_bytes, old_err := os.read_entire_file(old_path, context.allocator)
	testing.expect_value(t, old_err, nil)
	defer delete(old_bytes)

	new_bytes, new_err := os.read_entire_file(new_path, context.allocator)
	testing.expect_value(t, new_err, nil)
	defer delete(new_bytes)

	table := line_table_init()
	defer line_table_destroy(&table)

	old_tokens := tokenize_lines(&table, string(old_bytes))
	defer delete(old_tokens)
	new_tokens := tokenize_lines(&table, string(new_bytes))
	defer delete(new_tokens)

	testing.expect_value(t, len(old_tokens), 5)
	testing.expect_value(t, len(new_tokens), 5)

	ops, diff_err := engine.diff(old_tokens, new_tokens, .Myers)
	defer delete(ops)
	testing.expect_value(t, diff_err, engine.Error.None)
	testing.expect(t, !engine.ops_identical(ops))
	testing.expect(t, engine.ops_round_trip_ok(old_tokens, new_tokens, ops))

	hunks := build_hunks(ops, old_tokens, new_tokens, table.lines[:])
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}

	testing.expect_value(t, len(hunks), 1)

	found_delete, found_insert := false, false
	for line in hunks[0].lines {
		if line.kind == .Delete && line.text == "c" {
			found_delete = true
		}
		if line.kind == .Insert && line.text == "X" {
			found_insert = true
		}
	}
	testing.expect(t, found_delete, "expected the deleted 'c' line in the hunk")
	testing.expect(t, found_insert, "expected the inserted 'X' line in the hunk")
}

@(test)
test_diff_pipeline_identical_real_files_produce_no_changes :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	content := "one\ntwo\nthree\n"
	path_a := write_fixture(t, dir, "sindri_same_a.txt", content)
	defer delete(path_a)
	defer os.remove(path_a)
	path_b := write_fixture(t, dir, "sindri_same_b.txt", content)
	defer delete(path_b)
	defer os.remove(path_b)

	bytes_a, err_a := os.read_entire_file(path_a, context.allocator)
	testing.expect_value(t, err_a, nil)
	defer delete(bytes_a)
	bytes_b, err_b := os.read_entire_file(path_b, context.allocator)
	testing.expect_value(t, err_b, nil)
	defer delete(bytes_b)

	table := line_table_init()
	defer line_table_destroy(&table)

	tokens_a := tokenize_lines(&table, string(bytes_a))
	defer delete(tokens_a)
	tokens_b := tokenize_lines(&table, string(bytes_b))
	defer delete(tokens_b)

	ops, err := engine.diff(tokens_a, tokens_b, .Myers)
	defer delete(ops)

	testing.expect_value(t, err, engine.Error.None)
	testing.expect(t, engine.ops_identical(ops))

	hunks := build_hunks(ops, tokens_a, tokens_b, table.lines[:])
	defer {
		hunks_destroy(hunks[:])
		delete(hunks)
	}
	testing.expect_value(t, len(hunks), 0)
}

@(test)
test_reading_a_missing_file_reports_not_exist :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	missing_path, _ := filepath.join([]string{dir, "sindri_does_not_exist.txt"})
	defer delete(missing_path)

	_, err := os.read_entire_file(missing_path, context.allocator)
	testing.expect(t, err != nil)
}

