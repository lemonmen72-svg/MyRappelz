class_name LoginScreen
extends CanvasLayer
## Экран входа в аккаунт (первый экран после пакета ресурсов): фон — главный арт Dark Pact, сверху логотип
## (MenuKit.KEY_ART, MenuKit.LOGO; нет файлов — тёмный фон и заголовок), поле логина (подставлен последний вошедший —
## Accounts.last_login), «Войти» — существующий аккаунт, «Создать аккаунт» — новый логин (правила
## Accounts.name_error, занятость). Пока только логин: пароль появится вместе с сервером.
## Аккаунт Dedok_max — с админ-панелью в настройках. Успешный вход — сигнал logged_in (main → выбор персонажа).
## Для тестов: try_login(text), try_create(text) — "" или причина отказа (она же в подписи error_label).

signal logged_in

## Высота логотипа для «Среднего» размера интерфейса.
const LOGO_H := 150.0

var login_edit: LineEdit
var error_label: Label


func _ready() -> void:
	var root := MenuKit.build_root(self, MenuKit.KEY_ART)
	var logo := MenuKit.logo(LOGO_H)
	if logo != null:
		root.add_child(logo)
	else:
		root.add_child(MenuKit.title("Dark Pact"))
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer_top)

	var center := CenterContainer.new()
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UiScale.px(520), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiScale.px(10)))
	panel.add_child(v)

	# Подпись «Логин» — в самом поле (placeholder): экран влезает в 720 px на «Крупном»
	v.add_child(MenuKit.label("Вход в игру", UiScale.FONT_NAME, MenuKit.GOLD))
	login_edit = MenuKit.line_edit("Логин", Accounts.last_login())
	login_edit.text_submitted.connect(func(_t: String) -> void: _on_login())
	v.add_child(login_edit)
	v.add_child(MenuKit.label(Accounts.NAME_RULES + ".", UiScale.FONT_SMALL, MenuKit.MUTED, true))
	error_label = MenuKit.label("", UiScale.FONT_BODY, MenuKit.BAD, true)
	v.add_child(error_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiScale.px(10)))
	v.add_child(row)
	var enter := MenuKit.main_button("Войти")
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enter.pressed.connect(_on_login)
	row.add_child(enter)
	var make := MenuKit.button("Создать аккаунт", UiScale.BUTTON_H + 4)
	make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	make.pressed.connect(_on_create)
	row.add_child(make)

	v.add_child(MenuKit.label("Аккаунт хранится на этом устройстве: до 4 персонажей, у каждого свой ник. Пароль и вход "
		+ "с сервера появятся к бета-тесту.", UiScale.FONT_SMALL, MenuKit.MUTED, true))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)


## Войти аккаунтом text. "" — вошли (сигнал logged_in), иначе причина.
func try_login(text: String) -> String:
	var err := Accounts.login(text)
	return _result(err)


## Создать аккаунт text и войти. "" — получилось, иначе причина.
func try_create(text: String) -> String:
	var err := Accounts.create(text)
	return _result(err)


func _result(err: String) -> String:
	if error_label != null:
		error_label.text = err
	if err == "":
		logged_in.emit()
	return err


func _on_login() -> void:
	try_login(login_edit.text)


func _on_create() -> void:
	try_create(login_edit.text)
