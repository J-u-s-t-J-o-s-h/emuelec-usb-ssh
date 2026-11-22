extends Node2D
const BUTTONS := [KEY_ENTER,KEY_BACKSPACE,KEY_SPACE,KEY_C,KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT,KEY_Q,KEY_E,KEY_HOME,KEY_END]
const NAMES := ["A   C","B   E","X   G","Y   A","UP   C","RIGHT   E","DOWN   G","LEFT   A","L1 KICK","R1 SNARE","L2 HAT","R2 CLAP"]
const COLORS := [Color("#ff7099"),Color("#ff9878"),Color("#ffcd69"),Color("#eeb8ff"),Color("#6fe1bd"),Color("#52cdda"),Color("#71aaff"),Color("#ad95fa"),Color("#ffb55c"),Color("#f77c84"),Color("#e4dc69"),Color("#85dfaa")]
var tones: Array[AudioStreamWAV] = []
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var glow: Array[float] = []
var held: Array[bool] = []
var pulses: Array[Dictionary] = []
var clock := 0.0
var palette := 0
var hits := 0
var last_note: Label
var key_label: Label
var benchmark := false
var next_beat := 0.0
var last_tick := 0
var sample_start := 0
var sample_frames := 0
var frames: Array[float] = []

func _ready() -> void:
	get_tree().auto_accept_quit = false
	scale = Vector2.ONE*(float(ProjectSettings.get_setting("display/window/size/viewport_width"))/720.0)
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	for i in 12:
		tones.append(load("res://sounds/%d.wav" % i) as AudioStreamWAV)
		glow.append(0.0)
		held.append(false)
	# A hard polyphony limit and conservative gain bound simultaneous peak level.
	for i in 16:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -25.0
		add_child(voice)
		voices.append(voice)
	_build_hud()
	print("JAM_READY ticks_ms=%d tones=%d voices=%d" % [Time.get_ticks_msec(),tones.size(),voices.size()])
	if "--self-test" in OS.get_cmdline_user_args(): call_deferred("_self_test")

