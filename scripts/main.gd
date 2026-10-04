extends Control

const CREAM = Color("fff5e4")
const INK = Color("224e51")
const TEAL = Color("356e70")
const CORAL = Color("d07d62")
const GOLD = Color("e0ba79")
const FONT = preload("res://assets/fonts/NotoSansCJKtc.otf")
var story: Dictionary = {}
var nodes: Dictionary = {}
var art: Dictionary = {}
var state: Dictionary = {}
var profile: Dictionary = {"read": {}, "endings": {}, "speed": 42.0, "volume": 0.35, "muted": false}
var canvas: Control
var scene_bg: TextureRect
var portrait: TextureRect
var title_layer: Control
var play_layer: Control
var chapter_label: Label
var speaker_label: Label
var body_label: RichTextLabel
var choices_box: VBoxContainer
var next_button: Button
var mode_label: Label
var status_label: Label
var modal: Control
var music: AudioStreamPlayer
var sfx: AudioStreamPlayer
var current_id := ""
var in_game := false
var auto_mode := false
var skip_mode := false
var was_read := false
var elapsed := 0.0
var reveal := 0.0
var cooldown := 0.0
var current_texture := ""
var textures: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://data/story.json", FileAccess.READ)
	if file:
		story = JSON.parse_string(file.get_as_text())
	nodes = story.get("nodes", {})
	if FileAccess.file_exists("res://data/art.json"):
		art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art.json"))
	var loaded = _read_json("user://profile.json")
	if loaded is Dictionary:
		_sanitize_profile(loaded)
	_build_ui()
	resized.connect(_resize)
	_resize()
	_setup_audio()
	_show_title()
	var args = OS.get_cmdline_user_args()
	if "--self-test" in args:
		call_deferred("_self_test")
	if "--capture" in args:
		call_deferred("_capture", args)

func _style(color: Color, border := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	if border:
		s.set_border_width_all(2)
		s.border_color = GOLD
	return s

func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, action: Callable, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42 if small else 54
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18 if small else 22)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("829b92"))
	b.add_theme_stylebox_override("normal", _style(TEAL))
	b.add_theme_stylebox_override("hover", _style(Color("45878a"), true))
	b.add_theme_stylebox_override("pressed", _style(INK, true))
	b.add_theme_stylebox_override("focus", _style(Color("45878a"), true))
	b.add_theme_stylebox_override("disabled", _style(Color("d5dfd5")))
	b.pressed.connect(action)
	return b

