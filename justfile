browser := "firefox"
cov_dir := "/tmp/InteinFinder"
cov_file := cov_dir / "InteinFinder"
git_describe := "git describe --always --dirty --abbrev=7"

build_dev:
    INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}` \
    dune build --profile=dev

build_release:
    INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}` \
    dune build --profile=release

bundle_assets:
    #!/usr/bin/env bash
    set -euxo pipefail
    cd _assets

    BUNDLE=intein_finder_databases.tar.gz
    TMPDIR=intein_finder_databases
    if [ -f $BUNDLE ]; then rm $BUNDLE; fi

    mkdir -p $TMPDIR
    cp -r cddb isdb README.md $TMPDIR

    tar -czf $BUNDLE $TMPDIR

    rm -r $TMPDIR

clean:
    dune clean

docs_dev:
    mkdocs serve -w _docs_src -f _docs_src/mkdocs.yml -a localhost:8888

install_dev:
    INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}` \
    dune install --profile=dev

install_release:
    INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}` \
    dune install --profile=release

test_dev:
    dune runtest --profile=dev

test_release:
    dune runtest --profile=release

test_coverage:
    #!/usr/bin/env bash
    set -euxo pipefail
    if [ -d {{ cov_dir }} ]; then rm -r {{ cov_dir }}; fi
    mkdir -p {{ cov_dir }}
    BISECT_FILE={{ cov_file }} dune runtest --no-print-directory \
      --instrument-with bisect_ppx --force
    bisect-ppx-report html --coverage-path {{ cov_dir }}
    bisect-ppx-report summary --coverage-path {{ cov_dir }}

test_coverage_open: test_coverage
    {{ browser }} _coverage/index.html

send_coverage: clean test_coverage
    bisect-ppx-report send-to Coveralls --coverage-path {{ cov_dir }}

# Examples

gen_basic_usage_example:
    #!/usr/bin/env bash
    set -euxo pipefail

    TARGET_CDDB=_examples_data/basic_usage/cddb
    TARGET_ISDB=_examples_data/basic_usage/isdb

    if [ -d $TARGET_CDDB ]; then rm -r $TARGET_CDDB; fi
    if [ -d $TARGET_ISDB ]; then rm -r $TARGET_ISDB; fi

    cp -r _assets/cddb _assets/isdb _examples_data/basic_usage

    cd _examples_data

    if [ -f basic_usage.tar.gz]; then rm basic_usage.tar.gz; fi
    tar czf basic_usage.tar.gz basic_usage/
    mv basic_usage.tar.gz ../_examples
