# Loads the generic bats assertion libraries (bats-support, bats-assert)
# installed by script/install/bats-libs into ~/.local/lib/bats. Appending that
# dir to BATS_LIB_PATH lets a bare `bats test/` resolve the libs with no
# shell-level setup; the default (/usr/lib/bats) is preserved as a fallback so
# a system-wide install still works. bats-assert depends on bats-support, so
# load order matters. Adopting test files `load test_helper` at the top.
export BATS_LIB_PATH="${BATS_LIB_PATH:-/usr/lib/bats}:$HOME/.local/lib/bats"
bats_load_library bats-support
bats_load_library bats-assert
