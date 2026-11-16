# Working on SceneZOI

Start with [CONTRIBUTING.md](CONTRIBUTING.md). Use the [source map](docs/architecture.md)
to find the code and tests for your change. Read the relevant contract before
changing a public API, schema or runtime lifecycle rule. For a bug, start with
the report and diagnostics, then use [runtime troubleshooting](docs/investigations/runtime-and-ui-issues.md)
if the symptom matches.

- Edit Lua in `modkit/SceneZOI_93C44199/workspace/lua/`; ModKit generates prepared
  `lua/`. UI source is under `modkit/SceneZOI_93C44199/ui/`, built-in
  declarations under `packs/`, and the public SDK under `sdk/`.
- SceneZOI is an all-ages framework. Packs own their JSON and assets. Gameplay
  add-ons own gameplay rules, persistence and consequences through the public API.
  Default builds and tests work without HZoi. Keep proprietary material and
  private logs out of public changes.
- Discover enabled declarations through native `Text_UI` patches (retail `Text`).
  Keep one JSON file per scene. Preserve existing API and schema compatibility.
  Localize player-facing text and keep English fallbacks.
- Keep rosters and role assignments fixed per session. The UI and autosave follow
  the controlled Zoi. Manual entry uses technical eligibility. Keep the game's
  animation instances, the native input handshake and independent cleanup.
  Leave Smart Zoi alone. [Runtime contracts](docs/tier1-contracts.md)

Run the checks relevant to the change. For runtime or authored data, start here:

```powershell
python tools/build_catalog.py
python tools/test.py --modkit-root "C:/Path/To/inZOIModKit"
```

For documentation-only changes, verify links, examples and formatting. See
[development and packaging](docs/development.md) before using the native project
or a live game. Use isolated packaging and test the filtered ZIP on a fresh
launch for releases. Keep raw logs local and put test results with the issue,
PR or release they support.

Preserve working changes, the license and attribution. Commit, push, tag or
publish only when asked.
