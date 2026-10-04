extends SceneTree
var g
var failures = []
func check(ok, name):
	print(('PASS ' if ok else 'FAIL ')+name)
	if not ok: failures.append(name)
func _initialize():
	call_deferred('run')
func run():
	g = load('res://main.tscn').instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g._new_game()
	g.cooldown = 0
	var id = g.current_id
	g._advance()
	check(g.current_id == id and g.body_label.visible_characters == g.body_label.get_total_character_count(), 'first advance reveals only')
	g._advance()
	check(g.current_id != id, 'second advance progresses')
	id = g.current_id
	g._settings()
	g._process(100)
	g._advance()
	check(g.current_id == id, 'settings freezes story')
	g._close_modal()
	g._save(1)
	var saved = g.state.duplicate(true)
	g.cooldown=0
	g.reveal=99999
	g.body_label.visible_characters=-1
	g._advance()
	g._save(0)
	g._load_slot(1)
	check(g.state==saved, 'autosave does not overwrite manual slot')
	g._save(1)
	g._load_slot(1)
	check(g.state==saved, 'overwrite same slot and reload')
	for nid in g.nodes:
		if g.nodes[nid].has('choices'):
			g._show_node(nid)
			break
	g.cooldown=0
	g.reveal=99999
	g.body_label.visible_characters=-1
	id=g.current_id
	g.auto_mode=true
	g._process(100)
	check(g.current_id==id, 'auto stops at choices')
	g.skip_mode=true
	g.was_read=true
	g._process(100)
	check(g.current_id==id, 'skip stops at choices')
	var c=g.nodes[id]['choices'][0]
	var before=g.state['affection'].duplicate(true)
	g._choose(0)
	var chosen=g.current_id
	g._choose(0)
	check(g.current_id==chosen, 'double choice guarded')
	for person in c.get('effects',{}).get('affection',{}):
		check(g.state['affection'][person]==before.get(person,0)+c['effects']['affection'][person], 'affection delta '+person)
	for flag in c.get('effects',{}).get('flags',[]):
		check(g.state['flags'].has(flag), 'flag '+flag)
	g._new_game()
	g.profile['read'].erase(g.story['start'])
	g._show_node(g.story['start'])
	g.skip_mode=true
	g._process(1)
	check(not g.skip_mode, 'skip stops unread')
	var option_count=0
	for nid in g.nodes:
		for ci in g.nodes[nid].get('choices',[]).size():
			g._new_game()
			g._show_node(nid)
			g.cooldown=0
			var option=g.nodes[nid]['choices'][ci]
			g._choose(ci)
			check(g.current_id==option['next'], 'choice target '+nid+':'+str(ci))
			for person in option.get('effects',{}).get('affection',{}):
				check(g.state['affection'][person]==option['effects']['affection'][person], 'choice affection '+nid+':'+str(ci))
			for flag in option.get('effects',{}).get('flags',[]):
				check(g.state['flags'].has(flag),'choice flag '+nid+':'+str(ci))
			option_count+=1
	print('OPTIONS_TESTED ',option_count)
	print('FLOW_RESULT ',failures)
	g._stop_audio()
	await create_timer(0.25).timeout
	g.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
