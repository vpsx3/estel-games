class_name Device
extends RefCounted
## Deteccao de plataforma (equivalente a IS_TOUCH / DEVICE do HTML).

static func is_web() -> bool:
	return OS.has_feature("web")


static func is_touch() -> bool:
	if OS.has_feature("mobile"):
		return true
	if is_web():
		# Mesmo criterio do HTML: pointer:coarse ou ontouchstart.
		return WebBridge.is_coarse_pointer()
	return DisplayServer.is_touchscreen_available()


## "mobile" ou "desktop" (chave de CAM_CONFIG).
static func tier() -> String:
	return "mobile" if is_touch() else "desktop"