func _label(text: String, rect: Rect2, size: int, color := Color("#eff5ff")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _build_hud() -> void:
	_label("RAINBOW JAM",Rect2(0,12,720,40),32)
	key_label = _label("SUNSHINE KEY",Rect2(0,55,720,28),17,Color("#a6b8df"))
	last_note = _label("Make some music!",Rect2(0,244,720,35),22)
	var groups := ["PIANO  •  FACE BUTTONS","GUITAR  •  D-PAD","DRUMS  •  SHOULDERS"]
	for row in 3:
		_label(groups[row],Rect2(0,286+row*124,720,24),16,Color("#a6b8df"))
	for i in 12:
		_label(NAMES[i],Rect2(_pad(i)+Vector2(0,25),Vector2(144,38)),19,Color("#152033"))
	_label("Start: change key     Select: quit",Rect2(0,681,720,28),17,Color("#b5c6eb"))

func _pad(index: int) -> Vector2:
	return Vector2(36+(index%4)*164,316+(index/4)*124)

func _hit(index: int) -> void:
	var voice := voices[voice_index]
	voice_index = (voice_index+1)%voices.size()
	voice.stop()
	voice.stream = tones[index]
	voice.pitch_scale = pow(2.0,float(palette*2)/12.0) if index<8 else 1.0
	voice.play()
	glow[index] = 1.0
	hits += 1
	if pulses.size() >= 12: pulses.pop_front()
	pulses.append({"age":0.0,"index":index,"phase":float(hits)*0.7})
	last_note.text = ["Piano","Guitar","Drums"][index/4]+"  /  "+NAMES[index]

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var index := BUTTONS.find(event.keycode)
	if index < 0 and event.keycode == KEY_W: index = 4
	if index >= 0:
		if event.pressed and not event.echo and not held[index]:
			held[index] = true
			_hit(index)
		elif not event.pressed: held[index] = false
		return
	if not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		print("JAM_QUIT hits=%d" % hits)
		get_tree().quit(0)
	elif event.keycode == KEY_P:
		palette = (palette+1)%3
		key_label.text = ["SUNSHINE KEY","OCEAN KEY","STARLIGHT KEY"][palette]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit(0)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		for i in held.size(): held[i] = false

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now-last_tick)/1000.0 if last_tick else 0.0
	last_tick = now
	clock += delta
	for i in glow.size(): glow[i] = maxf(0.0,glow[i]-delta*2.3)
	for pulse in pulses: pulse.age += delta
	while not pulses.is_empty() and float(pulses[0].age)>1.25: pulses.pop_front()
	if benchmark:
		if clock >= next_beat:
			# Six simultaneous notes, ten times per second: sustained stress.
			var base_note := hits/6
			for i in 6: _hit((base_note+i)%12)
			next_beat = clock+0.1
		if clock>3.0:
			if sample_start==0:
				sample_start = now
				sample_frames = Engine.get_process_frames()
			frames.append(ms)
		if clock>23.0:
			frames.sort()
			print("JAM_BENCH fps=%.2f median_ms=%.2f p95_ms=%.2f worst_ms=%.2f hits=%d" % [
				(Engine.get_process_frames()-sample_frames)/((now-sample_start)/1000000.0),
				frames[int(frames.size()*0.5)],frames[int(frames.size()*0.95)],frames[-1],hits])
			if DisplayServer.get_name()!="headless":
				get_viewport().get_texture().get_image().save_png("user://jam-benchmark.png")
			get_tree().quit(0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,720,720),Color("#101a31"))
	# Slow orbiting rainbow petals: continuous movement without full-screen flashes.
	var center := Vector2(360,164)
	for i in 12:
		var a := clock*0.22+float(i)*TAU/12.0
		var radius := 48.0+sin(clock*1.8+i)*6.0
		var point := center+Vector2(cos(a),sin(a))*radius
		draw_circle(point,9.0+glow[i]*13.0,COLORS[i])
	draw_circle(center,23.0+sin(clock*2.0)*2.0,Color("#f1e7ff"))
	for i in 12:
		var pos := _pad(i)
		var expansion := sin(glow[i]*PI*0.5)*4.0
		draw_rect(Rect2(pos+Vector2(0,7),Vector2(144,86)),COLORS[i].darkened(0.6))
		draw_rect(Rect2(pos-Vector2.ONE*expansion,Vector2(144,80)+Vector2.ONE*expansion*2),COLORS[i].lightened(glow[i]*0.25))
		if held[i]: draw_rect(Rect2(pos+Vector2(7,7),Vector2(130,66)),Color("#ffffff"),false,2.0)
	for pulse in pulses:
		var age: float = pulse.age
		var i: int = pulse.index
		var life := maxf(0.0,1.0-age/1.25)
		var color: Color = COLORS[i]
		color.a = life*0.85
		var origin := Vector2(360,164)
		var radius := 35.0+age*90.0
		draw_arc(origin,radius,float(pulse.phase),float(pulse.phase)+PI*1.3,20,color,3.0)
		for n in 3:
			var angle := float(pulse.phase)+float(n)*TAU/3.0+age
			var point := origin+Vector2(cos(angle),sin(angle))*radius
			var size := 5.0*life
			var points := PackedVector2Array([point+Vector2(0,-size),point+Vector2(size,0),point+Vector2(0,size),point+Vector2(-size,0)])
			draw_colored_polygon(points,color)

func _check(ok: bool, label: String) -> bool:
	print("JAM_CHECK %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: get_tree().quit(1)
	return ok

func _self_test() -> void:
	await get_tree().process_frame
	for i in 12:
		if not _check(tones[i]!=null and tones[i].data.size()>1000,"audio asset %d" % i): return
		var event := InputEventKey.new()
		event.keycode = BUTTONS[i]
		event.pressed = true
		var before := hits
		_unhandled_input(event)
		if not _check(hits==before+1 and glow[i]>0,"sound and visual %d" % i): return
		_unhandled_input(event)
		if not _check(hits==before+1,"held key no repeat"): return
		event.pressed = false
		_unhandled_input(event)
	for i in 40: _hit(i%12)
	if not _check(voices.size()==16 and pulses.size()<=12,"bounded audio and animation"): return
	var start := InputEventKey.new()
	start.keycode = KEY_P
	start.pressed = true
	for i in 3: _unhandled_input(start)
	if not _check(palette==0,"key cycle"): return
	print("JAM_SELF_TEST_PASS")
	get_tree().quit(0)
