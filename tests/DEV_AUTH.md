# Same-PC EOS development test

Normal game launches use Connect Device-ID login. To give two source/editor
instances distinct identities on one PC, explicitly opt into Epic's Dev Auth
Tool with a different named account for each instance. This is development-only:
the source/editor Godot executable accepts these options; all exported builds,
including debug exports, reject them. Invalid options or a failed Dev Auth login
never fall back to Device-ID. Nothing in `eos.local.cfg` enables Dev Auth.

This is a fresh implementation using the installed EOSG Auth/Connect helpers.
[Chum's transport-spike notes](https://github.com/ImDarkly/loki/blob/master/docs/prd/eosg-transport-spike.md)
provide the test precedent; no Chum game code was copied.
[Epic's Dev Auth documentation](https://dev.epicgames.com/docs/epic-online-services/accounts-and-social/eos-epic-account-services/developer-authentication-tool)
describes the tool and named credentials.

## Prerequisites

1. Keep this game's EOS product/client configuration in ignored `eos.local.cfg`.
2. Run EOS Developer Authentication Tool locally on port **8081** (or supply its
   actual port below). The tool comes with the EOS SDK under `SDK/Tools`.
3. In the tool, sign in yourself with **two different Epic accounts**, naming
   them **host_user** and **client_user**. Two labels for the same account do
   not provide distinct players. Keep passwords/tokens out of chat and Git.
4. Use the existing portal setup first. This code requests only BasicProfile
   for Auth, then uses the Auth token internally for Connect/lobbies/P2P. Auth
   may require Epic Account Services configuration in addition to working
   Device-ID/Connect. Capture the exact Auth/Connect failure before considering
   any portal changes; this workflow does not change permissions.

## Launch from this repository in PowerShell

For two normal game windows, run these in separate terminals and then click
Host in the first and Join in the second:

```powershell
$engine = 'C:/Godot/Godot_v4.6.2-stable_win64.exe'
& $engine --path . -- --dev-auth=host_user --dev-auth-server=localhost:8081
& $engine --path . -- --dev-auth=client_user --dev-auth-server=localhost:8081
```

Alternatively, this test-only launcher initiates the real EOS room flow:

```powershell
# First terminal: wait for the room code in the host window.
& $engine --path . --script tests/dev_auth_demo.gd -- --role=host --dev-auth=host_user --dev-auth-server=localhost:8081

# Second terminal: replace ABCDEF with the code displayed by the host.
& $engine --path . --script tests/dev_auth_demo.gd -- --role=client --room-code=ABCDEF --dev-auth=client_user --dev-auth-server=localhost:8081
```

These are EOS runs, not the ENet localhost demo. Both accounts must resolve to
different Product User IDs before treating them as two players. The launcher
writes only IDs and session status to ignored `build/dev-auth-host.json` and
`build/dev-auth-client.json`; it never writes access tokens or client credentials.
Compare those PUIDs locally and verify both windows report two players. Check
input ownership, shared movement/reset and host departure. Do not interpret a
successful same-PC run as a cross-device/Internet playtest.

To return to player login, launch without the Dev Auth options. The saved
Device-ID identity is never deleted, transferred or linked by this development
path. No tool installation, account sign-in UI or portal edits are automated.

## Offline checks

```powershell
& 'C:/Godot/Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script tests/check_dev_auth.gd
```

Checks normal defaults, account selection, loopback endpoint validation,
malformed/duplicate options, export rejection, and no fallback/initialization
for rejected options. It does not contact EOS or Dev Auth Tool.
