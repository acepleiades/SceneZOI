# Investigation notes

Short records of problems reproduced while building SceneZOI. Each note separates
observations, tested explanations, authoring guidance, and remaining uncertainty.
Findings describe the tested game assets and historical experiments; they are not universal
guarantees for future inZOI versions or replacement bodies.

The technical prototype and Maya authoring validation are complete. Treat the
rigs/exporters as production-ready; reopen accuracy investigations when a concrete
problem appears. Active work is the [SceneZOI first release](../../README.md), with independent HZoi content. Historical test names and rates do not define
the new production inventory.

| Note | Main finding |
| --- | --- |
| [Participant selection options](participant-selection-options.md) | Native and custom approaches that avoid changing gameplay groups; verified API gaps and proof criteria. |
| [Runtime and UI issue ledger](runtime-and-ui-issues.md) | Concise symptoms, findings, fixes and regression constraints for lifecycle, outfits, attachments, gaze, entry, reloads and packaging. |
| [Portable anatomy assets and bind pose](portable-anatomy-assets.md) | Moving assets across package roots needs reference remapping; FBX reimport needed the tested mesh's bind transforms restored. |

For future notes, record the date, symptom, isolated comparison, practical result,
and limits. Prefer measured evidence and relevant source documentation. Keep
private machine paths, personal save data, proprietary asset dumps, and large
diagnostic binaries out of these public notes.
