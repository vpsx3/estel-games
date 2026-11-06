import sys,os
from PIL import Image,ImageDraw
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','icons'))
names=sorted(f[:-4] for f in os.listdir('.') if f.endswith('.png'))
cols=8;S=4;cw=32*S+8
im=Image.new('RGBA',(cols*cw,((len(names)+cols-1)//cols)*(32*S+20)),(250,238,197,255));d=ImageDraw.Draw(im)
for i,n in enumerate(names):
    x=(i%cols)*cw+4;y=(i//cols)*(32*S+20)
    im.alpha_composite(Image.open(n+'.png').convert('RGBA').resize((32*S,32*S),Image.NEAREST),(x,y)); d.text((x,y+32*S+3),n,fill=(49,3,8,255))
im.save('../_raw/sheet.png')
