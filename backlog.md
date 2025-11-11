capture control-c to exit instead of showing the iex menu

---

maybe use https://hexdocs.pm/elixir/URI.html#new/1 as cast function for Owl.IO.input/1

---

§2

- `rr list` to show all clusters

- if no match, show all the available

---

§1
refactor `RR.KubeConfig.execute/4`.

why:

- the naming doesn't really tell what is doing
- the executing logic are overlapping between different clauses

how: separate the logic into two functions

1. a function to choose local kf or download remote kf
2. a function to output path to kf or shell command to use kf
