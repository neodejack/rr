# RR

## Installation

### Homebrew

```bash
brew install neodejack/tap/rr
```

try running `rr`, mac's security feature probably would block you from doing this. you need to open up settings -> privacy & security and manually allow this binary to run

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
# this will list all the clusters in the rancher cluster

rr list

# this will output a path contain kubeconfig that can connect to us_west
rr kf us_west

# this will output "export" command with a path contain kubeconfig that can connect to us_west
rr kf us_west --sh
```

`us_west` has to be substring match of the actual cluster name defined in rancher

## tips

i like to set up this thing in my .zshrc

```bash
rr yo >> ~/.zshrc
```

this defines a `yo` helper, so i can just call `yo us_west` to connect to us_west k8s cluster in my current shell

it works by setting the `KUBECONFIG` env var in the current shell. so i highly suggest you to use some sort of shell prompt tool that can extract `KUBECONFIG` and indicate the kubeconfig context.

for example, i use [`starship`](starship.rs) and my config to set up kubernetes context is [here](https://github.com/neodejack/.dotfiles/blob/7a95812334f20b71dd4d2ccded5811f9150470e0/starship/.config/starship.toml#L49)

if you also use starship, see [starship kubernetes configuration](https://starship.rs/config/#kubernetes)

if you use [`powerlevel10k`](https://github.com/romkatv/powerlevel10k), it has a built-in `kubecontext` segment — see [Show on Command](https://github.com/romkatv/powerlevel10k#show-on-command)

## development

Build the local dev binaries with:

```bash
just dev build
```

Enter the isolated macOS shell with:

```bash
just dev macos
```

Enter the isolated Linux shell with:

```bash
just dev linux
```

`dev_out/bin/` stores the locally built binaries. `dev_out/home/macos` and `dev_out/home/linux` store isolated `RR_HOME` state for each shell, so testing does not mutate `~/.rr`.

On first shell entry, the matching dev home copies `~/.rr/config.json` into `dev_out/home/.../config.json` if it does not already exist. After that, the dev config is left alone so you can make local test edits without them being overwritten on the next shell launch.

Burrito (the packaging and build tool) caches extracted runtime files for the same version (the version is defined in `mix.exs`). If a same-version macOS rebuild looks stale, run `rr maintenance uninstall` inside the macOS dev shell, exit, and enter the shell again.
