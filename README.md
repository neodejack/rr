# RR

## Installation

1. download the binary executable from github release page
2. unzip and cp the binary executable into your PATH. for example, you can copy it into `$HOME/.local/bin`
3. try running `rr`, mac's security feature should block you from doing this. you need to open up settings -> privacy & security and manually allow this binary to run

## How to use this

1. put in the rancher auth configs

```bash
rr login
```

2. you can now try do `rr kf --help`

some useful commands

```bash
# check local kubeconfig first, if the local kubeconfig is not valid, then download kubeconfig for us_west cluster, save it locally, and output path of saved kubeconfig to stdout
rr kf us_west
# check local kubeconfig first, if the local kubeconfig is not valid, then download kubeconfig for us_west cluster, save it locally, and output shell command to use the kubeconfig in the current shell to stdout
rr kf us_west --sh
# download kubeconfig for us_west cluster, save it locally (overwriting the local kubeconfig whether it's still valid or not), and output shell command to use the kubeconfig in the current shell to stdout
rr kf us_west --sh --new
```

3. i like to set up this thing in my .zshrc

```bash
## put this somewhere in your .zshrc/.bashrc
hi () {
    eval "$(rr kf --sh "$1")"
}
```

then i can just call `hi us_west` to connect to us_west k8s cluster in my current shell
