# synacor

After playing the Advent of Code of 2022, I wanted to check if in
the wild there were similar programming challanges. Luckily the
author is a goldmine of ideas, and that's how I ended up discovering
this great challenge. It has been quite a journey, but very rewarding
eventually! It has been lots of fun finding my way through the 8
riddles, also because I learned a lot while playing. It has also been
an excuse to play with a different programming language since there
were no limitation about it. Once a man said to me: _"Every
programmer in their life should implement at least once a CPU or an
emulator..."_ and here we go!

You can find the challenge instructions and data at this
[link](https://challenge.synacor.com/). Give it a chance and you
won't be disappointed, "I give you my word as Junior Woodchucks"!

## Getting started
The solution has been entirely writte in `Perl v5.36`, which is
already present by default in most of GNU/Linux distributions, but
is also available on Windows platform.

```bash
git clone https://github.com/A-725-K/synacor.git
cd synacor
./main.pl
```

Once the emulator is started you can provide commands for the game
by just typing them after the prompt `>` while if you want to run a
command in the debugger you have to use `@` as prefix. For more
information type:
- **help**: to get information about the possible game actions
- **@help, @h, @?**: to get the list of available debugger commands
