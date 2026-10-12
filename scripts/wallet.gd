extends CanvasLayer

## The player's Phantom wallet on Solana Devnet (autoload Wallet). Web build
## only: the page's wallet_bridge.js (served by the exchange server in
## server/) is reached through JavaScriptBridge as window.AftersteelWallet.
## On desktop, or with no bridge, `available` is false and nothing here does
## anything - fishing and the shop behave as they always have.
##
## Connecting signs a one-time message (no transaction); the server checks it
## and from then on rolls this wallet's catches, so a Divine fish it hands out
## carries a claim the exchange can pay. Calls are asynchronous: each takes a
## Callable that gets the server's reply as a Dictionary ("ok" plus details).
##
## While connected, a small line in the top-right corner shows the short
## address and the Devnet balance.

signal changed

## Web build with the bridge loaded.
var available := false
var phantom := false
var connected := false
var connecting := false
var address := ""
## Devnet SOL; -1 until known.
var balance_sol := -1.0

## Set by tests in place of the page's bridge.
var bridge: Object
## JavaScript callbacks have to stay referenced until the page calls them.
var _pending: Array = []
var _hud: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 92

	if OS.has_feature("web"):
		bridge = JavaScriptBridge.get_interface("AftersteelWallet")

	refresh_flags()
	print("[Wallet] bridge %s, Phantom %s" % ["ready" if available else "unavailable", "found" if phantom else "not found"])
	_build_hud()


func _process(_delta: float) -> void:
	_hud.visible = connected and ObjectiveHUD.visible


## Re-reads whether the bridge and Phantom are there (Phantom injects itself
## a moment after the page loads).
func refresh_flags() -> void:
	available = bridge != null
	phantom = available and bool(bridge.hasPhantom())


func short_address() -> String:
	return address if address.length() <= 9 else "%s...%s" % [address.left(4), address.right(4)]


## "7xKX...9fQ2  1.2345 SOL" (Devnet).
func describe() -> String:
	return "%s  %s SOL" % [short_address(), "..." if balance_sol < 0.0 else "%.4f" % balance_sol]


## Phantom's connect and sign-in prompts. `on_done` gets the reply.
func connect_wallet(on_done := Callable()) -> void:
	refresh_flags()

	if not available or connecting:
		_done(on_done, {"ok": false, "error": "unavailable" if not available else "busy"})
		return

	connecting = true
	changed.emit()
	_call("connectWallet", [], func(r: Dictionary) -> void:
		connecting = false
		if r.get("ok", false):
			connected = true
			address = str(r.get("wallet", ""))
			balance_sol = float(r.get("balance", -1.0)) if r.get("balance") != null else -1.0
		changed.emit()
		_done(on_done, r))


func refresh_balance(on_done := Callable()) -> void:
	if not connected:
		_done(on_done, {"ok": false, "error": "not_signed_in"})
		return

	_call("refreshBalance", [], func(r: Dictionary) -> void:
		if r.get("ok", false):
			balance_sol = float(r.get("balance", balance_sol))
		elif r.get("error", "") == "not_signed_in":
			_lost()
		changed.emit()
		_done(on_done, r))


## The server rolls this cast's catch: {"divine": true, "fish", "claimId"}
## or {"divine": false} for the game to roll an ordinary fish itself.
func roll_catch(on_done: Callable) -> void:
	_call("rollCatch", [], on_done)


func land_catch(claim_id: String, on_done := Callable()) -> void:
	_call("landCatch", [claim_id], on_done)


func escape_catch(claim_id: String) -> void:
	_call("escapeCatch", [claim_id], Callable())


## Asks the server to pay a landed claim. Replies {"status": "paid",
## "signature", "explorer", "amountSol"} once the transfer is confirmed on
## Devnet, {"status": "pending", ...} while it is still confirming, or an
## error - and only "paid" means the fish has been paid for.
func redeem(claim_id: String, on_done: Callable) -> void:
	_call("redeemClaim", [claim_id], on_done)


func open_explorer(url: String) -> void:
	if available:
		bridge.openExplorer(url)


func _call(method: String, args: Array, on_done: Callable) -> void:
	if not available:
		_done(on_done, {"ok": false, "error": "unavailable"})
		return

	var handler := func(reply: Array) -> void:
		var data: Variant = JSON.parse_string(str(reply[0])) if reply.size() > 0 else null
		var result: Dictionary = data if data is Dictionary else {"ok": false, "error": "bad_reply"}
		if result.get("error", "") == "not_signed_in" and method != "connectWallet":
			_lost()
		_done(on_done, result)
	var callback: Variant = JavaScriptBridge.create_callback(handler) if OS.has_feature("web") else handler
	_pending.append(callback)
	# Dropped once answered, so the list stays short.
	if _pending.size() > 32:
		_pending.pop_front()
	bridge.callv(method, args + [callback])


## The server forgot the session (restart, expiry, account switch in Phantom).
func _lost() -> void:
	connected = false
	address = ""
	balance_sol = -1.0
	changed.emit()


func _done(on_done: Callable, result: Dictionary) -> void:
	if on_done.is_valid():
		on_done.call(result)


func _build_hud() -> void:
	_hud = Label.new()
	_hud.add_theme_font_override("font", load("res://Assets/UI/Fabled_Font.ttf"))
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_hud.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_hud.add_theme_constant_override("outline_size", 8)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.size = Vector2(1000, 40)
	_hud.position = Vector2(get_viewport().get_visible_rect().size.x - 1024, 18)
	_hud.hide()
	add_child(_hud)
	changed.connect(func() -> void: _hud.text = "Phantom %s  (Devnet)" % describe())
