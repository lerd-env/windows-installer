# lerd-setup.exe (Inno Setup)

A wizard installer for lerd on Windows, the native-wizard counterpart of
`lerd.exe --setup` (`cmd/lerd-windows/setup.go`). It is a bootstrapper: it
prepares Windows and hands lerd itself to `install.sh`, so it carries no lerd
binaries and always installs the latest release. The version `build.ps1`
stamps on it only labels Add/Remove Programs.

Needs Windows 10 2004 (build 19041) or newer, x64 or Arm64.

## What it does

1. **WSL features.** Enables `Microsoft-Windows-Subsystem-Linux` and
   `VirtualMachinePlatform` and offers the restart they need. Setup registers
   itself in `RunOnce` and resumes after you sign back in with the same account.
2. **WSL.** Installs the latest MSI from github.com/microsoft/WSL. Setup only
   ever runs the real `wsl.exe` in `C:\Program Files\WSL`; the System32 stub
   opens its own window offering to install WSL.
3. **Ubuntu-24.04**, with a Linux user from the wizard's username and password
   page. The password reaches `chpasswd` through `WSLENV`, never a command line.
4. **Options page**: `.test` with HTTPS (default) or `.localhost` over HTTP,
   and whether lerd manages Node.js. lerd's installers take the defaults, and a
   change runs `lerd dns:disable` or `lerd node:unmanage` afterwards. Skipped
   when lerd is already installed.
5. **lerd.** Installs Podman and the packages `install.sh` checks for, turns on
   linger, then runs `install.sh`. The package list lives in `InstallPackages`
   in `lerd.iss`; keep it in step with `install.sh`.
6. **Certificate.** Imports lerd's root CA into the Windows user's store from
   Setup itself, so Windows' confirmation comes to the front. Declining only
   leaves a browser warning.
7. **Windows integration**: `lerd wsl:setup`.
8. **Start.** Restarts WSL and waits for the dashboard, then offers to open it.
   The finish page ends with `install.sh`'s GitHub star note, and an unticked
   option to open github.com/lerd-env/lerd.

Every Linux command runs under `setsid -w ... </dev/null`: Setup's hidden
console still gives WSL a pty, and a question read from `/dev/tty` would wait
forever. Detached, every question takes its default. The user has passwordless
sudo (`/etc/sudoers.d/zz-lerd-setup`) only while steps 5 to 7 run.

Every step checks before it acts, so running Setup again after a failure
resumes where it stopped. A details box under the progress bar streams each
command's output; the full log is in `%TEMP%\Setup Log *.txt`. Silent installs
are not supported, since the Linux user's password comes from the wizard.

Uninstalling from Add/Remove Programs asks whether to keep the distro, which
runs `lerd uninstall --keep-data` inside it, or to delete it with everything in
it. Either way it removes lerd's Windows side: PATH entry, login agent, DNS
rule and `%LOCALAPPDATA%\lerd`.

## Build

```powershell
winget install JRSoftware.InnoSetup
.\build.ps1                      # -> dist\lerd-setup.exe
.\build.ps1 -Version 1.37.0      # label for Add/Remove Programs; defaults to the latest tag
```

`build.ps1` generates the icon and wizard images into `assets\` from the logo
in `..\lerd-wsl` (`-LerdRepo` to change it), copies its license, and compiles
with ISCC. `assets\` and `dist\` are not committed.

## Testing an unreleased build

`/local=<folder>` installs lerd from a Windows folder holding `install.sh`,
`lerd` and `lerd.exe` instead of the latest release. `make build` in lerd-wsl
leaves `lerd` and `lerd.exe` in `build\`; copy `install.sh` beside them:

```powershell
dist\lerd-setup.exe /local=C:\path\to\lerd-wsl\build
```

`..\lerd-test-vm` has double-click scripts for a Hyper-V test VM that roll back
to a clean Windows, or one with the WSL features already enabled, and copy the
installer (and a local build) into it.
