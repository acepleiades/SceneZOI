# Investigation notes

Retained implementation findings support future maintenance; current contracts and
[release validation](../validation/README.md) take precedence over historical
experiments. Read the note relevant to a reproduced problem rather than treating
every old hypothesis or pending checkpoint as a current release requirement.

| Note | Purpose |
| --- | --- |
| [Runtime and UI issue ledger](runtime-and-ui-issues.md) | Reproducible failures, retained fixes and regression requirements. |
| [Participant selection options](participant-selection-options.md) | Historical API/approach comparison; the shipped picker is documented in [participant support](../group-support.md). |
| [Asset references and bind pose](asset-portability.md) | General native package/reference and reimport lessons, without a private asset dependency. |

For a new finding, record the trigger, direct observations, smallest fix, retained
regression and remaining limit. Keep raw probes, personal paths, private save data
and proprietary dumps outside public documentation. Do not reopen completed
animation-authoring investigations without a concrete defect.
