# Workshop Zero - Environment

Machine status recorded during **BOOTSTRAP-001**.
No usernames, credentials or API keys are recorded here on purpose.

Generated from `scripts/doctor.ps1` plus the verification commands below.

## Machine

```text
OS            Windows 10/11 (build 26200)
Shell         Windows PowerShell 5.1.26100.9549
              (PowerShell 7 / pwsh is not installed; all scripts target 5.1+)
Package mgr   winget 1.29.380
```

## Tool status

| Tool             | Detected | Version                     | Action taken                                    |
| ---------------- | -------- | --------------------------- | ----------------------------------------------- |
| Git              | Yes      | 2.55.0.windows.3            | Already present. Nothing installed.             |
| Git LFS          | Yes      | 3.7.1                       | Already present. Ran `git lfs install` (hooks). |
| winget           | Yes      | 1.29.380                    | Already present. Used only if a base tool is missing. |
| Rokit            | Yes      | 1.2.0                       | Installed via the official `rojo-rbx/rokit` PowerShell installer. |
| Rojo             | Yes      | 7.7.0                       | Pinned and installed by Rokit (`rokit add rojo-rbx/rojo@7.7.0`). |
| Wally            | Yes      | 0.3.2                       | Pinned and installed by Rokit (`UpliftGames/wally@0.3.2`). |
| Selene           | Yes      | 0.31.0                      | Pinned and installed by Rokit (`Kampfkarren/selene@0.31.0`). |
| StyLua           | Yes      | 2.5.2                       | Pinned and installed by Rokit (`JohnnyMorganz/StyLua@2.5.2`). |
| Luau LSP         | Yes      | 1.70.1                      | Pinned and installed by Rokit (`JohnnyMorganz/luau-lsp@1.70.1`). |
| Blender          | Yes      | 5.2.0 LTS                   | Already present. `blender.exe --version` works. |
| Roblox Studio    | Yes      | `version-6b0e880a1a144428`  | Already present under `%LOCALAPPDATA%\Roblox\Versions\`. Nothing installed. |
| Rojo Studio plugin | Yes    | `RojoManagedPlugin.rbxm`    | Installed with `rojo plugin install` into `%LOCALAPPDATA%\Roblox\Plugins`. |

Tool paths, without any user-specific detail:

```text
Rokit shims        %USERPROFILE%\.rokit\bin        (added to the user PATH by Rokit)
Roblox Studio      %LOCALAPPDATA%\Roblox\Versions\<version>\RobloxStudioBeta.exe
Studio plugins     %LOCALAPPDATA%\Roblox\Plugins\
Blender            %ProgramFiles%\Blender Foundation\Blender 5.2\blender.exe
```

## Notes and gotchas

- **PATH timing.** Rokit added `%USERPROFILE%\.rokit\bin` to the *user* PATH.
  Terminals that were already open before installation keep their old PATH, so
  they will not see `rojo`, `selene`, `stylua`, `wally` or `luau-lsp` until they
  are reopened. `scripts\_tools.ps1` handles this by adding that folder for its
  own process, so the project scripts work in an old window as well.
- **Blender is installed but not on PATH.** The doctor script finds it under
  `%ProgramFiles%\Blender Foundation\` without requiring a PATH change.
- **Nothing was downloaded from a mirror.** Rokit, Rojo, Wally, Selene, StyLua
  and luau-lsp all came from their official GitHub repositories through Rokit.
- **No Roblox credentials were used.** Studio is a manual, human step: install
  and sign in through the official Creator Hub pages only.
- **No Hyper3D / Rodin API key was requested or stored.** `.env.example`
  contains an empty `RODIN_API_KEY=` placeholder and nothing else.

## Verified in this batch

```text
git --version                 ok    2.55.0.windows.3
git lfs version               ok    3.7.1
rokit --version               ok    1.2.0
rojo --version                ok    7.7.0
wally --version               ok    0.3.2
selene --version              ok    0.31.0
stylua --version              ok    2.5.2
luau-lsp --version            ok    1.70.1
blender --version             ok    5.2.0 LTS (full path)
stylua --check src            ok    no formatting differences
selene src                    ok    0 errors, 0 warnings, 0 parse errors
rojo build                    ok    build\WorkshopZero.rbxlx generated
rojo serve                    ok    listening on 127.0.0.1:34872, project "WorkshopZero"
rojo plugin install           ok    RojoManagedPlugin.rbxm in the Studio plugins folder
scripts\doctor.ps1            ok    exit 0
scripts\check.ps1             ok    exit 0
scripts\build.ps1             ok    exit 0, place seeded once
```

## Not verified by a human

No human has opened Roblox Studio and pressed Play during this batch.
The server/client bootstrap messages are therefore **not yet confirmed inside
Studio** - see the manual steps in `README.md` and at the end of the bootstrap
report.

## Manual steps that remain

```text
1. Install / sign into Roblox Studio if it is not signed in yet (Studio is
   present on this machine; sign-in state was not checked or changed).
2. Open place\WorkshopZeroPrototype.rbxlx in Roblox Studio.
3. Start scripts\dev.ps1.
4. Open the Rojo plugin and Connect.
5. Press Play and confirm both bootstrap lines in the Output window.
6. Save the place.
```

Optional, only if a terminal still cannot find `rojo` after a fresh restart:
check that `%USERPROFILE%\.rokit\bin` is present in the user PATH.
