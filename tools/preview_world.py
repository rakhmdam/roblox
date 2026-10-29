"""Offline geometry contact sheet, not a Roblox screenshot. Optional Pillow dependency."""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import world_art

ROOT=Path(__file__).resolve().parents[1]


def render():
    scale=2
    image=Image.new('RGB',(1800*scale,850*scale),(19,38,47))
    draw=ImageDraw.Draw(image)
    def font(n):
        path=Path('C:/Windows/Fonts/segoeui.ttf')
        return ImageFont.truetype(str(path),n*scale) if path.exists() else ImageFont.load_default()
    draw.text((52*scale,30*scale),'SLIME SALVAGE',font=font(38),fill=(239,230,203))
    draw.text((54*scale,86*scale),'Editable world geometry / offline preview / not a Roblox gameplay capture',font=font(17),fill=(156,188,192))
    art=world_art.parts()
    for panel,group in enumerate(['shore','bay','cave']):
        x0=(panel*600+18)*scale
        draw.rounded_rectangle((x0,140*scale,x0+564*scale,780*scale),radius=18*scale,fill=(39,72,82))
        faces=[]
        def world(part,vertex):
            r=world_art.rotation_matrix(part.get('rotation'))
            return [sum(r[i][j]*vertex[j] for j in range(3))+part['position'][i]-(panel*400 if i==0 else 0) for i in range(3)]
        def face(part,vertices):
            vertices=[world(part,v) for v in vertices]
            a,b,c=vertices[:3]
            u=[b[i]-a[i] for i in range(3)]; v=[c[i]-a[i] for i in range(3)]
            n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            length=math.sqrt(sum(t*t for t in n))
            if not length or sum(n)<=0: return
            # Warm directional light and cool ambient shade.
            strength=.66+.34*max(0,(n[0]*-.25+n[1]*.9+n[2]*.35)/length)
            tint=part['color']; rgb=tuple(min(255,int(t*strength)) for t in tint)
            points=[((panel*600+300+(v[0]-v[2])*.866*2.5)*scale,
                     (448+(v[0]+v[2])*.5*2.5-v[1]*2.5)*scale) for v in vertices]
            faces.append((points,[sum(v) for v in vertices],rgb))
        # A local ocean tile gives each island context without distant base geometry.
        water=dict(position=[panel*400,-6,10],size=[124,1,134],color=[65,149,167])
        selected=[water]+[p for p in art if p['group']==group and p.get('class')!='SpawnLocation']
        for part in selected:
            sx,sy,sz=[n/2 for n in part['size']]
            if part.get('shape')=='Ball':
                # Tessellated ellipsoid approximates the baked Roblox ball geometry.
                def point(a,b): return [sx*math.cos(b)*math.cos(a),sy*math.sin(b),sz*math.cos(b)*math.sin(a)]
                for j in range(6):
                    b0=-math.pi/2+j*math.pi/6; b1=b0+math.pi/6
                    for i in range(10):
                        a0=i*math.pi/5; a1=a0+math.pi/5
                        face(part,[point(a0,b0),point(a0,b1),point(a1,b1)])
                        face(part,[point(a0,b0),point(a1,b1),point(a1,b0)])
            else:
                # Static scenery uses boxes and balls; runtime props are excluded.
                face(part,[[-sx,sy,-sz],[-sx,sy,sz],[sx,sy,sz],[sx,sy,-sz]])
                face(part,[[sx,-sy,-sz],[sx,sy,-sz],[sx,sy,sz],[sx,-sy,sz]])
                face(part,[[-sx,-sy,sz],[sx,-sy,sz],[sx,sy,sz],[-sx,sy,sz]])
        pixels=np.array(image)
        depth_buffer=np.full((850*scale,1800*scale),-np.inf,dtype=np.float32)
        for points,depths,rgb in faces:
            for j in range(1,len(points)-1):
                a,b,c=[points[k] for k in [0,j,j+1]]
                da,db,dc=[depths[k] for k in [0,j,j+1]]
                left=max(x0,int(min(a[0],b[0],c[0]))); right=min(x0+564*scale,int(max(a[0],b[0],c[0]))+1)
                top=max(141*scale,int(min(a[1],b[1],c[1]))); bottom=min(680*scale,int(max(a[1],b[1],c[1]))+1)
                if left>=right or top>=bottom: continue
                denominator=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
                if abs(denominator)<1e-7: continue
                yy,xx=np.mgrid[top:bottom,left:right]
                wa=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/denominator
                wb=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/denominator
                wc=1-wa-wb
                depth=wa*da+wb*db+wc*dc
                region=depth_buffer[top:bottom,left:right]
                mask=(wa>=-1e-6)&(wb>=-1e-6)&(wc>=-1e-6)&(depth>region)
                pixels[top:bottom,left:right][mask]=rgb
                region[mask]=depth[mask]
        image=Image.fromarray(pixels); draw=ImageDraw.Draw(image)
        title=['GREEN SHORE','IRON BAY','CRYSTAL CAVES'][panel]
        caption=['Garden coast / timber / nursery','Salvage port / cranes / machinery','Amethyst rock / glowing mushrooms'][panel]
        draw.text(((panel*600+46)*scale,690*scale),title,font=font(25),fill=(247,226,180))
        draw.text(((panel*600+46)*scale,734*scale),caption,font=font(16),fill=(177,204,204))
    draw.text((52*scale,803*scale),'Source: tools/world_art.py  |  Lighting and gameplay entities must be reviewed in Roblox Studio.',font=font(16),fill=(156,188,192))
    out=ROOT/'assets/previews/world-dioramas.png'; out.parent.mkdir(exist_ok=True)
    image.resize((1800,850),Image.Resampling.LANCZOS).save(out)
    print(out)


if __name__=='__main__': render()
