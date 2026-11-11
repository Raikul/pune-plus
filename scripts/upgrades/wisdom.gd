extends RefCounted
class_name Wisdom

# Quotes shown at the top of the upgrade screen, for the element of the snake that won
# the previous round ("any" when nobody won). PLACEHOLDERS: short paraphrases in the
# spirit of each source, not exact quotes. Edit, add or replace them freely; each entry
# is {"text", "source"}, both translation keys
# (translations/strings.csv: WISDOM_<ELEMENT>_<N> and WISDOM_SRC_*); show them with tr().

const QUOTES = {
	"fire": [
		{"text": "WISDOM_FIRE_1", "source": "WISDOM_SRC_MUSASHI"},
		{"text": "WISDOM_FIRE_2", "source": "WISDOM_SRC_MOORE"},
		{"text": "WISDOM_FIRE_3", "source": "WISDOM_SRC_JUNG"},
		{"text": "WISDOM_FIRE_4", "source": "WISDOM_SRC_ALCHEMY"},
		{"text": "WISDOM_FIRE_5", "source": "WISDOM_SRC_PHOENIX"},
	],
	"earth": [
		{"text": "WISDOM_EARTH_1", "source": "WISDOM_SRC_LAO_TZU"},
		{"text": "WISDOM_EARTH_2", "source": "WISDOM_SRC_MUSASHI"},
		{"text": "WISDOM_EARTH_3", "source": "WISDOM_SRC_MOORE"},
		{"text": "WISDOM_EARTH_4", "source": "WISDOM_SRC_HERMETIC"},
		{"text": "WISDOM_EARTH_5", "source": "WISDOM_SRC_LAO_TZU"},
	],
	"air": [
		{"text": "WISDOM_AIR_1", "source": "WISDOM_SRC_MUSASHI"},
		{"text": "WISDOM_AIR_2", "source": "WISDOM_SRC_MOORE"},
		{"text": "WISDOM_AIR_3", "source": "WISDOM_SRC_LAO_TZU"},
		{"text": "WISDOM_AIR_4", "source": "WISDOM_SRC_JUNG"},
		{"text": "WISDOM_AIR_5", "source": "WISDOM_SRC_DELPHI"},
	],
	"water": [
		{"text": "WISDOM_WATER_1", "source": "WISDOM_SRC_LAO_TZU"},
		{"text": "WISDOM_WATER_2", "source": "WISDOM_SRC_MUSASHI"},
		{"text": "WISDOM_WATER_3", "source": "WISDOM_SRC_MOORE"},
		{"text": "WISDOM_WATER_4", "source": "WISDOM_SRC_JUNG"},
		{"text": "WISDOM_WATER_5", "source": "WISDOM_SRC_PUNE_LESSON"},
	],
	"void": [
		{"text": "WISDOM_VOID_1", "source": "WISDOM_SRC_HEART_SUTRA"},
		{"text": "WISDOM_VOID_2", "source": "WISDOM_SRC_NIETZSCHE"},
		{"text": "WISDOM_VOID_3", "source": "WISDOM_SRC_LAO_TZU"},
	],
	"any": [
		{"text": "WISDOM_ANY_1", "source": "WISDOM_SRC_PUNE_PROVERB"},
		{"text": "WISDOM_ANY_2", "source": "WISDOM_SRC_MUSASHI"},
		{"text": "WISDOM_ANY_3", "source": "WISDOM_SRC_LAO_TZU"},
	],
}

const ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water", 5: "void"}

# A random quote for the snake (player id) that won; 0 or unknown -> "any"
static func for_winner(player_id) -> Dictionary:
	var element = ELEMENTS.get(player_id, "any")
	var pool = QUOTES.get(element, QUOTES.any)
	return pool[randi() % pool.size()]
