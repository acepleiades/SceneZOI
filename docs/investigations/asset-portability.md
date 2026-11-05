# Asset references and bind-pose preservation

These lessons came from an earlier native package-portability investigation.
They apply to author-owned assets; the old prototype and its separate asset
distribution are not framework inputs or public setup requirements.

- Copying a package to a different mod folder does not automatically rewrite
  internal object paths. Keep a consistent registered package root and use the
  supported editor rename/migration workflow to update dependencies.
- Check skeleton, animation, material, texture and soft preview references after
  migration. A successful file copy does not establish a self-contained package.
- Reimport can alter a mesh's local reference transforms. Compare reference pose
  and rendered/vertex results against the original, and test animation playback.
  Preserve the game's shared skeleton; repairs to author-owned geometry must not
  replace unrelated native resources.
- In the recorded material-slot workflow, editing a borrowed struct did not
  persist until it was assigned back into its owning array. Reloading assets
  caught that failure; do not infer persistence from an in-memory preview.
- Numerical comparisons and package/hash checks do not establish visual fit in
  every body or another author's mod. Record the actual tested configuration.

Use [developer setup](../installation.md), [package ownership](../package-split.md)
and [exact packaging](../development.md) for the current framework workflow.
Referenced Game/Engine assets are excluded from owned distribution payloads.
