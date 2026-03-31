# Configuration And Security

- Local state lives under `~/.rr/` by default.
- Set `RR_HOME` to redirect that state to another directory, including the isolated dev-shell homes under `dev_out/home/`.
- Do not commit Rancher tokens, kubeconfigs, or other generated local state.
- Put new secrets in environment variables or local config only.
- When testing packaged behavior, prefer the isolated `just dev macos` or `just dev linux` shells so local experiments do not mutate your real workstation state.
