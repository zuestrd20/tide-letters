extends SceneTree
var g
var failures=[]
func check(ok,name):
	print(('PASS ' if ok else 'FAIL ')+name)
	if not ok:failures.append(name)
func _initialize(): call_deferred('run')
func run():
	g=load('res://main.tscn').instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g._new_game()
	var baseline=g.state.duplicate(true)
	var valid={'version':1,'state':baseline,'saved':'QA'}
	check(g._valid_save(JSON.parse_string(JSON.stringify(valid))), 'roundtrip version 1 accepted')
	for key in ['history','visited','letters','flags','affection']:
		var bad=valid.duplicate(true)
		bad['state'][key]='corrupt'
		check(not g._valid_save(bad), 'reject bad type '+key)
		g._write_json('user://slot_3.json',bad)
		g._load_slot(3)
		check(g.state==baseline,'invalid load preserves state '+key)
		g._close_modal()
		g._slots(true)
		g._close_modal()
	for v in [null,{},[],{'version':99,'state':baseline},{'version':1,'state':{'node':'missing'} }]:
		check(not g._valid_save(v),'reject malformed/version/node '+str(v).substr(0,50))
	var f=FileAccess.open('user://slot_3.json',FileAccess.WRITE)
	f.store_string('{broken')
	f.close()
	g._load_slot(3)
	check(g.state==baseline and is_instance_valid(g.modal), 'malformed JSON rejected without progress loss')
	g._close_modal()
	g._sanitize_profile({'read':[],'endings':'bad','speed':999,'volume':-10,'muted':'bad'})
	check(g.profile['read'] is Dictionary and g.profile['endings'] is Dictionary and g.profile['speed']==150 and g.profile['volume']==0,'profile sanitization/clamping')
	var extra=valid.duplicate(true)
	extra['state']['affection']['unknown']={}
	check(not g._valid_save(extra),'reject nonnumeric unexpected affection value')
	if g._valid_save(extra):
		g._write_json('user://slot_3.json',extra)
		g._load_slot(3)
	print('SAVE_RESULT ',failures)
	g.music.stop()
	g.sfx.stop()
	g._stop_audio()
	await create_timer(0.25).timeout
	g.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
