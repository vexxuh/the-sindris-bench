package json

// A standard recursive-descent JSON parser (RFC 8259 grammar). It validates
// structure, string escapes, and number syntax, but deliberately does not
// decode strings or numbers into native types (see value.odin) since all
// this package needs to do afterwards is pretty-print the same text back
// out with different surrounding whitespace.

Error :: enum u8 {
	None = 0,
	Unexpected_End,
	Unexpected_Character,
	Invalid_Number,
	Invalid_String,
	Invalid_Escape,
	Trailing_Data,
}

// Parses `source` as a single JSON document. On success `err == .None` and
// `value` owns allocated memory that must be freed with `value_destroy`.
// On failure `value` is the zero value (nothing to free) and `pos` is the
// byte offset in `source` where the problem was found.
parse :: proc(source: string, allocator := context.allocator) -> (value: Value, err: Error, pos: int) {
	p := Parser{source = source}

	skip_ws(&p)
	value, err = parse_value(&p, allocator)
	if err != .None {
		return {}, err, p.pos
	}

	skip_ws(&p)
	if p.pos != len(p.source) {
		value_destroy(value)
		return {}, .Trailing_Data, p.pos
	}

	return value, .None, p.pos
}

@(private)
Parser :: struct {
	source: string,
	pos:    int,
}

@(private)
is_ws :: proc(c: u8) -> bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

@(private)
is_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

