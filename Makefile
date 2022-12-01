BROWSER = firefox
TEST_COV_D = /tmp/intein_finder
COV_FILE = intein_finder

.PHONY: build_dev
build_dev:
	INTEIN_FINDER_GIT_COMMIT_HASH=`git describe --always --dirty --abbrev=7` dune build --profile=dev

.PHONY: build_release
build_release:
	INTEIN_FINDER_GIT_COMMIT_HASH=`git describe --always --dirty --abbrev=7` dune build --profile=release

.PHONY: clean
clean:
	dune clean

.PHONY: install_dev
install_dev:
	INTEIN_FINDER_GIT_COMMIT_HASH=`git describe --always --dirty --abbrev=7` dune install --profile=dev

.PHONY: install_release
install_release:
	INTEIN_FINDER_GIT_COMMIT_HASH=`git describe --always --dirty --abbrev=7` dune install --profile=release

.PHONY: test_dev
test_dev:
	dune runtest --profile=dev

.PHONY: test_release
test_release:
	dune runtest --profile=release

.PHONY: test_coverage
test_coverage:
	if [ -d $(TEST_COV_D) ]; then rm -r $(TEST_COV_D); fi
	mkdir -p $(TEST_COV_D)
	BISECT_FILE=$(TEST_COV_D)/$(COV_FILE) dune runtest --no-print-directory \
	  --instrument-with bisect_ppx --force
	bisect-ppx-report html --coverage-path $(TEST_COV_D)
	bisect-ppx-report summary --coverage-path $(TEST_COV_D)

.PHONY: test_coverage_open
test_coverage_open: test_coverage
	$(BROWSER) _coverage/index.html

.PHONY: send_coverage
send_coverage: clean test_coverage
	bisect-ppx-report send-to Coveralls --coverage-path $(TEST_COV_D)
