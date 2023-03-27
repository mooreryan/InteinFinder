# Installing Precompiled Binaries

Probably the most straightforward way to use the `InteinFinder` program is to download one of the precompiled binaries available on the GitHub [releases](https://github.com/mooreryan/InteinFinder/releases) page.

A couple different "flavors" are available:

- macOS
    - Use this if you have a Mac
    - Note that I have not tested it on the new Apple Silicon chips, but it *should* work with Rosetta.
    - You will (likely) need to deal with the "unidentified developer" prompts
        - This [macOS user guide page](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac) has steps  explaining how to open an app from an unidentified developer.
        - Alternatively, here is a [Macworld](https://www.macworld.com/article/672947/how-to-open-a-mac-app-from-an-unidentified-developer.html) article explaining the steps with pictures.
- Linux
    - This should work on most Linux systems with GLIBC version 2.31 or greater.
    - It does have some dynamically linked C/C++ libraries, so it may not work if you have an older system (e.g., one with GLIBC older than 2.31). See the release page for more info.

You can find them all on the [releases](https://github.com/mooreryan/InteinFinder/releases) page.

Don't forget that after downloading one of the binaries, you will need to adjust the permissions to make it executable (e.g., `chmod +x InteinFinder`).

Before running InteinFinder, you will need to install the [external dependencies](./installing-external-dependencies.md) that `InteinFinder` relies on.

## Example

Here is an example of getting one of the `InteinFinder` binaries working:

```
$ \curl -L https://github.com/mooreryan/InteinFinder/releases/download/1.0.0-alpha/InteinFinder-linux.tar.gz \
  | tar xz
$ cd InteinFinder-linux
$ chmod 755 InteinFinder
$ ./InteinFinder --help
```

Note that it is for `InteinFinder` version `1.0.0-alpha` and using the binary compiled for a Linux system. You can find other versions on the release page.  Replace that with the version you want, or click the links directly on the [releases](https://github.com/mooreryan/InteinFinder/releases) page.
