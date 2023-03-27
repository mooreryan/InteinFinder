browser := "firefox"
cov_dir := "/tmp/InteinFinder"
cov_file := cov_dir / "InteinFinder"
git_describe := "git describe --always --dirty --abbrev=7"
with_commit_hash := "INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}`"

build_dev:
    {{ with_commit_hash }} dune build --profile=dev

build_release:
    INTEIN_FINDER_GIT_COMMIT_HASH=`{{ git_describe }}` \
    dune build --profile=release

clean:
    dune clean

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
