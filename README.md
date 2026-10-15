# lerd-setup.exe (Inno Setup)

A wizard installer for lerd on Windows, the native-wizard counterpart of
`lerd.exe --setup` (`cmd/lerd-windows/setup.go`). It is a bootstrapper: it
prepares Windows and hands lerd itself to `install.sh`, so it carries no lerd
binaries and always installs the latest release. It has a version of its own,
which moves only when the installer changes and says nothing about lerd's.

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
5. **Packages.** Installs Podman and the packages `install.sh` checks for, and
   turns on linger. The package list lives in `InstallPackages` in `lerd.iss`;
   keep it in step with `install.sh`.
6. **Desktop app.** Downloads `lerd-desktop-win32-<arch>.zip` from the latest
   lerd-env/lerd-desktop release into `{app}\desktop`, unless that release is
   the one already there, and registers it for the signed-in user: the
   `sh.lerd.Lerd` app ID with lerd's logo, which its notifications are posted
   under, the `lerd://` scheme, a Start menu shortcut and a `lerd-desktop` Run
   entry that starts it hidden in the tray at sign-in. The app holds lerd's
   tray icon and notifications on Windows, keeps lerd's agent running, and has
   no installer of its own. It comes before lerd so that `wsl:setup` finds it
   and leaves the agent to it: started from a Run entry of its own, the
   unsigned agent reads to Windows Defender as malware making itself
   persistent, and Defender has quarantined it for that.
7. **lerd.** Runs `install.sh`.
8. **Certificate.** Imports lerd's root CA into the Windows user's store from
   Setup itself, so Windows' confirmation comes to the front. Declining only
   leaves a browser warning.
9. **Windows integration**: `lerd wsl:setup`, then `lerd notify target native`,
   since the desktop app only receives lerd's notifications from the native
   sink.
10. **Start.** Restarts WSL, waits for the dashboard, and starts the desktop
    app in the tray, which starts lerd's agent. The finish page offers to open
    the app, ends with `install.sh`'s GitHub star note, and has an unticked
    option to open github.com/lerd-env/lerd.

Every Linux command runs under `setsid -w ... </dev/null`: Setup's hidden
console still gives WSL a pty, and a question read from `/dev/tty` would wait
forever. Detached, every question takes its default. The user has passwordless
sudo (`/etc/sudoers.d/zz-lerd-setup`) only while steps 7 to 9 run.

Every step checks before it acts, so running Setup again after a failure
resumes where it stopped. A details box under the progress bar streams each
command's output; the full log is in `%TEMP%\Setup Log *.txt`. Silent installs
are not supported, since the Linux user's password comes from the wizard.

Uninstalling from Add/Remove Programs asks whether to keep the distro, which
runs `lerd uninstall --keep-data` inside it, or to delete it with everything in
it. Either way it removes lerd's Windows side: PATH entry, login agent, DNS
rule and `%LOCALAPPDATA%\lerd`, and the desktop app with its registration.

## Build

```powershell
winget install JRSoftware.InnoSetup
.\build.ps1                      # -> dist\lerd-setup.exe
.\build.ps1 -Version 0.2.0       # overrides the version in lerd.iss
```

`build.ps1` generates the icon and wizard images into `assets\` from
`branding\`, which holds copies of lerd's logo
(`internal/ui/icons/icon-512.png`) and license, so the build needs nothing
outside this repo. Copy them again if lerd's change. `assets\` and `dist\` are
not committed.

## Versions and releases

The version lives in `lerd.iss` (`AppVersion`). It stays on 0.x until the
installer is stable. The wizard shows just "Lerd", so a 0.x number is never
mistaken for lerd's own version; Add/Remove Programs lists it as the version
of the installed package.

`.github/workflows/build.yml` builds `lerd-setup.exe` on every push to `main`
and every pull request and keeps it as a run artifact. Pushing a `v*` tag also publishes it as
a GitHub release, marked as a prerelease while on `v0.*`. No tag has been made
yet.

## When this needs updating

The installer only changes when one of the things it relies on does:

| It relies on | Update it when |
|---|---|
| The package list in `InstallPackages` | `install.sh` starts requiring another package |
| `Ubuntu-24.04` | a newer Ubuntu LTS should be the default |
| `https://lerd.sh/install.sh`, `lerd wsl:setup`, `lerd dns:disable`, `lerd node:unmanage`, `lerd uninstall --keep-data` | one of them moves or changes its meaning |
| lerd's mkcert at `~/.local/share/lerd/bin/mkcert` | lerd moves it |
| lerd's Windows side: `%LOCALAPPDATA%\lerd`, the `lerd` Run key, the NRPT rule commented `lerd`, the `sh.lerd.Lerd` toast app ID | lerd changes how `wsl:setup` installs it, so uninstalling still cleans up |
| microsoft/WSL release assets named `*.x64.msi` / `*.arm64.msi` | Microsoft renames them |
| lerd-env/lerd-desktop release assets named `lerd-desktop-win32-x64.zip` / `lerd-desktop-win32-arm64.zip`, with `lerd-desktop.exe` at their root | lerd-desktop renames them or the executable |
| `lerd notify target native` | lerd renames the command, or the desktop app's notifications move off the native sink |

## Testing an unreleased build

`/local=<folder>` (or the `LERD_SETUP_LOCAL` environment variable) installs
lerd from a Windows folder holding `install.sh`, `lerd` and `lerd.exe` instead
of the latest release. `make build` in lerd-wsl
leaves `lerd` and `lerd.exe` in `build\`; copy `install.sh` beside them:

```powershell
dist\lerd-setup.exe /local=C:\path\to\lerd-wsl\build
```

The same folder can hold an unreleased desktop app: `npm run package:win` in
lerd-desktop leaves `lerd-desktop-win32-x64.zip` (and the arm64 one) in its
`dist\`; copy the one for the machine beside the rest. Setup takes the app from
there when it is present, and from the latest lerd-desktop release otherwise.

`..\lerd-test-vm` has double-click scripts for a Hyper-V test VM that roll back
to a clean Windows, or one with the WSL features already enabled, and copy the
installer (and a local build) into it.
