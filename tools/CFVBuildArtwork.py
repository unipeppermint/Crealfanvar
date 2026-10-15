"""Regenerate original Paperkin audio only.
Creature PNGs are authored with imagegen; see artifacts/CFV-Artwork-Prompts.json.
The retired polygon generator must not recreate obsolete runtime artwork.
"""
import pathlib, math, wave, struct
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'Crealfanvar/Resources'
# Original synthesized sounds: six short motifs and a quiet, seamless 16-second loop.
(OUT/'Audio').mkdir(exist_ok=True)
def sound(name,duration,notes,volume=0.2,loop=False):
    sr=22050;frames=[]
    for i in range(int(sr*duration)):
        t=i/sr; value=0
        if loop:
            for freq in notes:value+=math.sin(2*math.pi*freq*t)*0.14*(1-math.cos(2*math.pi*t/duration))/2
        else:
            for j,freq in enumerate(notes):
                local=t-j*0.075
                if local>=0:value+=(math.sin(2*math.pi*freq*local)+0.22*math.sin(2*math.pi*freq*2*local))*math.exp(-local*12)*min(1,local*160)
        frames.append(struct.pack('<h',int(max(-1,min(1,value*volume))*32767)))
    with wave.open(str(OUT/'Audio'/f'CFV-{name}.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(b''.join(frames))
for name,notes in [('select',[660]),('swap',[440,660]),('fold',[330,495,660]),('match',[660,880]),('fail',[330,294]),('win',[523.25,659.25,784,1046.5])]:sound(name,0.65,notes)
sound('music',16,[130.8125,164.8125,196,261.625],0.12,True)
