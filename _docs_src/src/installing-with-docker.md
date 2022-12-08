# Installing & Using InteinFinder with Docker

*Note: If you're using Windows, I think this is your only option.  WSL may work, but I don't have a way to support it right now.*

*Note: If you use Docker, you won't have to install the [external dependencies](./installing-external-dependencies.md) that InteinFinder relies on.  (Other than Docker of course!)*

An easy way to get started with InteinFinder is by using the [Docker image](https://github.com/mooreryan/ocaml_docker_images/pkgs/container/InteinFinder) we have created.

## Install Docker

First, you will need to [install Docker](https://docs.docker.com/get-docker/) on your computer.

## Run InteinFinder in Docker

Now you can run `InteinFinder` inside of the Docker container.  You can run Docker directly, or use one of the [helper scripts](TODO).

### Using Docker directly

You can get the main help screen like this.

```
$ docker run \
    --rm \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    --user $(id -u):$(id -g) \
    ghcr.io/mooreryan/InteinFinder:VERSION \
    --help
```

*Note: just replace VERSION above with the actual Docker image version, e.g., TODO.*

### Using helper scripts

That's a lot to remember to type, so I recommend using one of the [helper scripts](TODO).

To "install" the scripts, just download them and put them somewhere on your `PATH`.

Here's how you get the main help screen.  It does the same thing as above.

```
$ InteinFinder-docker --help
```

When you use the script, you can just replace `InteinFinder` with `InteinFinder-docker` and you should be good.

### Docker gotchas

There are some things to watch out for with Docker.  Note that if you use the [helper scripts](https://github.com/mooreryan/ocaml_docker_images/tree/main/InteinFinder/InteinFinder/scripts) rather than running the Docker CLI manually, these will be taken care of for you.

* Sometimes you need to provide the full path to a file.
* You need to make sure to mount a volume so the Docker container can read and write files on your hard disk.
* You probably want to set the working directory of the container to your current working directory (unless you want to specify absolute paths to everything).
* You probably want to explicitly set the user and group IDs.  If you don't everything Docker creates will be owned by a different user.  (At least that's how it works on Linux.)

TODO: relative path config file issues
