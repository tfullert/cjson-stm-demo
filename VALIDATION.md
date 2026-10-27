# Validation performed

- Compiled `src/main.c` using GCC C99 with `-Wall -Wextra -Wpedantic -Werror`.
- Linked the resulting Linux smoke-test executable against the environment's
  installed cJSON 1.7.17 shared library. Because its development headers were
  unavailable, the smoke test used a temporary header with only the opaque
  cJSON type and the five API declarations used by this program. That temporary
  header is not part of the delivered project. The real CMake build uses the
  upstream release's own header and compiles its source statically.
- Executed default mode, `--normal`, `--missing`, `--version`, an unknown option,
  and excessive arguments; verified their output and exit codes. Normal input
  succeeded and missing input returned the handled-error exit code 2.
- Parsed `.github/workflows/build.yml` with PyYAML and inspected the Windows
  runner and expected step structure.

## Not executed in the authoring environment

- Full CMake dependency download and build: CMake was unavailable and outbound
  GitHub source downloads were blocked.
- cJSON 1.7.16 crash reproduction: that release was unavailable locally.
- Windows/MSVC build and PowerShell 7 harness: those runtimes were unavailable.
- GitHub Actions execution: no repository was created or workflow dispatched.
- STM signing: the workflow intentionally contains an insertion point rather
  than account-specific signing setup.

The supplied workflow performs the Windows build and both behavioral checks
when the project is pushed to GitHub. The old-version expectation is grounded
in the upstream fix: cJSON_SetValuestring gained a NULL-object guard in 1.7.17.
