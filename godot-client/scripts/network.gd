extends Node

# Network layer — stubs out all server calls for the local alpha.
# Set LOCAL_MODE = false and configure SERVER_URL to connect to the backend.
#
# Socket.io protocol note: Godot's WebSocketPeer uses raw WebSocket.
# The backend will need to support raw WS or this layer needs a Socket.io handshake.
# For the alpha, LOCAL_MODE = true so none of this connects.

const LOCAL_MODE  := true
const SERVER_URL  := "ws://localhost:3000"

var _socket: WebSocketPeer
var _connected := false

func _ready() -> void:
	if not LOCAL_MODE:
		_connect()

func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				print("[Network] Connected to server")
			while _socket.get_available_packet_count():
				_handle_packet(_socket.get_packet())
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				print("[Network] Disconnected from server")

func _connect() -> void:
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(SERVER_URL)
	if err != OK:
		push_error("[Network] Failed to connect: %s" % error_string(err))

func send(event: String, data: Dictionary) -> void:
	if LOCAL_MODE:
		return
	if _socket and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var payload := JSON.stringify({ "event": event, "data": data })
		_socket.send_text(payload)
	else:
		push_warning("[Network] Cannot send '%s' — not connected" % event)

func _handle_packet(raw: PackedByteArray) -> void:
	var text := raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var event: String = parsed.get("event", "")
	var data: Dictionary = parsed.get("data", {})
	_dispatch(event, data)

func _dispatch(event: String, data: Dictionary) -> void:
	match event:
		"object:state_change":
			# TODO: spawn or remove world objects based on server state
			pass
		"throw:result":
			# TODO: play throw animation, apply damage from server-authoritative value
			pass
		"lift:update":
			# TODO: show cooperative lift progress meter
			pass
		_:
			push_warning("[Network] Unknown event: %s" % event)
