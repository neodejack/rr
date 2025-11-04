capture control-c to exit instead of showing the iex menu

---

a response middleware to deal with auth token expiration

prompt user to run `rr login`

---

maybe use https://hexdocs.pm/elixir/URI.html#new/1 as cast function for Owl.IO.input/1

---

--new
check if a kubeconfig file already exists and is valid,
if valid: only rewrite if present --new
if not valid: rewrite

---

flow:

if only --zsh:
check if already valid,

- if not: get new kf, update local file, export KUBECONFIG
- if yes: export KUBECONFIG

if --zsh and --new:
get new kf, update local file, export KUBECONFIG

if no switches:
check if already valid,

- if not: get new kf, update local file
- if yes:

discrete steps:

- get new kf
- get kubeconfig path
- update local kubeconfig
- export kubeconfig
