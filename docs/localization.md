# Translate your pack's names and messages

<a id="player-facing-localization"></a>

Add translations so players can read scene titles, navigation buttons, voice
choices and expression labels in their game's language. Keep the same internal
IDs: translating a label should not break navigation or saved choices.

1. Add a [localization file](#add-translations-to-a-content-pack) to your manifest.
2. Supply English fallback strings, then translations for the same keys. Scene
   and navigation keys use the IDs described below.
3. Build and install the pack, restart inZOI, choose a translated game language
   and start a new scene. Check the title, buttons and personality menus.

SceneZOI refreshes language on initialization, save load, session start and
before the participant picker. An idle check updates entry text after an Options
language change. Start a new session to check translated scene presentation;
an already-open session does not promise an immediate language refresh.

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
all 15 cultures. The public HZoi-Reference
[content catalog](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi/localization/text.json) supplies scene, navigation, expression,
voice and task labels through the same declaration contract. For example,
`scene.hzoi.standing_idle` names a scene, while
`navigation.hzoi.standing_idle.neutral` names its explicit Return edge. Follow
the [manifest registration](https://github.com/acepleiades/HZoi-Reference/blob/main/packs/hzoi.json) and
[English/Japanese excerpt](content-examples.md#find-other-examples)
to see the complete relationship. The reference shows how IDs connect declarations to player-facing text.

<a id="framework-messages-and-safety"></a>

## Framework messages and placeholders

Framework `translations.<culture>.messages` maps an English source message to
its translation, like a gettext message ID. This covers controls, panels, hints,
accessible labels, errors, toasts, scene-entry labels and picker headings. Do not
replace messages belonging to another author. Pack labels normally need only the
`labels` map above. Translate new framework messages in every included culture.

Named placeholders such as `{min}`, `{max}` and `{code}` must remain unchanged;
they may move within the translated sentence. Text is plain UTF-8, never HTML,
Lua or an expression. The UI escapes translated text before creating markup.
A malformed declaration is rejected as a document. If two valid packs
provide different text for the same language and key, the framework's
translation takes priority when present. Other entries still load. The
conflict report in `scenezoi_runtime/mod_inventory.cfg` identifies both
providers and the chosen one. Builds reject conflicts within the same pack.
A declaration can register 64 cultures and 2,048 entries per map. Keys can
be up to 1,024 UTF-8 bytes and values up to 4,096 bytes. Use another
namespaced declaration if you reach the 1 MiB native limit.

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

The source checks catch malformed declarations, missing framework translations,
changed placeholders and fallback/conflict errors. They cannot tell whether a
translation reads naturally or fits the actual control. Have a speaker of the
language review the wording, then check it in game.

## Check a translation

Try English and a translated language, including a key you intentionally leave
untranslated. The missing translation should use the fallback. Check long
navigation labels and voice/expression choices in the actual panels. Keep any
format placeholders intact so names and values still appear.

If another pack defines the same language and key, conflict handling keeps a
winner for that key while accepting unrelated strings. Check the localization
warnings in `scenezoi_runtime/mod_inventory.cfg` for owners and the winner;
changing file load order is not a reliable fix. Coordinate shared strings with
the other author through the [community Discord](https://discord.gg/RECvhVaRcU).
