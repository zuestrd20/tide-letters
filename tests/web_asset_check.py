"""Local HTTP asset integrity check; this does not exercise a WebGL canvas."""
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from functools import partial
from threading import Thread
from urllib.request import urlopen
import hashlib,json
root=Path(__file__).resolve().parents[1]/'builds/web'
srv=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(root)))
t=Thread(target=srv.serve_forever,daemon=True);t.start();report={}
for name in ['index.html','game.html','game.js','game.pck','game.wasm','game.audio.worklet.js','game.audio.position.worklet.js']:
 with urlopen(f'http://127.0.0.1:{srv.server_port}/{name}') as r:
  b=r.read(); assert b==(root/name).read_bytes();report[name]={'status':r.status,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
assert 'const GODOT_THREADS_ENABLED = false;' in (root/'game.html').read_text()
srv.shutdown();print(json.dumps({'status':'PASS','single_thread':True,'assets':report},indent=2))
