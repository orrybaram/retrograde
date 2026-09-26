class_name LogTab
extends VBoxContainer

## One tab of the Log. A subclass owns its notch title, its bottom-border hint, its
## contents and whatever keys it wants; LogUI owns the frame, the notches and the
## cycling. Adding a tab is one subclass plus one entry in `LogUI.TABS`.
##
## The Log is the player's own instrument, read alone — no Automaton speaks from
## inside a tab (see CONTEXT.md).

## Keys the shell always offers, whichever tab is up, named for the device in use.
static func shell_keys() -> String:
	return "[%s] SWITCH   [%s] / [%s]  CLOSE" % [
		Controls.label(&"menu_tab_next"), Controls.label(&"open_log"), Controls.label(&"menu_back")]


## This tab's label in the top-left notch, e.g. "HOLD". A tab is a control, not a
## header, so it reads as a plain word — the window adds the `>` when it is selected.
func tab_title() -> String:
	return ""


## What the bottom border says while this tab is up. Own keys go before shell_keys().
func hint() -> String:
	return shell_keys()


## Redraw from current game state. Called on open, on switch, and whenever the
## ship, the hold, the bank or a Body's survey changes while the Log is open.
func refresh() -> void:
	pass


## Handle a menu action (`Controls.menu_action`) the shell did not claim. Return true to
## swallow it. The directions arrive here; only the Map tab claims LEFT / RIGHT, to drive its mark.
func handle_action(_action: StringName) -> bool:
	return false


func on_shown() -> void:
	pass


func on_hidden() -> void:
	pass