func _rect(parent: Node, color: Color, rect: Rect2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _build_ui() -> void:
	_rect(self, INK, Rect2(0,0,10000,10000))
	canvas = Control.new()
	canvas.size = Vector2(1280,800)
	add_child(canvas)
	scene_bg = TextureRect.new()
	scene_bg.size = canvas.size
	scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas.add_child(scene_bg)
	_rect(canvas, Color(0.10,0.23,0.25,0.18), Rect2(0,0,1280,800))
	portrait = TextureRect.new()
	portrait.position = Vector2(10,100)
	portrait.size = Vector2(540,690)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(portrait)
	play_layer = Control.new()
	canvas.add_child(play_layer)
	var top = Panel.new()
	top.position = Vector2(28,22)
	top.size = Vector2(1224,78)
	top.add_theme_stylebox_override("panel", _style(Color(1,0.97,0.90,0.95)))
	play_layer.add_child(top)
	var brand = _label("潮汐書店  /  SEVEN LETTERS", 22)
	brand.position = Vector2(24,11)
	top.add_child(brand)
	chapter_label = _label("",17,TEAL)
	chapter_label.position = Vector2(24,44)
	top.add_child(chapter_label)
	status_label = _label("",17,TEAL)
	status_label.position = Vector2(650,27)
	top.add_child(status_label)
	var panel = Panel.new()
	panel.position = Vector2(510,124)
	panel.size = Vector2(742,584)
	panel.add_theme_stylebox_override("panel", _style(Color(1,0.97,0.91,0.97),true))
	play_layer.add_child(panel)
	var content = VBoxContainer.new()
	content.position = Vector2(28,22)
	content.size = Vector2(686,538)
	content.add_theme_constant_override("separation",12)
	panel.add_child(content)
	speaker_label = _label("",27,TEAL)
	content.add_child(speaker_label)
	body_label = RichTextLabel.new()
	body_label.custom_minimum_size.y = 170
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_override("normal_font",FONT)
	body_label.add_theme_font_size_override("normal_font_size",25)
	body_label.add_theme_color_override("default_color",INK)
	body_label.add_theme_constant_override("line_separation",9)
	body_label.scroll_active = true
	body_label.selection_enabled = false
	body_label.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	content.add_child(body_label)
	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation",9)
	content.add_child(choices_box)
	next_button = _button("繼續閱讀  ›",_advance)
	content.add_child(next_button)
	mode_label = _label("",15,TEAL)
	content.add_child(mode_label)
	var toolbar = HBoxContainer.new()
	toolbar.position = Vector2(28,730)
	toolbar.size = Vector2(1224,48)
	toolbar.add_theme_constant_override("separation",10)
	play_layer.add_child(toolbar)
	for item in [["存檔",func(): _slots(false)],["讀檔",func(): _slots(true)],["回顧",_history],["手帳",_journal],["自動",_toggle_auto],["已讀快進",_toggle_skip],["設定",_settings],["回標題",func(): _confirm("回到標題？進度已自動保存。",_show_title)]]:
		var b = _button(item[0],item[1],true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar.add_child(b)
	title_layer = Control.new()
	canvas.add_child(title_layer)
	var title_panel = Panel.new()
	title_panel.position = Vector2(52,100)
	title_panel.size = Vector2(630,625)
	title_panel.add_theme_stylebox_override("panel",_style(Color(1,0.97,0.90,0.95),true))
	title_layer.add_child(title_panel)
	var col = VBoxContainer.new()
	col.position = Vector2(40,32)
	col.size = Vector2(550,560)
	col.add_theme_constant_override("separation",15)
	title_panel.add_child(col)
	col.add_child(_label("A SMALL TOWN · A NEW CHAPTER",16,TEAL))
	col.add_child(_label("潮汐書店的\n七封信",48))
	var sub = _label("把心意說清楚，也把彼此留在自由裡。",20,TEAL)
	col.add_child(sub)
	col.add_child(_button("翻開第一封信",_new_game))
	col.add_child(_button("繼續旅程  /  讀取存檔",func(): _slots(true)))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	for item in [["結局書架",_gallery],["設定",_settings],["製作與說明",_credits]]:
		var b = _button(item[0],item[1],true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	col.add_child(row)
	col.add_child(_label("原創成年戀愛視覺小說 · 三條路線 · 七種結局",17,TEAL))
	col.add_child(_label("滑鼠／觸控操作  ·  空白鍵繼續  ·  Esc 選單",16,TEAL))

func _resize() -> void:
	if not is_instance_valid(canvas): return
	var factor = min(size.x/1280.0,size.y/800.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-Vector2(1280,800)*factor)/2

func _texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path): return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func _bg(key: String) -> void:
	var path: String = art.get("backgrounds",{}).get(key,art.get("backgrounds",{}).get("bookstore",""))
	scene_bg.texture = _texture(path)

func _show_title() -> void:
	_close_modal()
	in_game = false
	auto_mode = false
	skip_mode = false
	play_layer.hide()
	title_layer.show()
	_bg("bookstore")
	portrait.texture = _texture(art.get("characters",{}).get("lin",{}).get("smile",""))
	portrait.position = Vector2(720,100)
	portrait.size = Vector2(520,690)

func _new_game() -> void:
	state = {"node":story.get("start","c001"),"affection":{"lin":0,"su":0,"ye":0},"flags":[],"history":[],"visited":[],"letters":[]}
	_begin()

func _begin() -> void:
	_close_modal()
	in_game = true
	title_layer.hide()
	play_layer.show()
	portrait.position = Vector2(0,102)
	portrait.size = Vector2(530,685)
	auto_mode = false
	skip_mode = false
	_show_node(str(state.get("node",story.get("start","c001"))),false)

func _show_node(id: String, record := true) -> void:
	if not nodes.has(id):
		_info("故事資料錯誤","找不到段落："+id+"。請回報此段落代碼。")
		return
	current_id = id
	state["node"] = id
	var n: Dictionary = nodes[id]
	was_read = profile["read"].has(id)
	profile["read"][id] = true
	if not state["visited"].has(id): state["visited"].append(id)
	if record or state["history"].is_empty():
		state["history"].append({"speaker":str(n.get("speaker","旁白")),"text":str(n.get("text",""))})
	if n.has("letter") and not state["letters"].has(n["letter"]): state["letters"].append(n["letter"])
	_bg(str(n.get("bg","bookstore")))
	var character = str(n.get("character",""))
	portrait.texture = _texture(art.get("characters",{}).get(character,{}).get(str(n.get("expression","neutral")),""))
	portrait.visible = portrait.texture != null
	chapter_label.text = "第 %s 日  ·  %s" % [str(int(n.get("day",1))),str(n.get("chapter","潮聲與書頁"))]
	status_label.text = "互信記錄  芷晴 %s  ·  曼 %s  ·  禾寧 %s" % [state["affection"].get("lin",0),state["affection"].get("su",0),state["affection"].get("ye",0)]
	speaker_label.text = str(n.get("speaker","旁白"))
	body_label.text = str(n.get("text",""))
	body_label.visible_characters = 0
	body_label.scroll_to_line(0)
	reveal = 0.0
	elapsed = 0.0
	cooldown = 0.35
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()
	var choices: Array = n.get("choices",[])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var b = _button(str(i+1)+"  "+str(choice["text"]),_choose.bind(i))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 56
		choices_box.add_child(b)
	choices_box.visible = false
	next_button.visible = choices.is_empty() and not n.has("ending")
	mode_label.text = "點文字可顯示全文  ·  空白鍵繼續  ·  選項也可按 1 / 2 / 3"
	_save(0)
	_save_profile()
	if n.has("ending"):
		profile["endings"][str(n["ending"])] = true
		_save_profile()
		var end_button = _button("閱讀結局後記  ·  收進書架",_ending)
		choices_box.add_child(end_button)

func _process(delta: float) -> void:
	cooldown = max(0.0,cooldown-delta)
	if not in_game or is_instance_valid(modal): return
	var count = body_label.get_total_character_count()
	reveal += delta*float(profile.get("speed",42.0))
	body_label.visible_characters = min(int(reveal),count)
	var done = body_label.visible_characters >= count
	choices_box.visible = done
	for b in choices_box.get_children(): b.disabled = cooldown>0.0
	if done:
		elapsed += delta
		if skip_mode and was_read and not nodes[current_id].has("choices") and not nodes[current_id].has("ending") and elapsed>0.10:
			_advance()
		elif auto_mode and not nodes[current_id].has("choices") and not nodes[current_id].has("ending") and elapsed>max(2.5,count/12.0):
			_advance()
	if skip_mode:
		if was_read: reveal = count
		else:
			skip_mode = false
			mode_label.text = "已讀快進已停下：這是尚未閱讀的段落。"

func _advance() -> void:
	if not in_game or is_instance_valid(modal) or cooldown>0: return
	if body_label.visible_characters < body_label.get_total_character_count():
		reveal = body_label.get_total_character_count()
		body_label.visible_characters = int(reveal)
		return
	var n: Dictionary = nodes[current_id]
	if n.has("next") and not n.has("choices"):
		_ping()
		_show_node(str(n["next"]))

func _choose(index: int) -> void:
	if cooldown>0 or is_instance_valid(modal): return
	var choices: Array = nodes[current_id].get("choices",[])
	if index<0 or index>=choices.size(): return
	var c: Dictionary = choices[index]
	var effects: Dictionary = c.get("effects",{})
	for person in effects.get("affection",{}):
		state["affection"][person] = int(state["affection"].get(person,0))+int(effects["affection"][person])
	for flag in effects.get("flags",[]):
		if not state["flags"].has(flag): state["flags"].append(flag)
	state["history"].append({"speaker":"我的選擇","text":str(c["text"])})
	_ping()
	_show_node(str(c["next"]))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(modal): _close_modal()
			else: _settings()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _advance()
		elif in_game and choices_box.visible and not is_instance_valid(modal):
			if event.keycode>=KEY_1 and event.keycode<=KEY_3: _choose(event.keycode-KEY_1)

func _toggle_auto() -> void:
	auto_mode = not auto_mode
	skip_mode = false
	mode_label.text = "自動閱讀："+("開啟（選項處會停下）" if auto_mode else "關閉")

func _toggle_skip() -> void:
	if skip_mode:
		skip_mode = false
		mode_label.text = "已讀快進：關閉"
	else:
		_confirm("快進只略過曾讀過的段落，遇到新內容或選項會停下。開始？",func():
			skip_mode = true
			auto_mode = false)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func _write_json(path: String, data: Dictionary) -> bool:
	var f = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(data))
	f.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func _save(slot: int) -> void:
	if state.is_empty(): return
	var data = {"version":1,"state":state,"saved":Time.get_datetime_string_from_system(true)+"Z"}
	if not _write_json("user://slot_%s.json"%slot,data):
		mode_label.text = "提醒：存檔失敗，請確認裝置儲存空間／瀏覽器隱私設定。"

func _save_profile() -> void:
	_write_json("user://profile.json",profile)

func _sanitize_profile(loaded: Dictionary) -> void:
	for category in ["read","endings"]:
		if loaded.get(category) is Dictionary:
			for key in loaded[category]:
				var allowed: bool = nodes.has(key) if category=="read" else story.get("endings",{}).has(key)
				if allowed and loaded[category][key] == true: profile[category][key] = true
	if typeof(loaded.get("speed")) in [TYPE_INT,TYPE_FLOAT]: profile["speed"] = clampf(float(loaded["speed"]),15,150)
	if typeof(loaded.get("volume")) in [TYPE_INT,TYPE_FLOAT]: profile["volume"] = clampf(float(loaded["volume"]),0,1)
	if loaded.get("muted") is bool: profile["muted"] = loaded["muted"]

func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("state") is Dictionary: return false
	var st: Dictionary = data["state"]
	if not st.get("node") is String or not nodes.has(st["node"]): return false
	for key in ["history","visited","letters","flags"]:
		if not st.get(key) is Array or st[key].size()>20000: return false
	for entry in st["history"]:
		if not entry is Dictionary or not entry.get("speaker") is String or not entry.get("text") is String: return false
	for id in st["visited"]:
		if not id is String or not nodes.has(id): return false
	for id in st["letters"]:
		if not id is String or not story.get("letters",{}).has(id): return false
	for flag in st["flags"]:
		if not flag is String: return false
	if not st.get("affection") is Dictionary or st["affection"].size()!=3: return false
	for person in ["lin","su","ye"]:
		if typeof(st["affection"].get(person)) not in [TYPE_INT,TYPE_FLOAT]: return false
		if abs(float(st["affection"][person]))>10000: return false
	return true

func _load_slot(slot: int) -> void:
	var data = _read_json("user://slot_%s.json"%slot)
	if not _valid_save(data):
		_info("無法讀取","此存檔不存在或格式無效。")
		return
	state = data["state"].duplicate(true)
	for key in ["history","visited","letters","flags"]:
		if not state.has(key): state[key] = []
	if not state.has("affection"): state["affection"] = {"lin":0,"su":0,"ye":0}
	for person in state["affection"]: state["affection"][person] = int(state["affection"][person])
	_begin()

func _open_modal(heading: String) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.size = Vector2(1280,800)
	canvas.add_child(modal)
	var veil = _rect(modal,Color(0.05,0.13,0.14,0.75),Rect2(0,0,1280,800))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var p = Panel.new()
	p.position = Vector2(165,58)
	p.size = Vector2(950,684)
	p.add_theme_stylebox_override("panel",_style(CREAM,true))
	modal.add_child(p)
	var head = _label(heading,30)
	head.position = Vector2(28,20)
	p.add_child(head)
	var close = _button("關閉  ×",_close_modal,true)
	close.position = Vector2(790,20)
	close.size.x = 132
	p.add_child(close)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(28,84)
	scroll.size = Vector2(894,568)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	scroll.add_child(content)
	return content

func _close_modal() -> void:
	if is_instance_valid(modal):
		canvas.remove_child(modal)
		modal.queue_free()
	modal = null
	cooldown = 0.25

func _paragraph(parent: Node, text: String, size := 22) -> void:
	var l = _label(text,size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)

func _info(heading: String, text: String) -> void:
	_paragraph(_open_modal(heading),text)

func _confirm(text: String, action: Callable) -> void:
	var col = _open_modal("請確認")
	_paragraph(col,text,26)
	col.add_child(_button("確認",func():
		_close_modal()
		action.call()))
	col.add_child(_button("返回",_close_modal))

func _slots(loading: bool) -> void:
	var col = _open_modal("讀取旅程" if loading else "保存旅程")
	_paragraph(col,"三個手動存檔＋一個自動存檔。每段開頭自動保存；手動存檔不會被自動覆寫。",18)
	for slot in range(0 if loading else 1,4):
		var data = _read_json("user://slot_%s.json"%slot)
		var title = "自動存檔" if slot==0 else "手動存檔 %s"%slot
		if _valid_save(data):
			var id = str(data.get("state",{}).get("node",""))
			title += "  ·  "+str(nodes.get(id,{}).get("chapter",id))+"\n"+str(data.get("saved",""))
		else: title += "  ·  尚無有效記錄"
		var b = _button(title,func():
			if loading:
				if in_game: _confirm("讀檔會回到所選時間點，並更新自動存檔。建議先把現在進度另存手動槽。繼續？",_load_slot.bind(slot))
				else: _load_slot(slot)
			elif data is Dictionary:
				_confirm("覆寫手動存檔 %s？"%slot,func():
					_save(slot)
					_slots(false))
			else:
				_save(slot)
				_slots(false))
		b.disabled = (loading and not _valid_save(data)) or (not loading and not in_game)
		col.add_child(b)

func _history() -> void:
	var col = _open_modal("對話回顧")
	if state.get("history",[]).is_empty(): _paragraph(col,"旅程尚未開始。")
	for entry in state.get("history",[]):
		_paragraph(col,str(entry["speaker"]),19)
		_paragraph(col,str(entry["text"]),21)

func _journal() -> void:
	var col = _open_modal("我的潮汐手帳")
	_paragraph(col,"周予安 · 27 歲\n不是猜中對方的答案，而是練習聽見她們自己的選擇。",24)
	_paragraph(col,"互信記錄是共同經歷的回聲，不是好感門檻。最後的關係由你在對話中清楚選擇。",19)
	for pair in [["lin","林芷晴 · 建築師 · 26 歲"],["su","蘇曼 · 聲音設計師 · 28 歲"],["ye","葉禾寧 · 海洋研究助理 · 25 歲"]]:
		_paragraph(col,pair[1]+"\n共同經歷："+str(state.get("affection",{}).get(pair[0],0)),22)
	_paragraph(col,"已走過 %s 段故事；收集 %s / 7 個結局。"%[state.get("visited",[]).size(),profile["endings"].size()],20)
	var letters: Variant = story.get("letters",{})
	if letters is Dictionary:
		for key in letters:
			var letter: Variant = letters[key]
			if letter is Dictionary:
				if state.get("letters",[]).has(key):
					_paragraph(col,str(letter.get("title",key)),23)
					_paragraph(col,str(letter.get("text",letter.get("summary",""))),20)

func _gallery() -> void:
	var col = _open_modal("結局書架  ·  %s / 7"%profile["endings"].size())
	_paragraph(col,"完成的結局會保存在這裡；開始新遊戲不會清除書架。",18)
	for id in story.get("endings",{}):
		var e: Dictionary = story["endings"][id]
		var unlocked: bool = profile["endings"].has(id)
		_paragraph(col,("✓  "+str(e.get("title",id))) if unlocked else "尚未寄出的信",24)
		_paragraph(col,str(e.get("summary","")) if unlocked else "沿著不同的心意，把這封信寫完。",19)

func _ending() -> void:
	var id = str(nodes[current_id].get("ending",""))
	var e: Dictionary = story.get("endings",{}).get(id,{})
	var col = _open_modal("旅程結束  ·  "+str(e.get("title",id)))
	_paragraph(col,str(e.get("summary","謝謝你讀到這裡。")),25)
	_paragraph(col,"這封信已收進結局書架。你可以回顧對話、讀取先前的手動存檔，或開始另一段旅程。",20)
	col.add_child(_button("回到書店  /  標題",_show_title))
	col.add_child(_button("讀取另一個時間點",func(): _slots(true)))
	col.add_child(_button("留在此頁",_close_modal))

func _settings() -> void:
	var col = _open_modal("閱讀設定")
	_paragraph(col,"文字速度",23)
	var speed = HSlider.new()
	speed.min_value = 15
	speed.max_value = 150
	speed.step = 5
	speed.value = float(profile["speed"])
	speed.custom_minimum_size.y = 38
	col.add_child(speed)
	var speed_text = _label("每秒 %s 字"%int(speed.value),18)
	col.add_child(speed_text)
	speed.value_changed.connect(func(v):
		profile["speed"] = v
		speed_text.text = "每秒 %s 字"%int(v)
		_save_profile())
	_paragraph(col,"音樂與翻頁音量",23)
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(profile["volume"])
	volume.custom_minimum_size.y = 38
	col.add_child(volume)
	volume.value_changed.connect(func(v):
		profile["volume"] = v
		_apply_volume()
		_save_profile())
	var mute = CheckButton.new()
	mute.text = "靜音"
	mute.button_pressed = bool(profile["muted"])
	mute.add_theme_font_override("font",FONT)
	mute.add_theme_font_size_override("font_size",24)
	mute.add_theme_color_override("font_color",INK)
	mute.add_theme_color_override("font_pressed_color",INK)
	mute.add_theme_color_override("font_hover_color",TEAL)
	mute.add_theme_color_override("font_hover_pressed_color",TEAL)
	mute.add_theme_color_override("font_focus_color",INK)
	col.add_child(mute)
	mute.toggled.connect(func(v):
		profile["muted"] = v
		_apply_volume()
		_save_profile())
	_paragraph(col,"操作：空白鍵／Enter 繼續，1–3 選擇，Esc 開啟或關閉選單。點文字先展開全文。\n自動閱讀與已讀快進在選項處停下。所有選項都有短暫防誤觸。\n建議橫向畫面與耳機。網頁存檔保存在目前瀏覽器；清除網站資料會刪除存檔。",19)

func _credits() -> void:
	_info("製作與閱讀說明","潮汐書店的七封信\n\n原創繁體中文成年戀愛視覺小說。周予安 27 歲、林芷晴 26 歲、蘇曼 28 歲、葉禾寧 25 歲。三條人物路線，六個關係結局與一個獨身結局。\n\n劇情、美術與程式由 AI 協作原創製作；無角色語音。背景及立繪由影像生成製作，配樂及翻頁音為程式合成原創。字型 Noto Sans CJK TC，SIL Open Font License。引擎 Godot 4.6.3，MIT 授權。完整素材出處與授權列於原始碼 README。\n\n閱讀節奏因個人速度和分支而異。互信數值不控制結局；誠實表達、傾聽界線與自主選擇才是故事的核心。")

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/tide.wav"):
		music.stream = load("res://assets/audio/tide.wav")
		music.finished.connect(func(): music.play())
		music.play()
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	if ResourceLoader.exists("res://assets/audio/page.wav"): sfx.stream = load("res://assets/audio/page.wav")
	_apply_volume()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(max(0.001,float(profile["volume"]))))
	AudioServer.set_bus_mute(0,bool(profile["muted"]))

