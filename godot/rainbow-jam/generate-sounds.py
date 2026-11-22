from pathlib import Path
import math,wave,struct,random,json
dst=Path(__file__).resolve().parent
(dst/"project/sounds").mkdir(parents=True,exist_ok=True)
(dst/"evidence").mkdir(exist_ok=True)
# Synthesized, original instrument-like one-shots; no third-party recordings.
rate=22050; report=[]
for index in range(12):
    rng=random.Random(817+index); n=int(rate*(1.0 if index<8 else 0.45)); samples=[]
    frequency=[261.6256,329.6276,391.9954,440.0,130.8128,164.8138,195.9977,220.0][index] if index<8 else 0
    delay=[rng.uniform(-1,1) for _ in range(max(2,round(rate/frequency)))] if 4<=index<8 else []
    for i in range(n):
        t=i/rate
        if index<4:
            value=(math.sin(math.tau*frequency*t)*math.exp(-3.4*t)+0.3*math.sin(math.tau*frequency*2*t)*math.exp(-7*t)+0.12*math.sin(math.tau*frequency*3.003*t)*math.exp(-10*t))
        elif index<8:
            slot=i%len(delay); value=delay[slot]; delay[slot]=0.497*(value+delay[(slot+1)%len(delay)])
        elif index==8:
            value=math.sin(math.tau*(48*t+42*(1-math.exp(-24*t))/24))*math.exp(-12*t)
        elif index==9:
            value=(0.7*rng.uniform(-1,1)+0.3*math.sin(math.tau*180*t))*math.exp(-18*t)
        elif index==10:
            value=rng.uniform(-1,1)*math.exp(-55*t)
        else:
            value=rng.uniform(-1,1)*math.exp(-14*t)*(0.45+0.55*abs(math.sin(100*t)))
        value*=min(1,t/0.004)*min(1,(n-1-i)/(rate*0.025))
        samples.append(value)
    peak=max(abs(x) for x in samples)
    pcm=[round(x/peak*24000) for x in samples]
    with wave.open(str(dst/'project/sounds'/f'{index}.wav'),'wb') as f:
        f.setparams((1,2,rate,n,'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*n,*pcm))
    report.append(dict(index=index,frames=n,rate=rate,peak=max(abs(x) for x in pcm),first=pcm[0],last=pcm[-1]))
(dst/'evidence/audio-generation.json').write_text(json.dumps(report,indent=2)+'\n')
