@tool
extends EditorPlugin
## Плагин Android «MyRappelzDownload» (формат Godot v2): при экспорте под Android добавляет в Gradle-сборку AAR
## с фоновой загрузкой пакета ресурсов через DownloadManager (Assets.download_plugin, AssetLoader).
## AAR собирается только при сборке APK (.github/workflows/android-apk.yml, исходники —
## android/plugins/myrappelz_download) и в репозитории не хранится. Нет AAR (проверка кода, редактор Максима) —
## плагин в экспорт не попадает, Gradle-сборка не нужна, игра качает пакет по-старому (HTTPRequest).

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = DownloadExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
	_export = null


class DownloadExport:
	extends EditorExportPlugin

	const AAR := "res://addons/myrappelz_download/bin/myrappelz_download-release.aar"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid and FileAccess.file_exists(AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR])

	func _get_name() -> String:
		return "MyRappelzDownload"