func _stop_audio() -> void:
	for player in [music,sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	_stop_audio()

func _ping() -> void:
	if is_instance_valid(sfx) and sfx.stream: sfx.play()

func _self_test() -> void:
	print("TIDE_SELF_TEST_START")
	_new_game()
	var checkpoint = state.duplicate(true)
	_save(3)
	_load_slot(3)
	assert(state == checkpoint,"Save/load must round-trip state")
	var start_id = current_id
	_advance()
	assert(current_id==start_id,"Cooldown must prevent accidental advance")
	_settings()
	assert(is_instance_valid(modal))
	var old_reveal = reveal
	_process(1.0)
	assert(reveal==old_reveal,"Modal must pause progression")
	_close_modal()
	_close_modal()
	assert(not is_instance_valid(modal),"Repeated close must be safe")
	_journal()
	_close_modal()
	_history()
	_close_modal()
	_slots(false)
	_close_modal()
	_slots(true)
	_close_modal()
	_toggle_skip()
	assert(is_instance_valid(modal),"Skip must require confirmation")
	_close_modal()
	assert(not skip_mode,"Cancel skip must not activate it")
	var reached: Dictionary = {}
	var paths: Array = [[story.get("start","c001")]]
	var seen: Dictionary = {}
	while not paths.is_empty():
		var path: Array = paths.pop_front()
		var id = str(path[-1])
		if seen.has(id): continue
		seen[id] = true
		var n: Dictionary = nodes[id]
		if n.has("ending"): reached[str(n["ending"])] = path
		var outgoing: Array = []
		if n.has("next"): outgoing.append(str(n["next"]))
		for c in n.get("choices",[]): outgoing.append(str(c["next"]))
		for next_id in outgoing:
			assert(nodes.has(next_id),"Missing graph target")
			var p = path.duplicate()
			p.append(next_id)
			paths.append(p)
	assert(reached.size()==7,"Seven reachable endings required")
	for ending_id in reached:
		_new_game()
		var path: Array = reached[ending_id]
		for i in range(path.size()-1):
			var n: Dictionary = nodes[current_id]
			cooldown = 0
			if n.has("choices"):
				for ci in n["choices"].size():
					if str(n["choices"][ci]["next"])==str(path[i+1]):
						_choose(ci)
						break
			else:
				reveal = body_label.get_total_character_count()
				body_label.visible_characters = int(reveal)
				_advance()
		assert(str(nodes[current_id].get("ending",""))==ending_id)
		_save(2)
		var expected = state.duplicate(true)
		_load_slot(2)
		assert(state==expected,"Ending save/load round-trip")
		_ending()
		assert(is_instance_valid(modal))
		_close_modal()
		_gallery()
		_close_modal()
		print("ENDING_PASS ",ending_id," nodes=",path.size())
	print("TIDE_SELF_TEST_PASS reachable_nodes=",seen.size()," endings=",reached.size())
	await get_tree().process_frame
	await get_tree().process_frame
	_stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

func _capture(args: PackedStringArray) -> void:
	var at = args.find("--capture")
	var target = args[at+1] if args.size()>at+1 else "title"
	if target!="title":
		_new_game()
		if nodes.has(target): _show_node(target)
		reveal = 100000
		body_label.visible_characters = -1
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output = "user://screenshots"
	var output_at = args.find("--capture-dir")
	if output_at>=0 and args.size()>output_at+1: output = args[output_at+1]
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output.path_join("screenshot_"+target+".png"))
	if "--hold" in args: return
	_stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()
