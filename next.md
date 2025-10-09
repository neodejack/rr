`--setup-zsh` command used when guiding user to set up

- used as: `rr kf --setup-zsh` >> ~/.zshrc
- basically it returns a zsh function like

```
kconnect() {
  eval "$(burrito_out/rr_cli_app_macos_arm kf --zsh "$1")"
}
```

---

refactor logger and stdout:

- a module to do intentional stdout
- log should go to a log file

---

first time setting up token user experience
a `rr login` command to input auth token, and then immediately verify if the token is usable

---

a response middleware to deal with auth token expiration

prompt user to run `rr login`
