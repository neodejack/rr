# RR [Archived tui implementation]

```bash
mix deps.get
mix run --no-halt -- kf --zsh
```

the above works. but the altscreen doesn't pops up after wrapping the whole application using burrito(the below command)

```bash
MIX_ENV=prod BURRITO_TARGET=macos_arm mix release
```

im inclining to belive that the burrito build doen't contain the prim_tty that termite(a breeze dependency) requires. and im not too interested in finding a working tty and write the implemented adaptor(something like https://github.com/Gazler/termite/blob/master/lib/termite/terminal/prim_tty.ex)

thus, the tui implementation of this cli app is archived
