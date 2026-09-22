package json

import "core:testing"

@(test)
test_parse_scalars :: proc(t: ^testing.T) {
	n, nerr, _ := parse("null")
	testing.expect_value(t, nerr, Error.None)
	testing.expect_value(t, n.kind, Value_Kind.Null)
	testing.expect_value(t, n.raw, "null")

	tv, terr, _ := parse("true")
	testing.expect_value(t, terr, Error.None)
	testing.expect_value(t, tv.kind, Value_Kind.Bool)
	testing.expect_value(t, tv.raw, "true")

	fv, ferr, _ := parse("false")
	testing.expect_value(t, ferr, Error.None)
	testing.expect_value(t, fv.raw, "false")

	s, serr, _ := parse(`"hello"`)
	testing.expect_value(t, serr, Error.None)
	testing.expect_value(t, s.kind, Value_Kind.String)
	testing.expect_value(t, s.raw, `"hello"`)
}

@(test)
test_parse_numbers :: proc(t: ^testing.T) {
	valid := []string{"0", "-0", "1", "-1", "42", "3.14", "-3.14", "1e10", "1E10", "1e+10", "1e-10", "0.5", "123.456e-7"}
	for text in valid {
		v, err, pos := parse(text)
		testing.expectf(t, err == .None, "%q: expected valid number, got %v at %d", text, err, pos)
		testing.expect_value(t, v.kind, Value_Kind.Number)
		testing.expect_value(t, v.raw, text)
	}

	invalid := []string{"01", "1.", ".5", "1e", "-", "+1"}
	for text in invalid {
		_, err, _ := parse(text)
		testing.expectf(t, err != .None, "%q: expected an error, got none", text)
	}
}

@(test)
test_parse_string_escapes :: proc(t: ^testing.T) {
	v, err, _ := parse(`"a\n\t\"\\\/bé"`)
	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, v.kind, Value_Kind.String)

	_, bad_escape_err, _ := parse(`"\q"`)
	testing.expect_value(t, bad_escape_err, Error.Invalid_Escape)

	_, short_unicode_err, _ := parse(`"\u12"`)
	testing.expect_value(t, short_unicode_err, Error.Invalid_Escape)

	_, unterminated_err, _ := parse(`"abc`)
	testing.expect_value(t, unterminated_err, Error.Unexpected_End)

	_, control_char_err, _ := parse("\"a\nb\"")
	testing.expect_value(t, control_char_err, Error.Invalid_String)
}

@(test)
test_parse_array :: proc(t: ^testing.T) {
	v, err, _ := parse(`[1, 2, 3]`)
	defer value_destroy(v)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, v.kind, Value_Kind.Array)
	testing.expect_value(t, len(v.items), 3)
	testing.expect_value(t, v.items[0].raw, "1")
	testing.expect_value(t, v.items[2].raw, "3")
}

@(test)
test_parse_empty_array :: proc(t: ^testing.T) {
	v, err, _ := parse(`[]`)
	defer value_destroy(v)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, v.kind, Value_Kind.Array)
	testing.expect_value(t, len(v.items), 0)
}

@(test)
test_parse_object :: proc(t: ^testing.T) {
	v, err, _ := parse(`{"a": 1, "b": [true, null], "c": {"d": "e"}}`)
	defer value_destroy(v)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, v.kind, Value_Kind.Object)
	testing.expect_value(t, len(v.fields), 3)
	testing.expect_value(t, v.fields[0].key, `"a"`)
	testing.expect_value(t, v.fields[0].value.raw, "1")
	testing.expect_value(t, v.fields[1].value.kind, Value_Kind.Array)
	testing.expect_value(t, len(v.fields[1].value.items), 2)
	testing.expect_value(t, v.fields[2].value.kind, Value_Kind.Object)
	testing.expect_value(t, v.fields[2].value.fields[0].key, `"d"`)
}

@(test)
test_parse_empty_object :: proc(t: ^testing.T) {
	v, err, _ := parse(`{}`)
	defer value_destroy(v)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, v.kind, Value_Kind.Object)
	testing.expect_value(t, len(v.fields), 0)
}

@(test)
test_parse_whitespace_is_ignored :: proc(t: ^testing.T) {
	v, err, _ := parse("  \n\t{ \"a\" : 1 ,\n \"b\" : 2 }\n  ")
	defer value_destroy(v)

	testing.expect_value(t, err, Error.None)
	testing.expect_value(t, len(v.fields), 2)
}

@(test)
test_parse_rejects_trailing_data :: proc(t: ^testing.T) {
	_, err, pos := parse(`1 2`)
	testing.expect_value(t, err, Error.Trailing_Data)
	testing.expect_value(t, pos, 2)
}

@(test)
test_parse_rejects_malformed_input :: proc(t: ^testing.T) {
	cases := []string{"", "{", "[", "{,}", "[,]", `{"a"}`, `{"a":}`, `{"a":1,}`, `[1,]`, "nul", "tru", "-", "{'a':1}"}
	for text in cases {
		_, err, _ := parse(text)
		testing.expectf(t, err != .None, "%q: expected an error, got none", text)
	}
}

@(test)
test_parse_nested_error_frees_partial_allocations :: proc(t: ^testing.T) {
	// Memory-tracking in `odin test` will flag this if the array/object
	// parsers don't clean up already-appended children on failure.
	_, err, _ := parse(`{"a": [1, 2, {"b": 3}], "c": [4, 5,`)
	testing.expect(t, err != .None)
}
