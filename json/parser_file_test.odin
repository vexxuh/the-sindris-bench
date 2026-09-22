package json

// File-based tests: write a fixture to disk, read it back with
// os.read_entire_file, and run it through the real parse -> pretty_print
// path, the same one the CLI's --pretty mode uses.

import "core:os"
import "core:path/filepath"
import "core:testing"

@(private)
write_json_fixture :: proc(t: ^testing.T, dir, name, content: string) -> string {
	path, _ := filepath.join([]string{dir, name})
	err := os.write_entire_file(path, transmute([]byte)content)
	testing.expectf(t, err == nil, "failed to write fixture %q: %v", path, err)
	return path
}

@(test)
test_parse_and_pretty_print_a_real_file :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	path := write_json_fixture(t, dir, "sindri_sample.json", `{"name":"sindri","tags":["diff","json"],"count":3,"ok":true,"nil":null,"nested":{"a":[1,2,3]}}`)
	defer delete(path)
	defer os.remove(path)

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	value, parse_err, _ := parse(string(data))
	defer value_destroy(value)
	testing.expect_value(t, parse_err, Error.None)
	testing.expect_value(t, value.kind, Value_Kind.Object)

	out := pretty_print(value)
	defer delete(out)

	expected := `{
  "name": "sindri",
  "tags": [
    "diff",
    "json"
  ],
  "count": 3,
  "ok": true,
  "nil": null,
  "nested": {
    "a": [
      1,
      2,
      3
    ]
  }
}`
	testing.expect_value(t, out, expected)
}

@(test)
test_parse_reports_error_location_in_a_real_file :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	// line 3 has a trailing comma before the closing brace, which is
	// invalid JSON.
	path := write_json_fixture(t, dir, "sindri_bad.json", "{\n  \"a\": 1,\n  \"b\": 2,\n}\n")
	defer delete(path)
	defer os.remove(path)

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	_, parse_err, pos := parse(string(data))
	testing.expect(t, parse_err != .None)
	testing.expect(t, pos >= 0 && pos <= len(data))
}

@(test)
test_pretty_print_round_trips_through_disk :: proc(t: ^testing.T) {
	dir, dir_err := os.temp_dir(context.allocator)
	testing.expect(t, dir_err == nil)
	defer delete(dir)

	original := `[{"x":1},{"y":[true,false,null]}]`
	path := write_json_fixture(t, dir, "sindri_roundtrip.json", original)
	defer delete(path)
	defer os.remove(path)

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	v1, err1, _ := parse(string(data))
	defer value_destroy(v1)
	testing.expect_value(t, err1, Error.None)

	pretty := pretty_print(v1)
	defer delete(pretty)

	pretty_path := write_json_fixture(t, dir, "sindri_roundtrip_pretty.json", pretty)
	defer delete(pretty_path)
	defer os.remove(pretty_path)

	reread, reread_err := os.read_entire_file(pretty_path, context.allocator)
	testing.expect(t, reread_err == nil)
	defer delete(reread)

	v2, err2, _ := parse(string(reread))
	defer value_destroy(v2)
	testing.expect_value(t, err2, Error.None)

	second_pretty := pretty_print(v2)
	defer delete(second_pretty)

	testing.expect_value(t, pretty, second_pretty)
}
