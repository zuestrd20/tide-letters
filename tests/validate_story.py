"""Validate the complete story graph, assets, and all seven ending paths."""
from pathlib import Path
import json,re,collections,hashlib
ROOT=Path(__file__).resolve().parents[1]
s=json.loads((ROOT/'data/story.json').read_text()); nodes=s['nodes']; endings=s['endings']
assert len(endings)==7
han=lambda text:len(re.findall(r'[\u3400-\u9fff]',text))
q=collections.deque([(s['start'],[s['start']])]);seen=set();paths={};choices=0
while q:
 ident,path=q.popleft()
 if ident in seen:continue
 seen.add(ident);n=nodes[ident]
 assert isinstance(n.get('text'),str) and n['text'],ident
 modes=sum(k in n for k in ('next','choices','ending'))
 assert modes==1,(ident,'must have exactly one continuation',modes)
 if 'ending' in n:
  assert n['ending'] in endings
  paths[n['ending']]=path
 if 'choices' in n:
  choices+=1
  assert 2<=len(n['choices'])<=3,(ident,'choice count')
 targets=[n['next']] if 'next'in n else [c['next'] for c in n.get('choices',[])]
 for target in targets:
  assert target in nodes,(ident,target)
  assert target not in path,('cycle',target)
  q.append((target,path+[target]))
assert set(nodes)==seen,('unreachable',set(nodes)-seen)
assert set(paths)==set(endings),('unreachable endings',set(endings)-set(paths))
letters=[n['letter'] for n in nodes.values() if 'letter'in n]
assert len(set(letters))==7
assert set(letters)==set(s['letters'])
art=json.loads((ROOT/'data/art.json').read_text())
for n in nodes.values():
 assert n.get('bg','bookstore') in art['backgrounds'],n
 if n.get('character'):
  assert n['character'] in art['characters'],n
  assert n.get('expression','neutral') in art['characters'][n['character']],n
for path in list(art['backgrounds'].values())+[p for c in art['characters'].values() for p in c.values()]:
 assert path.startswith('res://') and (ROOT/path[6:]).is_file(),path
# Dynamic programming over DAG gives exact per-ending min/max story-only Han counts.
memo={};visiting=set()
def ranges(ident):
 if ident in memo:return memo[ident]
 assert ident not in visiting,('cycle',ident)
 visiting.add(ident);n=nodes[ident];weight=han(n['text'])
 if 'ending'in n: result={n['ending']:(weight,weight)}
 else:
  result={}
  targets=[n['next']] if 'next'in n else [c['next'] for c in n['choices']]
  for target in targets:
   for end,(lo,hi) in ranges(target).items():
    old=result.get(end,(10**9,0));result[end]=(min(old[0],lo+weight),max(old[1],hi+weight))
 visiting.remove(ident);memo[ident]=result;return result
report={'status':'PASS','nodes':len(nodes),'choice_nodes':choices,'seven_endings':list(endings),'story_text_han':sum(han(n['text']) for n in nodes.values()),'choice_han':sum(han(c['text']) for n in nodes.values() for c in n.get('choices',[])),'letters_han':sum(han(l['text']) for l in s['letters'].values()),'max_node_han':max(han(n['text']) for n in nodes.values()),'per_ending_han_range':ranges(s['start']),'ending_paths':paths,'story_sha256':hashlib.sha256((ROOT/'data/story.json').read_bytes()).hexdigest()}
(ROOT/'tests/story_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='ending_paths'},ensure_ascii=False,indent=2))
