extends Node
class_name Backend

@export var base_url: String = "https://your-api.example.com"
@onready var http := HTTPRequest.new()

func _ready() -> void:
	add_child(http)

func post_contract_contribution(player_id: String, contract_id: String, kind: String, qty: int) -> void:
	var url = "%s/contracts/%s/contrib" % [base_url, contract_id]
	var body = JSON.stringify({
		"player_id": player_id,
		"item": kind,
		"qty": qty
	})
	var headers = ["Content-Type: application/json"]
	http.request(url, headers, HTTPClient.METHOD_POST, body)

func fetch_daily_contracts() -> void:
	http.request("%s/contracts/daily" % base_url)
