# Translations

The game ships in English (default and fallback), Spanish (`es`) and Simplified Chinese
(`zh_CN`). The player picks one in **Options > Gameplay > Language**; it is saved as
`game/language` in `user://settings.cfg` (`Global.language`, `Global.apply_language()`).

## Where the text lives

`translations/strings.csv` is the only translation file:

```
keys,en,es,zh_CN
MENU_PLAY,Play,Jugar,开始游戏
HUD_FIRST_TO,FIRST TO %d,PRIMERO A %d,先得 %d 分
```

Godot imports it into `strings.<locale>.translation` files next to it (registered in
Project Settings > Localization > Translations). Edit the CSV in a spreadsheet or a text
editor (UTF-8, quote cells that contain commas or line breaks; `\n` also works as a line
break) and the editor reimports it.

## Using keys

- **Scenes**: put the key in the node's `text` (or `placeholder_text`, `tooltip_text`).
  Labels and buttons translate it themselves and follow language changes live.
- **Code**: `label.text = "SETUP_MATCH"` works the same way for a plain key. Anything put
  together in code goes through `tr()`: `tr("MATCH_POINTS") % points`. Static functions
  use `TranslationServer.translate("KEY")`.
- Text built with `tr()` doesn't update by itself when the language changes. Screens that
  can be open at that moment refresh in `_notification(NOTIFICATION_TRANSLATION_CHANGED)`
  (Options rebuilds itself; player setup, the HUD and the main menu refresh their texts).
- Keep the same `%d` / `%s` placeholders in every language.

## Keys built from data

| Text | Key |
| --- | --- |
| Upgrades (`upgrade_catalog.gd`) | `UPG_<ID>`, `UPG_<ID>_DESC`; rarities `RARITY_<NAME>` |
| Upgrade-screen quotes (`wisdom.gd`) | `WISDOM_<ELEMENT>_<N>`, sources `WISDOM_SRC_*` |
| Arenas (`levels/*.tscn`) | `LEVEL_<FILE NAME>`, e.g. `LEVEL_TWIN_BLOCKS` (falls back to the file name) |
| Match stats / awards | `STAT_<STAT>`, `AWARD_<TITLE>` and `AWARD_<TITLE>_DESC` |
| Elements | `ELEMENT_FIRE` ("Fire") and `ELEMENT_FIRE_UPPER` ("FIRE") |
| AI names | `AI_<NAME>` (`Global.AI_NAMES`) |

A new upgrade, arena, stat or award needs its rows in the CSV; a missing key shows up as
the key itself on screen (arenas show their file name instead).

## Adding a language

Add a column named after the locale (e.g. `fr`) to the CSV, reimport, add the generated
`strings.fr.translation` to Project Settings > Localization > Translations, and add
`["fr", "Français"]` to `Global.LANGUAGES`. The fonts have no CJK glyphs: Chinese text
uses the system's fallback font (Microsoft YaHei on Windows).
