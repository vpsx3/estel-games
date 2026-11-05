class_name CameraRig
extends Camera2D
## Camera. Porta CAM_CONFIG, resizeCanvas (pxPerWorld), cameraTarget e centerCameraOnBear.
##  - zoom: largura util = min(viewport.x, viewport.y * maxAspect); zoom = largura / (tilesAcross * TILE)
##  - alvo: centra no urso e trava nas bordas do mapa; se a vista for >= mapa, centraliza o mapa
##  - suavizacao: JS = cam += (alvo - cam) * smooth POR FRAME @60fps; aqui alpha = 1 - (1-smooth)^(dt*60)
## Tier: Device.tier() ("mobile" | "desktop"), sobrescrevivel para teste.

var tier_override: String = ""
var top_left: Vector2 = Vector2.ZERO   # canto sup-esq da vista em px de mundo
var _ready_snap: bool = false


func _init() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false


static func cam_config(tier: String) -> Dictionary:
	return (GameState.constants["CAM_CONFIG"] as Dictionary)[tier] as Dictionary


static func zoom_for(viewport_px: Vector2, cfg: Dictionary) -> float:
	var pw: float = minf(viewport_px.x, viewport_px.y * float(cfg["maxAspect"]))
	return pw / (float(cfg["tilesAcross"]) * Units.TILE)


## Tamanho da vista em px de mundo.
static func view_world_size(viewport_px: Vector2, cfg: Dictionary) -> Vector2:
	return viewport_px / zoom_for(viewport_px, cfg)


## cameraTarget(): canto sup-esq alvo.
static func target_top_left(bear_pos: Vector2, view: Vector2) -> Vector2:
	var tx: float = (Units.WORLD_W - view.x) / 2.0 if view.x >= Units.WORLD_W else clampf(bear_pos.x - view.x / 2.0, 0.0, Units.WORLD_W - view.x)
	var ty: float = (Units.WORLD_H - view.y) / 2.0 if view.y >= Units.WORLD_H else clampf(bear_pos.y - view.y / 2.0, 0.0, Units.WORLD_H - view.y)
	return Vector2(tx, ty)


static func smooth_alpha(smooth: float, dt: float) -> float:
	return 1.0 - pow(1.0 - smooth, dt * 60.0)


func _cfg() -> Dictionary:
	return cam_config(tier_override if tier_override != "" else Device.tier())


func _apply(view: Vector2, z: float) -> void:
	zoom = Vector2(z, z)
	global_position = top_left + view / 2.0


## centerCameraOnBear(true)
func snap_to(bear_pos: Vector2) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var cfg: Dictionary = _cfg()
	var view: Vector2 = view_world_size(vp, cfg)
	top_left = target_top_left(bear_pos, view)
	_apply(view, zoom_for(vp, cfg))
	_ready_snap = true


## centerCameraOnBear(false)
func follow(bear_pos: Vector2, dt: float) -> void:
	if not _ready_snap:
		snap_to(bear_pos)
		return
	var vp: Vector2 = get_viewport_rect().size
	var cfg: Dictionary = _cfg()
	var view: Vector2 = view_world_size(vp, cfg)
	var t: Vector2 = target_top_left(bear_pos, view)
	top_left += (t - top_left) * smooth_alpha(float(cfg["smooth"]), dt)
	_apply(view, zoom_for(vp, cfg))
