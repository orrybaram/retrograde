extends State
class_name ClawState

## A state of the DORSAL ARM's claw (DorsalClaw). Each one owns where the wrist goes
## and what the jaws do while it is active.

var claw: DorsalClaw:
	get: return entity as DorsalClaw

## How long this state has run, s.
var t := 0.0

func enter() -> void:
	t = 0.0
	super.enter()

func process(delta: float) -> void:
	t += delta

static func ease_io(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0
