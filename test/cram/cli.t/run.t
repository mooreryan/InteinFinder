--help doesn't fail

  $ InteinFinder --help 1>/dev/null

Prints version

  $ InteinFinder --version | ../scripts/redact_git_hash /dev/stdin
  2024.0.0

No args gives decent message

  $ InteinFinder 2> err
  [1]
  $ grep 'required argument CONFIG is missing' err
  InteinFinder: required argument CONFIG is missing
