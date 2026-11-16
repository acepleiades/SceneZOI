# Release checks

Start with the [build and packaging steps](../development.md). Run the checks
that cover your change. Record the tested commit or ZIP and the result in the
PR or release notes.

| Check | What to verify |
| --- | --- |
| Source | Build the catalog and run the Lua, Python and UI suites. Use a regression for the reported failure where possible. |
| ModKit | Prepare the authoritative Lua and validate Lua and both UI apps. Use the filtered output from an isolated export. |
| Clean install | Install the exact release ZIP without old SceneZOI configuration. Start inZOI normally, open the solo launcher and the picker on supported furniture, then play, navigate, Exit and re-enter. |
| Update | Install the same ZIP over a previous release and verify that user preferences carry over. |
| Native changes | Check the affected result in game. For lifecycle changes, try movement or reusing the furniture after Exit. For presentation, check what the player sees or hears. |

A test fixture can confirm logic, and native diagnostics can confirm a game
state or acknowledgement. Use a live check for timing, mesh fit, sound and
input. If a check is pending, say which one.

See [GitHub Releases](https://github.com/acepleiades/SceneZOI/releases) for shipped
changes. The former [validation reports](https://github.com/acepleiades/SceneZOI/tree/e0cb40d64bb8c313d5c7309c3c5605b231569892/docs/validation)
and [1.3.8 report](https://github.com/acepleiades/SceneZOI/blob/e0cb40d64bb8c313d5c7309c3c5605b231569892/validation.json)
are available at the commit that recorded them.
