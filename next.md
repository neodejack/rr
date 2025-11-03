refactor logger and stdout:

- if crash, the cli should just crash
- it shouldn't generate erl_dump file or generate it to a specific location

---

capture control-c to exit instead of showing the iex menu

---

a response middleware to deal with auth token expiration

prompt user to run `rr login`

---

maybe use https://hexdocs.pm/elixir/URI.html#new/1 as cast function for Owl.IO.input/1
