package engine

// Public entry point: diff two token streams with the requested algorithm.
diff :: proc(a, b: []u32, algorithm := Algorithm.Myers, allocator := context.allocator) -> (ops: []Op, err: Error) {
	switch algorithm {
	case .Myers:
		return myers(a, b, allocator)
	case .Patience:
		return patience(a, b, allocator)
	case .Histogram:
		return histogram(a, b, allocator)
	case .Lcs_Dp:
		return lcs_dp(a, b, allocator)
	}

	return nil, .Invalid_Ops
}
