# cJSON dependency update and STM signing demo

A small C console application for demonstrating **CVE-2023-50472**, upgrading
a dependency, rebuilding a Windows executable, and then signing that artifact.

The project starts with **cJSON 1.7.16**. Change one line in `CMakeLists.txt`
to **1.7.17** to demonstrate the fix. The application code stays identical.

| Command | cJSON 1.7.16 | cJSON 1.7.17 |
|---|---|---|
| `cjson-demo.exe --normal` | Updates the setting; exit 0 | Updates the setting; exit 0 |
| `cjson-demo.exe --missing` | Access violation | Rejects missing setting; exit 2 |
| `cjson-demo.exe --version` | Reports 1.7.16 | Reports 1.7.17 |

## Files

- `src/main.c`: the application and deliberate CVE reproduction.
- `CMakeLists.txt`: dependency version, download, static library, and executable.
- `.github/workflows/build.yml`: Windows x64 build, behavioral checks, and artifacts.
- `scripts/Test-Demo.ps1`: PowerShell 7 subprocess checks and JSON report.
- `VALIDATION.md`: checks performed during creation and remaining limitations.

## Upload to GitHub

1. Extract this archive. Use the **contents** of `cjson-stm-demo` as your repository
   root, so `CMakeLists.txt` and `.github` are at the top level. Include `.github`
   and `.gitignore`; they may be hidden in file pickers.
2. Create an empty GitHub repository, then push these files using Git or VS Code.
   The project has no account-specific URLs or credentials to configure.
3. Open **Actions → Build Windows demo**. A push starts the workflow; you can
   also use **Run workflow**. Enable Actions if your organization requires it.
4. Download the artifact named `cjson-demo-windows-x64-cjson-1.7.16`.
   Extract it before running the executable.

Example Git commands after opening a terminal in the extracted project folder:

```powershell
git init
git add .
git commit -m "Add cJSON dependency demonstration"
git branch -M main
git remote add origin https://github.com/YOUR-ACCOUNT/YOUR-REPOSITORY.git
git push -u origin main
```

The workflow uses a GitHub-hosted `windows-2022` runner and Visual Studio 2022
C build tools. It needs outbound access to GitHub to fetch the cJSON source.
It builds and uploads an **unsigned** executable without STM secrets.

## Demonstration: vulnerable build

In the downloaded artifact folder, run:

```powershell
.\cjson-demo.exe --version
.\cjson-demo.exe --normal
.\cjson-demo.exe --missing
$LASTEXITCODE
```

Normal output includes:

```text
cJSON version: 1.7.16
Input: {"name":"Original name"}
Calling cJSON_SetValuestring...
Updated name: Updated name
RESULT: normal update succeeded.
```

The missing-setting case prints the version, `Input: {}`, and
`Calling cJSON_SetValuestring...`, then the vulnerable library crashes.
On Windows the expected process status is `0xC0000005`
(`-1073741819` as a signed integer). A crash is the actual demonstration;
the program does not print a simulated failure based on its version.

## Demonstration: dependency upgrade

Change this line in `CMakeLists.txt`:

```diff
-set(CJSON_VERSION "1.7.16")
+set(CJSON_VERSION "1.7.17")
```

Commit and push the change. GitHub Actions rebuilds from the new tag.
Download the new artifact ending in `1.7.17` and rerun the same commands.
Normal input still succeeds. The missing-setting case now produces:

```text
cJSON version: 1.7.17
Input: {}
Calling cJSON_SetValuestring...
RESULT: missing setting rejected safely.
```

Exit code **2** means the application handled invalid input; it is not a crash.

## What the workflow verifies

The workflow builds Release x64, runs a normal CTest check, and then runs both
cases in separate processes using PowerShell 7. The behavioral check expects
the specific access-violation status on 1.7.16 and a handled rejection on 1.7.17.
Unexpected results fail the workflow. Each process has a 15-second timeout.

**A passing vulnerable build means the historical bug was reproduced as expected.**
This workflow is a demonstration harness, not a vulnerability-blocking release gate.
It should not be presented as a security scan or as proof the executable is safe.

The artifact includes the executable, test results, upstream license,
dependency version, application and dependency commit IDs, and a SHA-256 hash.
The hash is computed after the signing insertion point, so enabling signing
there will hash the signed artifact. The metadata is not a full SBOM.

## Build locally on Windows

Install Visual Studio 2022 **Build Tools** with **Desktop development with C++**,
including MSVC, a Windows SDK, and CMake. Install Git. The Visual Studio IDE
is optional; VS Code can be your editor.

From a Developer PowerShell or another terminal with CMake and Git available:

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release --parallel
ctest --test-dir build -C Release --output-on-failure
.\build\Release\cjson-demo.exe --normal
.\build\Release\cjson-demo.exe --missing
```

After changing the dependency version, rerun configure and build. You can use
separate directories, such as `build-old` and `build-fixed`, to retain both builds.
With PowerShell 7 (`pwsh`), run the same behavioral harness used in CI:

```powershell
./scripts/Test-Demo.ps1 -Executable build/Release/cjson-demo.exe -DependencyVersion 1.7.16
```

Use `-DependencyVersion 1.7.17` for the updated build. The standalone app does
not need PowerShell 7. CMake compiles cJSON directly into the executable and,
with MSVC, also links the runtime statically; no separate cJSON DLL is required.

## Add DigiCert Software Trust Manager signing

The workflow marks an insertion point **after the tests and before packaging**.
Use your configured STM signing integration there, targeting:

```text
build/Release/cjson-demo.exe
```

This starter does not install SMCTL/KSP, upload credentials, select a keypair,
or perform signing. Those depend on your STM account and chosen integration.
If you already have an STM workflow, place its signing steps at the marked point.
Keep API credentials and client-certificate passwords in GitHub secrets, and
do not enable credential-bearing signing on untrusted pull-request code.

Once signing is configured, add a verification step before packaging:

```powershell
$signature = Get-AuthenticodeSignature build/Release/cjson-demo.exe
$signature | Format-List Status, StatusMessage, SignerCertificate
if ($signature.Status -ne 'Valid') { throw 'Authenticode verification failed.' }
```

You can also download the unsigned artifact and sign it from an STM-configured
Windows machine. Rebuild first, then sign the final executable. A dependency
update creates a new executable that requires a new signature. Signing establishes
publisher identity and integrity; it does not remove vulnerabilities.

## Scope and references

The deliberate trigger passes a missing JSON lookup result into
`cJSON_SetValuestring()`. The older implementation dereferences that null
pointer; the fixed implementation rejects it. Application-side input checks
would also prevent this particular trigger. The program is a controlled local
reproduction, not evidence that every cJSON application is remotely exploitable.

Both dependency versions are historical demo pins. 1.7.17 fixes this specific
CVE and is not a recommended current production baseline. The build follows
release tags for an easy version-change demonstration and records their resolved
commits; release tags are not immutable supply-chain pins.

- Upstream changelog, including the 1.7.17 fix:
  https://github.com/DaveGamble/cJSON/blob/master/CHANGELOG.md
- CVE record:
  https://www.cve.org/CVERecord?id=CVE-2023-50472
- Original report: https://github.com/DaveGamble/cJSON/issues/803
- Upstream fix: https://github.com/DaveGamble/cJSON/pull/809
