# lerd-setup.exe (Inno Setup)

A wizard installer for lerd on Windows. It does what `lerd.exe --setup`
(`cmd/lerd-windows/setup.go`) does, in a native wizard:

1. Enables the WSL features and offers the restart they need; Setup resumes at
   the next login through `RunOnce`.
2. Installs WSL from github.com/microsoft/WSL, then the `Ubuntu-24.04` distro.
3. Creates the Linux user from the wizard's username and password page.
4. Installs Podman and the packages `install.sh` checks for, and turns on
   linger: with no terminal, `install.sh`'s offer to do both reads as "no".
   Then it runs `install.sh` and `lerd wsl:setup`. With no terminal to type a
   password in, the user has passwordless sudo only while these run. The
   package list lives in `InstallPackages` in `lerd.iss`; keep it in step with
   `install.sh`.
5. Restarts WSL and waits for the dashboard.

Every step checks before it acts, so running Setup again resumes where it
stopped. The log is in `%TEMP%\Setup Log *.txt`.

Uninstalling from Add/Remove Programs asks whether to keep the distro, which
runs `lerd uninstall --keep-data` inside it, or to delete it altogether.

## Build

```powershell
winget install JRSoftware.InnoSetup
.\build.ps1                      # -> dist\lerd-setup.exe
.\build.ps1 -Version 1.30.0      # version shown in Add/Remove Programs
```

`build.ps1` reads the logo and license from `..\lerd-wsl` (`-LerdRepo` to
change it).

## Testing a local build

`/local=<folder>` installs lerd from a Windows folder holding `install.sh`,
`lerd` and `lerd.exe` instead of the latest release:

```powershell
dist\lerd-setup.exe /local=C:\path\to\lerd-wsl\build
```
