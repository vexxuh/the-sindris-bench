package main

Tab :: enum {
	Diff,
	Json,
	Passphrase,
}

App_State :: struct {
	active_tab: Tab,
	passphrase: Passphrase_State,
}

app_state_init :: proc() -> App_State {
	return App_State{active_tab = .Passphrase, passphrase = passphrase_state_init()}
}

app_state_destroy :: proc(state: ^App_State) {
	passphrase_state_destroy(&state.passphrase)
}
