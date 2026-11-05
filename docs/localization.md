# Player-facing localization

SceneZOI selects the game's display language on runtime/save-load initialization,
on every session start and before opening its native participant picker. An idle
two-second check also updates entry text after an Options language change. The UI
reads the current game setting when its view loads and before each new session.
Changing language does not change IDs, compatibility, task progress, preferences
or session ownership. Immediate translation of an already-running scene is not a
contract; a new session refreshes its presentation.

## Included languages

| Culture | Language |
| --- | --- |
| `en-US` | English |
| `ko-KR` | Korean |
| `zh-CN` | Simplified Chinese |
| `zh-TW` | Traditional Chinese |
| `ja-JP` | Japanese |
| `ru-RU` | Russian |
| `es-ES` | Spanish (Spain) |
| `pt-BR` | Portuguese (Brazil) |
| `pt-PT` | Portuguese (Portugal) |
| `de-DE` | German |
| `fr-FR` | French |
| `it-IT` | Italian |
| `pl-PL` | Polish |
| `tr-TR` | Turkish |
| `nl-NL` | Dutch |

These are the 15 entries returned by the current retail
`gameplay.list_languages` command. The ModKit Language workspace's culture picker
can have an older list; it is not required for this JSON transport. Short language
codes and underscore separators are normalized. An unsupported language falls
back to English.

## Add translations to a content pack

Add an ordinary inert declaration to the pack manifest:

```json
{"kind":"localization","file":"designer/localization/text.json"}
```

The file contains one schema-1 document:

```json
{
  "schema_version": 1,
  "id": "designer.localization",
  "translations": {
    "en-US": {
      "labels": {
        "scene.designer.hub": "Standing embrace",
        "navigation.designer.hub.return": "Return...",
        "scene_task.designer.calm": "Calm"
      }
    },
    "fr-FR": {
      "labels": {
        "scene.designer.hub": "Étreinte debout",
        "navigation.designer.hub.return": "Retour...",
        "scene_task.designer.calm": "Calme"
      }
    }
  }
}
```

Only translate display text. Keep the original scene/definition `label` in English
as its final fallback. A pack can provide any subset of cultures or entries;
missing text falls back **per entry** to `en-US`, then to the original label. It
never substitutes another non-English language or displays a translation key.

| Label key | Display destination |
| --- | --- |
| `scene.<scene_id>` | Scene title and navigation captions using that destination's name |
| `navigation.<source_scene_id>.<edge_id>` | An explicit navigation caption, such as Return |
| `expression_set.<set_id>` | Expression-family picker |
| `voice_archetype.<archetype_id>` | Voice archetype picker |
| `voice_context.<context_id>` | Voice context heading |
| `voice_set.<set_id>` | Voice set choice |
| `scene_task.<task_id>` | Task tray caption |

The key uses the exact registered ID. An omitted/blank navigation caption still
uses the translated destination; an explicit caption has its own translation
key and English fallback. Translations do not alter the graph or navigation
restrictions. Labels in developer diagnostics and internal task/event data retain
their source meanings; IDs always remain stable.

The public [framework catalog](../packs/scenezoi/localization/text.json) supplies
all 15 cultures. The private optional integration pack supplies its own scene,
navigation, expression, voice and task labels through the same declaration
contract. It still ships no executable code.

## Framework messages and safety

Framework `translations.<culture>.messages` maps an English source message to
its translation, like a gettext message ID. This covers controls, panels, hints,
accessible labels, errors, toasts, scene-entry labels and picker headings. Do not
replace messages belonging to another author. Pack labels normally need only the
`labels` map above. Translate new framework messages in every included culture.

Named placeholders such as `{min}`, `{max}` and `{code}` must remain unchanged;
they may move within the translated sentence. Text is plain UTF-8, never HTML,
Lua or an expression. The UI escapes translated text before creating markup.
Malformed declarations and conflicting entries are diagnosed and rejected as
whole documents, independently of other contributions. Build validation fails
before generated output changes. Limits: 64 cultures/document, 2,048 entries per
map, 1,024 UTF-8 bytes/key, 4,096 bytes/translation, and the existing 1 MiB native
declaration limit. Use another namespaced declaration when necessary.

Player-written outfit names and proper names are preserved. Outfit categories
are translated, while raw asset IDs remain internal. Tags/actions, aliases,
clinical metadata, asset paths, role IDs, log messages and machine-readable
failure codes are not translated. The framework still uses the game's font CSS;
no font assets or content-pack scripts are added.

UI text controls must use the complete `var(--inzoi-font-ui)` stack directly
when overriding their font. The native stylesheet includes Japanese and
Simplified/Traditional Chinese CJK faces. A shortened `Pretendard, NotoSans`
override can render the title correctly while navigation and Exit show missing
glyph boxes. Valid UTF-8 text and successful language detection do not establish
that a control's chosen font can draw it.

## Verification

Source checks cover complete built-in culture/message sets, UTF-8, placeholder
parity, safe escaping, conflicts, independent English fallback, saved-language
refresh, custom names and navigation caption behavior. Existing playback,
settings, ownership and cleanup regressions remain. ModKit validation, package
hashes and actual in-game presentation are recorded separately in
[release validation](validation/README.md). Automated completeness does not
establish native-speaker review or visual fit in every language.
