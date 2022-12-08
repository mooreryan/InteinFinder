# Installing Precompiled Binaries

The simplest way to use the `InteinFinder` program is to download one of the precompiled binaries available on the [releases](https://github.com/mooreryan/InteinFinder/releases) page.

A couple different "flavors" are available:

- macOS
  - Use this if you have a Mac
  - Note that I have not tested it on the new Apple Silicon chips.
- Linux (Ubuntu, dynamic linking)
  - This should work on Ubuntu-like systems (e.g., Debian and possible others).
  - It does have some dynamically linked C/C++ libraries, so it may not work if you have an older system. See the release page for more info.
- Linux (Alpine, static linking)
  - This _should_ work on most Linux systems.
  - It is statically linked, so it should _Just Work_ :)

You can find them all on the [releases](https://github.com/mooreryan/InteinFinder/releases) page.

Don't forget that after downloading one of the binaries, you will need to adjust the permissions to make it executable.

Additionally, you will need to install the [external dependencies](./installing-external-dependencies.md) that `InteinFinder` relies on.

## Example

Here is an example of getting one of the `InteinFinder` binaries working:

```
$ \curl -L https://github.com/mooreryan/InteinFinder/releases/download/1.0.0-alpha/InteinFinder-linux.tar.gz \
  \ tar xz
$ cd InteinFinder-linux
$ chmod 755 InteinFinder
$ ./InteinFinder --help
```

Note that it is for `InteinFinder` version TODO and using the `alpine-static` version. You can find other versions on the release page.
