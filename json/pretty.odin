package json

import "core:strings"

Pretty_Options :: struct {
	indent_width: int,
}

DEFAULT_PRETTY_OPTIONS :: Pretty_Options{indent_width = 2}

// Re-renders a parsed value with one member/element per line and nested
// structures indented by `options.indent_width` spaces per level. Object key
// order is preserved exactly as parsed.
pretty_print :: proc(value: Value, options := DEFAULT_PRETTY_OPTIONS, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	write_value(&b, value, 0, options)
	return strings.to_string(b)
}

@(private)
write_indent :: proc(b: ^strings.Builder, level: int, options: Pretty_Options) {
	for _ in 0 ..< level * options.indent_width {
		strings.write_byte(b, ' ')
	}
}

@(private)
write_value :: proc(b: ^strings.Builder, value: Value, level: int, options: Pretty_Options) {
	switch value.kind {
	case .Null, .Bool, .Number, .String:
		strings.write_string(b, value.raw)

	case .Array:
		if len(value.items) == 0 {
			strings.write_string(b, "[]")
			return
		}
		strings.write_string(b, "[\n")
		for item, i in value.items {
			write_indent(b, level + 1, options)
			write_value(b, item, level + 1, options)
			if i < len(value.items) - 1 {
				strings.write_byte(b, ',')
			}
			strings.write_byte(b, '\n')
		}
		write_indent(b, level, options)
		strings.write_byte(b, ']')

	case .Object:
		if len(value.fields) == 0 {
			strings.write_string(b, "{}")
			return
		}
		strings.write_string(b, "{\n")
		for field, i in value.fields {
			write_indent(b, level + 1, options)
			strings.write_string(b, field.key)
			strings.write_string(b, ": ")
			write_value(b, field.value, level + 1, options)
			if i < len(value.fields) - 1 {
				strings.write_byte(b, ',')
			}
			strings.write_byte(b, '\n')
		}
		write_indent(b, level, options)
		strings.write_byte(b, '}')
	}
}
