package json

import "core:testing"

@(test)
test_pretty_print_scalars_are_unchanged :: proc(t: ^testing.T) {
	cases := []string{"null", "true", "false", "42", "-3.14", `"hi"`}
	for text in cases {
		v, err, _ := parse(text)
		testing.expect_value(t, err, Error.None)

		out := pretty_print(v)
		defer delete(out)
		testing.expect_value(t, out, text)
	}
}

@(test)
test_pretty_print_empty_containers :: proc(t: ^testing.T) {
	arr, aerr, _ := parse(`[]`)
	testing.expect_value(t, aerr, Error.None)
	arr_out := pretty_print(arr)
	defer delete(arr_out)
	testing.expect_value(t, arr_out, "[]")

	obj, oerr, _ := parse(`{}`)
	testing.expect_value(t, oerr, Error.None)
	obj_out := pretty_print(obj)
	defer delete(obj_out)
	testing.expect_value(t, obj_out, "{}")
}

@(test)
test_pretty_print_nested_structure :: proc(t: ^testing.T) {
	v, err, _ := parse(`{"a":1,"b":[2,3],"c":{"d":true}}`)
	defer value_destroy(v)
	testing.expect_value(t, err, Error.None)

	out := pretty_print(v)
	defer delete(out)

	expected := `{
  "a": 1,
  "b": [
    2,
    3
  ],
  "c": {
    "d": true
  }
}`
	testing.expect_value(t, out, expected)
}

@(test)
test_pretty_print_respects_custom_indent_width :: proc(t: ^testing.T) {
	v, err, _ := parse(`{"a":[1]}`)
	defer value_destroy(v)
	testing.expect_value(t, err, Error.None)

	out := pretty_print(v, Pretty_Options{indent_width = 4})
	defer delete(out)

	expected := `{
    "a": [
        1
    ]
}`
	testing.expect_value(t, out, expected)
}

@(test)
test_pretty_print_is_idempotent :: proc(t: ^testing.T) {
	v1, err1, _ := parse(`{"x":[1,2,{"y":"z"}]}`)
	defer value_destroy(v1)
	testing.expect_value(t, err1, Error.None)

	first := pretty_print(v1)
	defer delete(first)

	v2, err2, _ := parse(first)
	defer value_destroy(v2)
	testing.expect_value(t, err2, Error.None)

	second := pretty_print(v2)
	defer delete(second)

	testing.expect_value(t, first, second)
}
