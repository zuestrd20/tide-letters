"""Original procedural music/SFX. No samples or third-party melodies."""
from pathlib import Path
import wave, math
import numpy as np
out=Path(__file__).resolve().parents[1]/'assets/audio';out.mkdir(parents=True,exist_ok=True)
sr=22050;duration=48.;n=int(sr*duration);t=np.arange(n)/sr
a=np.zeros(n)
# Six eight-second suspended harmony fields, individually faded to silence.
chords=[(146.832,220,293.665),(130.813,195.998,261.626),(164.814,220,329.628),(174.614,261.626,349.228),(146.832,220,293.665),(130.813,195.998,261.626)]
for k,chord in enumerate(chords):
 local=t-k*8;mask=(local>=0)&(local<8);q=local[mask];env=np.sin(np.pi*q/8)**1.7
 for f in chord:a[mask]+=0.065*env*(np.sin(2*np.pi*f*q)+0.18*np.sin(2*np.pi*f*2*q))/1.18
 for j,idx in enumerate([2,1,0,1]):
  st=k*8+j*1.8+0.5; mask=(t>=st)&(t<st+2.5);q=t[mask]-st;f=chord[idx]*2
  a[mask]+=0.065*np.exp(-2*q)*(1-np.exp(-25*q))*np.sin(2*np.pi*f*q)
a*=0.7

def write(name,signal):
 with wave.open(str(out/name),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes((np.clip(signal,-1,1)*32767).astype('<i2').tobytes())
write('tide.wav',a)
rng=np.random.default_rng(7);q=np.arange(int(sr*.14))/sr
noise=rng.normal(0,.025,len(q));noise=np.convolve(noise,np.ones(7)/7,'same')
write('page.wav',noise*np.sin(np.pi*q/.14)**2+.018*np.exp(-q*35)*np.sin(2*np.pi*720*q))
