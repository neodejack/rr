refactor logger and stdout:

- a module to do intentional stdout
- if crash, the cli should just crash
- log should go to a log file

---

first time setting up token user experience
a `rr login` command to input auth token, and then immediately verify if the token is usable

---

a response middleware to deal with auth token expiration

prompt user to run `rr login`

---

maybe use https://hexdocs.pm/elixir/URI.html#new/1 as cast function for Owl.IO.input/1
