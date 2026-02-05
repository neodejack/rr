# RR

## Installation

### Homebrew

```bash
brew install neodejack/tap/rr
```

try running `rr`, mac's security feature should block you from doing this. you need to open up settings -> privacy & security and manually allow this binary to run

### If you are using windows

i dunno. there is a windows binary from github release page tho. but i literally don't know how anything works on windows, you gotta figure it out

## How to use this

1. create a rancher api key and fill them in using the below command

rancher api key can be obtained from `https://<rancher_host>/dashboard/account`

```bash
rr login
```

2. you can now try do `rr kf --help`

some useful commands

```bash
# it will output a path contain kubeconfig that can connect to us_west
rr kf us_west

# it will output "export" command with a path contain kubeconfig that can connect to us_west
rr kf us_west --sh
```

`us_west` has to be substring match of the actual cluster name defined in rancher

3. i like to set up this thing in my .zshrc

```bash
echo 'eval "$(rr zsh)"' >> ~/.zshrc
```

this defines a `yo` helper, so i can just call `yo us_west` to connect to us_west k8s cluster in my current shell

Note: in release binaries, pressing Ctrl-C exits immediately (no IEx BREAK menu).
