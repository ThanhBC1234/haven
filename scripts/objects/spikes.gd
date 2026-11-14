class_name Spikes
extends Area2D
## Một ô gai. Bóng chạm vào là bị thương. Gốc tọa độ ở giữa đáy ô.
## Trong bản đồ chữ: ^ là gai mọc từ đất, v là gai treo trên trần (xoay 180 độ).

@export var show_placeholder := true


## Nối tín hiệu: có vật thể chạm vào vùng gai.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Ball:
		body.take_hit()


## Hình tạm: 2 chiếc gai trong một ô.
func _draw() -> void:
	if not show_placeholder:
		return
	for x in [-16.0, 0.0]:
		var tri := PackedVector2Array([Vector2(x, 0), Vector2(x + 8, -16), Vector2(x + 16, 0)])
		draw_colored_polygon(tri, Color("#b9c4b0"))
		draw_polyline(tri, Color("#2a3328"), 1.5)
