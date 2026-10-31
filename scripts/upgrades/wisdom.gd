extends RefCounted
class_name Wisdom

# Quotes shown at the top of the upgrade screen, for the element of the snake that won
# the previous round ("any" when nobody won). PLACEHOLDERS: short paraphrases in the
# spirit of each source, not exact quotes. Edit, add or replace them freely; each entry
# is {"text", "source"}.

const QUOTES = {
	"fire": [
		{"text": "Strike when the moment opens. Hesitation is the only wall.", "source": "after Miyamoto Musashi, The Book of Five Rings"},
		{"text": "The Warrior serves something larger than himself, and burns only what must burn.", "source": "after Moore & Gillette, King, Warrior, Magician, Lover"},
		{"text": "What you do not bring to light rules you from the dark.", "source": "after C. G. Jung"},
		{"text": "Solve et coagula: dissolve, then make whole again.", "source": "alchemical maxim"},
		{"text": "From the ashes, the same bird, but wiser.", "source": "Phoenix legend"},
	],
	"earth": [
		{"text": "Heavy is the root of light; stillness is the master of restlessness.", "source": "after Lao Tzu, Tao Te Ching"},
		{"text": "Know the ground before you step on it, and let it fight for you.", "source": "after Miyamoto Musashi, The Book of Five Rings"},
		{"text": "The King orders the realm so that everything in it may grow.", "source": "after Moore & Gillette, King, Warrior, Magician, Lover"},
		{"text": "As above, so below.", "source": "Hermetic maxim"},
		{"text": "A tree as wide as your arms grows from a tiny sprout.", "source": "after Lao Tzu, Tao Te Ching"},
	],
	"air": [
		{"text": "The way is in training: see what cannot be seen at a glance.", "source": "after Miyamoto Musashi, The Book of Five Rings"},
		{"text": "The Magician knows the hidden rules, and moves through what others think is solid.", "source": "after Moore & Gillette, King, Warrior, Magician, Lover"},
		{"text": "The space between the spokes is what makes the wheel useful.", "source": "after Lao Tzu, Tao Te Ching"},
		{"text": "Who looks outside, dreams; who looks inside, awakes.", "source": "after C. G. Jung"},
		{"text": "Know thyself.", "source": "inscription at Delphi"},
	],
	"water": [
		{"text": "Nothing is softer than water, yet nothing is better at wearing down the hard.", "source": "after Lao Tzu, Tao Te Ching"},
		{"text": "Become like water: take the shape of whatever holds you.", "source": "after Miyamoto Musashi, The Book of Five Rings"},
		{"text": "The Lover feels the whole world as one living thing.", "source": "after Moore & Gillette, King, Warrior, Magician, Lover"},
		{"text": "The meeting of two people is like two substances touching: both are changed.", "source": "after C. G. Jung"},
		{"text": "Anyone knows the drop is in the sea; the wise know the sea is in the drop.", "source": "Pune lesson"},
	],
	"any": [
		{"text": "When nobody wins, the board teaches everyone.", "source": "Pune proverb"},
		{"text": "Do nothing that is of no use.", "source": "after Miyamoto Musashi, The Book of Five Rings"},
		{"text": "The journey of a thousand miles begins beneath one's feet.", "source": "after Lao Tzu, Tao Te Ching"},
	],
}

const ELEMENTS = {1: "fire", 2: "earth", 3: "air", 4: "water"}

# A random quote for the snake (player id) that won; 0 or unknown -> "any"
static func for_winner(player_id) -> Dictionary:
	var element = ELEMENTS.get(player_id, "any")
	var pool = QUOTES.get(element, QUOTES.any)
	return pool[randi() % pool.size()]
