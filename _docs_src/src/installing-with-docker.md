# Installing & Using InteinFinder with Docker

*Note: If you're using Windows, and you are not using WSL, then I think this is your only option.*

*Note: Some users have reported issues with Docker on Apple Silicon (arm).  Unfortunately, this is not something I am able to debug now.*

*Note: If you use Docker, you won't have to install the [external dependencies](./installing-external-dependencies.md) that InteinFinder relies on.  (Other than Docker of course!)*

If you are familiar with Docker, it can provide a potentially easier way to get started with InteinFinder.  You can find the container image on [Dockerhub](https://hub.docker.com/repository/docker/mooreryan/inteinfinder/general).

## Install Docker

First, you will need to [install Docker](https://docs.docker.com/get-docker/) on your computer.  Follow the install instructions for your operating system provided in that link, then return to this page.

## Run InteinFinder in Docker

Now you can run `InteinFinder` inside of the Docker container.  You can run the `docker` command directly, or use one of the [helper script](https://raw.githubusercontent.com/mooreryan/InteinFinder-docker/main/scripts/InteinFinder-docker).

### Using Docker directly

You can get the main help screen like this.

```
$ docker run \
    --rm \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --user $(id -u):$(id -g) \
    mooreryan/inteinfinder:1.0.0-SNAPSHOT-7547273 \
    --help
```

*Note: just replace 1.0.0-SNAPSHOT-7547273 above with whichever version you want to use.*

After all of the docker flags, you then provide the flags or config file as normal.  Here is an example of running InteinFinder.

```
$ docker run \
    --rm \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --user $(id -u):$(id -g) \
    mooreryan/inteinfinder:1.0.0-SNAPSHOT-7547273 \
    config.toml
```

This command assumes that your config file is in the current directory you're running the command in.

A docker tutorial is outside the scope of this document, but in brief...

- The `-v` flag takes care of mounting the current directory in the container, so that you can access files there.
    - **Important!!!**  Because we are mounting the current working directory, any files referenced in your config file must be sub-directories of the current directory.
	- If any of the files are outside of the current directory, they will not be visible inside the container.
- The `-w` flag sets the current working directory to the working directory inside the docker container.
- The `--user` flag sets the user and group to match the current user and group.
    - This makes it so that the files output by InteinFinder will be owned by you.

### Using helper scripts

That's a lot to remember to type, so I recommend using one of the [helper script](https://raw.githubusercontent.com/mooreryan/InteinFinder-docker/main/scripts/InteinFinder-docker).

To "install" the script, just download them and put them somewhere on your `PATH`.

Here's how you get the main help screen.  It does the same thing as above.

```
$ InteinFinder-docker --help
```

When you use the script, you can just replace `InteinFinder` with `InteinFinder-docker` and you should be good.

Be aware that the same notes listed above apply to this helper script usage as well.

### Docker gotchas

There are some things to watch out for with Docker.  Note that if you use the [helper script](https://raw.githubusercontent.com/mooreryan/InteinFinder-docker/main/scripts/InteinFinder-docker) rather than running the Docker CLI manually, some of these will be taken care of for you.

* Sometimes you need to provide the full path to a file.
* You need to make sure to mount a volume so the Docker container can read and write files on your hard disk.
* You probably want to set the working directory of the container to your current working directory (unless you want to specify absolute paths to everything).
* You probably want to explicitly set the user and group IDs.  If you don't everything Docker creates will be owned by a different user.  (At least that's how it works on Linux.)
