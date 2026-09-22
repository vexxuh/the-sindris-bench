package json

// A parsed JSON document. Scalars keep their exact source text (`raw`)
// rather than being decoded into native types: a pretty-printer only needs
// to re-emit what was there with different whitespace around it, and this
// sidesteps float-precision loss on numbers and escape re-encoding bugs on
// strings entirely.
Value_Kind :: enum u8 {
	Null,
	Bool,
	Number,
	String,
	Array,
	Object,
}

Value :: struct {
	kind:   Value_Kind,
	raw:    string, // source text for Null/Bool/Number/String (String includes its quotes)
	items:  []Value, // Array elements
	fields: []Field, // Object members, in source order
}

Field :: struct {
	key:   string, // source text of the key, including its quotes
	value: Value,
}

// Recursively frees everything a successful `parse` allocated.
value_destroy :: proc(value: Value) {
	#partial switch value.kind {
	case .Array:
		for item in value.items {
			value_destroy(item)
		}
		delete(value.items)
	case .Object:
		for field in value.fields {
			value_destroy(field.value)
		}
		delete(value.fields)
	}
}