@(private)
is_hex_digit :: proc(c: u8) -> bool {
	return is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

@(private)
skip_ws :: proc(p: ^Parser) {
	for p.pos < len(p.source) && is_ws(p.source[p.pos]) {
		p.pos += 1
	}
}

@(private)
peek :: proc(p: ^Parser) -> (c: u8, ok: bool) {
	if p.pos >= len(p.source) {
		return 0, false
	}
	return p.source[p.pos], true
}

@(private)
parse_value :: proc(p: ^Parser, allocator := context.allocator) -> (value: Value, err: Error) {
	c, ok := peek(p)
	if !ok {
		return {}, .Unexpected_End
	}

	switch c {
	case '{':
		return parse_object(p, allocator)
	case '[':
		return parse_array(p, allocator)
	case '"':
		return parse_string_value(p)
	case 't':
		return parse_literal(p, "true", .Bool)
	case 'f':
		return parse_literal(p, "false", .Bool)
	case 'n':
		return parse_literal(p, "null", .Null)
	case:
		if c == '-' || is_digit(c) {
			return parse_number(p)
		}
		return {}, .Unexpected_Character
	}
}

@(private)
parse_literal :: proc(p: ^Parser, literal: string, kind: Value_Kind) -> (value: Value, err: Error) {
	start := p.pos
	end := p.pos + len(literal)
	if end > len(p.source) || p.source[p.pos:end] != literal {
		return {}, .Unexpected_Character
	}
	p.pos = end
	return Value{kind = kind, raw = p.source[start:end]}, .None
}

// Advances past a run of digits, returning how many were consumed.
@(private)
skip_digits :: proc(p: ^Parser) -> int {
	n := 0
	for {
		c, ok := peek(p)
		if !ok || !is_digit(c) {
			break
		}
		p.pos += 1
		n += 1
	}
	return n
}

@(private)
parse_number :: proc(p: ^Parser) -> (value: Value, err: Error) {
	start := p.pos

	if p.pos < len(p.source) && p.source[p.pos] == '-' {
		p.pos += 1
	}

	if p.pos < len(p.source) && p.source[p.pos] == '0' {
		p.pos += 1
	} else if skip_digits(p) == 0 {
		return {}, .Invalid_Number
	}

	if p.pos < len(p.source) && p.source[p.pos] == '.' {
		p.pos += 1
		if skip_digits(p) == 0 {
			return {}, .Invalid_Number
		}
	}

	if p.pos < len(p.source) && (p.source[p.pos] == 'e' || p.source[p.pos] == 'E') {
		p.pos += 1
		if p.pos < len(p.source) && (p.source[p.pos] == '+' || p.source[p.pos] == '-') {
			p.pos += 1
		}
		if skip_digits(p) == 0 {
			return {}, .Invalid_Number
		}
	}

	return Value{kind = .Number, raw = p.source[start:p.pos]}, .None
}

// Parses a string token (used for both values and object keys), returning
// its raw source text including the surrounding quotes.
@(private)
parse_string_raw :: proc(p: ^Parser) -> (raw: string, err: Error) {
	start := p.pos
	if c, ok := peek(p); !ok || c != '"' {
		return "", .Unexpected_Character
	}
	p.pos += 1

	for {
		c, ok := peek(p)
		if !ok {
			return "", .Unexpected_End
		}

		if c == '"' {
			p.pos += 1
			return p.source[start:p.pos], .None
		}

		if c == '\\' {
			p.pos += 1
			esc, esc_ok := peek(p)
			if !esc_ok {
				return "", .Unexpected_End
			}
			switch esc {
			case '"', '\\', '/', 'b', 'f', 'n', 'r', 't':
				p.pos += 1
			case 'u':
				p.pos += 1
				for _ in 0 ..< 4 {
					hc, hok := peek(p)
					if !hok || !is_hex_digit(hc) {
						return "", .Invalid_Escape
					}
					p.pos += 1
				}
			case:
				return "", .Invalid_Escape
			}
			continue
		}

		if c < 0x20 {
			return "", .Invalid_String
		}

		p.pos += 1
	}
}

@(private)
parse_string_value :: proc(p: ^Parser) -> (value: Value, err: Error) {
	raw, serr := parse_string_raw(p)
	if serr != .None {
		return {}, serr
	}
	return Value{kind = .String, raw = raw}, .None
}

@(private)
parse_array :: proc(p: ^Parser, allocator := context.allocator) -> (value: Value, err: Error) {
	p.pos += 1 // consume '['

	skip_ws(p)
	if c, ok := peek(p); ok && c == ']' {
		p.pos += 1
		return Value{kind = .Array}, .None
	}

	items := make([dynamic]Value, 0, 4, allocator)

	for {
		skip_ws(p)
		item, ierr := parse_value(p, allocator)
		if ierr != .None {
			destroy_items(items)
			return {}, ierr
		}
		append(&items, item)

		skip_ws(p)
		c, ok := peek(p)
		if !ok {
			destroy_items(items)
			return {}, .Unexpected_End
		}
		if c == ',' {
			p.pos += 1
			continue
		}
		if c == ']' {
			p.pos += 1
			return Value{kind = .Array, items = items[:]}, .None
		}
		destroy_items(items)
		return {}, .Unexpected_Character
	}
}

@(private)
parse_object :: proc(p: ^Parser, allocator := context.allocator) -> (value: Value, err: Error) {
	p.pos += 1 // consume '{'

	skip_ws(p)
	if c, ok := peek(p); ok && c == '}' {
		p.pos += 1
		return Value{kind = .Object}, .None
	}

	fields := make([dynamic]Field, 0, 4, allocator)

	for {
		skip_ws(p)
		c, ok := peek(p)
		if !ok || c != '"' {
			destroy_fields(fields)
			return {}, .Unexpected_Character
		}
		key, kerr := parse_string_raw(p)
		if kerr != .None {
			destroy_fields(fields)
			return {}, kerr
		}

		skip_ws(p)
		c, ok = peek(p)
		if !ok || c != ':' {
			destroy_fields(fields)
			return {}, .Unexpected_Character
		}
		p.pos += 1

		skip_ws(p)
		field_value, verr := parse_value(p, allocator)
		if verr != .None {
			destroy_fields(fields)
			return {}, verr
		}
		append(&fields, Field{key = key, value = field_value})

		skip_ws(p)
		c, ok = peek(p)
		if !ok {
			destroy_fields(fields)
			return {}, .Unexpected_End
		}
		if c == ',' {
			p.pos += 1
			continue
		}
		if c == '}' {
			p.pos += 1
			return Value{kind = .Object, fields = fields[:]}, .None
		}
		destroy_fields(fields)
		return {}, .Unexpected_Character
	}
}

@(private)
destroy_items :: proc(items: [dynamic]Value) {
	for item in items {
		value_destroy(item)
	}
	delete(items)
}

@(private)
destroy_fields :: proc(fields: [dynamic]Field) {
	for field in fields {
		value_destroy(field.value)
	}
	delete(fields)
}
