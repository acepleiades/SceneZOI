# Compatibility cleanup validation

Tested SceneZOI commit `a2e95c2` on November 16, 2026. The installed package
reported 1.3.12. HZoi 1.3.2 and VelvetZOI 0.13.0-alpha were enabled.

## Build and automated checks

- ModKit validated Lua and both UI apps with zero errors. The filtered package
  contained four framework animation assets and 110 protected Lua scripts.
  The three removed B2 modules were absent from the package and manifest.
- The full SceneZOI and HZoi Reference integration suite passed. The suite
  covers version 1 save-journal recovery, saved expression choices, and the
  established add-on API.
- The installed ZIP had SHA-256
  `78df819c8e271e70e7532bdc6880c91975739a1e418551e707d63c30d981f183`.

## In-game checks

- An existing save reached the ready state on a fresh game launch. The catalog
  reported all 86 scenes from SceneZOI, HZoi and VelvetZOI as playable.
- VelvetZOI started three autonomous sessions from its normal interaction.
  Auto-mode switched off and back on. Return reached HZoi Bed Idle, then the
  framework bed hub, and the VelvetZOI menu opened in the same session. Both
  Zois acknowledged preparation at each step, and there was no preparation
  timeout.
- All three exits cleared the recovery journal and released the same queen bed.
  VelvetZOI found and reused it on both repeat runs. The runtime history
  retained start, navigation and Exit records for the tests.
- The first run raised a visual question about the transition to HZoi Bed
  Idle. The game reported successful navigation. A follow-up from another
  bed scene visibly changed to the idle pose, and the maintainer could not
  reproduce the reported behavior in two attempts. The initial observation
  remains unconfirmed.

Autosave was suspended during the interactions and restored afterward. No manual
save was made.
