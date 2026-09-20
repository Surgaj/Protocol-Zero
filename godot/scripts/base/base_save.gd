extends RefCounted

const PATH: String = "user://czi07_base_v1.json"

static func write(data: Dictionary, path: String = PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read_data(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 262144:
		return {}
	var value = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}
