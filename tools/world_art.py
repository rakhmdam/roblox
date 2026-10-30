"""Original editable diorama art; gameplay lanes and mining footprints stay clear."""
import math
import random


def rotation_matrix(degrees):
    a,b,c=map(math.radians,degrees or [0,0,0])
    ca,sa,cb,sb,cc,sc=math.cos(a),math.sin(a),math.cos(b),math.sin(b),math.cos(c),math.sin(c)
    return [[cb*cc,-cb*sc,sb], [ca*sc+sa*sb*cc,ca*cc-sa*sb*sc,-sa*cb],
            [sa*sc-ca*sb*cc,sa*cc+ca*sb*sc,ca*cb]]


def detail_island(result, group, x, z, theme, base=False):
    rng=random.Random(129)
    wood,darkwood,cream=[161,114,74],[96,74,60],[241,222,179]
    gold,metal=[236,184,87],[88,120,133]
    def p(name,size,pos,color,shape=None,rotation=None,material=None):
        result.append(dict(group=group,name=name,size=size,position=[x+pos[0],pos[1],z+pos[2]],
                           color=color,shape=shape,rotation=rotation,material=material,
                           collide=False,query=False))
    p('IslandRock',[108,10,98],[0,-6,0],[113,131,134],'Ball')
    p('SandLip',[112,2,102],[0,-3,0],[199,177,138],'Ball')
    p('StationWalk',[39,.15,6],[0,1.7,18],cream)
    for i in range(11):
        p('PathStone',[4.7,.13,3.3],[(-1)**i*.35,1.85,-28+i*5.7],[215,199,162])
    # Planks, bollards and mooring ropes turn the plain dock into a salvage pier.
    for i in range(13): p('PierPlank',[12.2,.22,1.7],[0,1.12,42+i*2],wood if i%3 else [177,131,88])
    for side in [-1,1]:
        for dz in [44,54,64]:
            p('PierPost',[1,6,1],[side*5.7,-.3,dz],darkwood)
            p('PostCap',[1.4,.35,1.4],[side*5.7,2.8,dz],cream)
        p('Rope',[.18,.18,20],[side*5.7,2.4,54],[203,178,129])
    p('SkiffHull',[6,2,13],[13,-3,54],wood,'Ball')
    p('SkiffInterior',[4.8,.5,9],[13,-1.9,54],darkwood)
    for dz in [51,56]: p('SkiffSeat',[5.5,.4,1.5],[13,-1.5,dz],cream)
    p('Oar',[.3,.3,10],[16,-1.2,54],cream,rotation=[0,20,0])
    for name,dx,dz in [('Recycler',-16,18),('Workshop',16,18),('Nursery',-17,-15)]:
        p(name+'Foundation',[8.5,.4,7.5],[dx,1.7,dz],metal)
        p(name+'Awning',[9.3,.35,8.3],[dx,7,dz],cream)
        for side in [-1,1]: p(name+'Frame',[.35,4.2,.35],[dx+side*3.3,3.9,dz+3],darkwood)
        p(name+'Counter',[7.8,.5,1.6],[dx,3,dz+3],cream)
        if name=='Recycler':
            p('RecycleHopper',[3,1.4,2.8],[dx,4,dz+1.8],metal)
            p('HopperMouth',[2.3,.15,2.1],[dx,4.75,dz+1.8],[40,68,70])
            for k in range(3): p('StatusLamp',[.4,.4,.2],[dx-1+k,4.5,dz+3.1],[135,235,156],material='Neon')
            p('Exhaust',[1,2,1],[dx+2,7.5,dz-1],metal)
        elif name=='Workshop':
            p('ToolBoard',[4.7,1.8,.3],[dx,4.2,dz+2.8],darkwood)
            for k in range(3):
                p('ToolHandle',[.2,1.1,.2],[dx-1.4+k*1.4,4,dz+3.1],gold,rotation=[0,0,-15+k*15])
                p('ToolHead',[.8,.3,.35],[dx-1.4+k*1.4,4.6,dz+3.1],metal)
        else:
            for k in [-1,1]:
                p('IncubatorPedestal',[1.7,.5,1.7],[dx+k*1.4,3.5,dz+2.5],gold)
                p('IncubatorEgg',[1.2,1.6,1.2],[dx+k*1.4,4.5,dz+3.3],[179,224,187] if k<0 else [236,202,245],'Ball')
    if theme=='shore':
        for dx,dz in [(-36,-29),(36,-29),(-36,28),(36,28)]:
            for ox,oy,oz,s in [(-2,10,0,7),(2,11,1,7),(0,14,-1,6)]:
                p('TreeFoliage',[s,s*.8,s],[dx+ox,oy,dz+oz],[114+int(oy),178+int(oy),119],'Ball')
            p('TreeRoots',[4,.6,4],[dx,1.8,dz],[94,145,92],'Ball')
        for i in range(8 if base else 22):
            dx=(-1 if i%2 else 1)*(32+rng.random()*7); dz=-20+rng.random()*45
            p('LeafBush',[3,2,3],[dx,2.3,dz],[89,152,103],'Ball')
            p('Wildflower',[.7,.65,.7],[dx+.8,3.2,dz],[245,210,140] if i%2 else [239,167,165],'Ball')
        for dx in [-39,39]:
            p('FenceRail',[.4,.5,21],[dx,3,8],cream)
            for dz in [0,8,16]: p('FencePost',[.65,2.5,.65],[dx,2.7,dz],wood)
    elif theme=='bay':
        for dx,dz in [(-38,-32),(38,29)]:
            p('CraneFoot',[7,1,7],[dx,2,dz],metal)
            p('CraneTower',[2.3,20,2.3],[dx,12,dz],gold)
            p('CraneArm',[20,1.8,2],[dx-4,22,dz],gold)
            p('CraneBrace',[.5,18,.5],[dx,12,dz],cream,rotation=[0,0,18])
            p('HoistCable',[.2,13,.2],[dx-12,15,dz],darkwood)
            p('HoistHook',[1.8,.5,1.8],[dx-12,8.5,dz],metal)
        for i in range(5):
            dx=-35+i*17
            p('Container',[10,5,6],[dx,4,-39],[98,134+i*6,146])
            for k in [-3,0,3]: p('ContainerRib',[.3,4.8,6.3],[dx+k,4,-39],metal)
        for dx in [-35,35]:
            for dz in [10,17]:
                p('SalvageCrate',[3.8,3,3.8],[dx,3,dz],wood)
                for k in [-1.2,1.2]: p('CrateStrap',[.3,3.2,4],[dx+k,3,dz],gold)
    else:
        for dx in [-44,44]:
            for dz in [-20,0,23]:
                p('CaveButtress',[8,14,10],[dx,7,dz],[97,90,130],'Ball')
                for k in [-1,0,1]:
                    h=5 if k else 8
                    p('Amethyst',[1.6,h,1.6],[dx+k*2,2+h/2,dz+k],[185,157,229],rotation=[0,45,k*15],material='Neon' if k==0 else 'SmoothPlastic')
        for i in range(12):
            dx=(-1 if i%2 else 1)*33; dz=-24+i*5
            p('GlowMushroomStem',[.35,1.2,.35],[dx,2.2,dz],cream)
            p('GlowMushroomCap',[1.8,.7,1.8],[dx,2.9,dz],[115,218,218],'Ball',material='Neon')
        for i in range(7):
            p('CaveLayer',[12,4,8],[-39+i*13,18+i%2*3,-43],[116,103,153],'Ball')
    for dx in [-9,9]:
        p('WayfinderPost',[.6,4,.6],[dx,3.5,33],darkwood)
        p('WayfinderLamp',[1,1,1],[dx,5.8,33],gold,material='Neon')

def parts():
    result = []

    def part(group, name, size, position, color, collide=True, shape=None, query=True):
        result.append(dict(group=group, name=name, size=size, position=position,
                           color=color, collide=collide, shape=shape, query=query))

    def island(group, x, z, theme, base=False):
        land, accent = theme
        part(group, 'Sand', [106, 5, 96], [x, -2, z], [226, 206, 161])
        part(group, 'Garden', [84, 1, 72], [x, 1, z], land)
        part(group, 'Path', [8, .25, 62], [x, 1.65, z+2], [233, 217, 179])
        part(group, 'Dock', [12, 1, 26], [x, .5, z+54], [155, 106, 70])
        for name, dx, dz, color in [('Recycler', -16, 18, [58, 127, 113]),
                                    ('Workshop', 16, 18, [168, 115, 68]),
                                    ('Nursery', -17, -15, [171, 145, 203])]:
            part(group, name, [7, 4, 6], [x+dx, 3.8, z+dz], color)
            part(group, name+'Roof', [9, 1, 8], [x+dx, 6.3, z+dz], accent)
            part(group, name+'Sign', [5, 2, .4], [x+dx, 6, z+dz+4], color, False)
            result[-1]['label'] = {'Recycler': 'Переработка / Recycle',
                                  'Workshop': 'Мастерская / Workshop',
                                  'Nursery': 'Питомник / Nursery'}[name]
        for index, (dx, dz) in enumerate([(-36, -29), (36, -29), (-36, 28), (36, 28)]):
            if group == 'cave':
                part(group, f'CrystalPillar{index}', [4, 14, 4], [x+dx, 8, z+dz], accent)
                part(group, f'CrystalTip{index}', [3, 4, 3], [x+dx, 16, z+dz], [214, 196, 243], False, 'Ball', False)
            elif group == 'bay':
                part(group, f'CranePost{index}', [2, 12, 2], [x+dx, 7, z+dz], [115, 140, 151])
                part(group, f'CraneBeam{index}', [8, 1, 2], [x+dx, 13, z+dz], [219, 174, 98], False)
                part(group, f'CraneCable{index}', [.25, 5, .25], [x+dx+3, 10, z+dz], [71, 93, 102], False, query=False)
            else:
                part(group, f'Trunk{index}', [2.5, 8, 2.5], [x+dx, 5, z+dz], [130, 92, 63])
                part(group, f'Crown{index}', [10, 8, 10], [x+dx, 12, z+dz], accent, False, 'Ball')
        for index in range(6):
            part(group, f'Rock{index}', [3+index%3, 2+index%2, 3],
                 [x-42+index*16, 1, z-42], [149, 159, 148], False)
        if not base:
            part(group, 'IslandGate', [14, 1.5, 1.3], [x, 8, z+38], accent, False, query=False)
            result[-1]['label'] = {'shore':'Зелёный берег / Green Shore',
                                  'bay':'Железная бухта / Iron Bay',
                                  'cave':'Кристальные пещеры / Crystal Caves'}[group]
            for side in [-1,1]:
                part(group, 'GatePost', [1, 7, 1], [x+side*6.5, 4.5, z+38], [130,92,63], False, query=False)
        if group == 'cave':
            for i in range(7):
                part(group, f'CavernWall{i}', [13, 12+i%3*3, 7], [x-39+i*13, 6, z-43], [96, 91, 119])
            part(group, 'CavernLintel', [78, 5, 8], [x, 16, z-42], [111, 101, 137])

    themes = [([124, 174, 104], [137, 208, 143]),
              ([111, 140, 139], [168, 183, 166]),
              ([124, 114, 151], [182, 153, 219])]
    part('Ocean', 'Water', [1300, 1, 1000], [350, -6, -100], [56, 148, 172], False)
    for index, name in enumerate(['shore', 'bay', 'cave']):
        island(name, index*400, 0, themes[index])
        detail_island(result,name,index*400,0,name)
        for ornament in range(5):
            x=index*400-37+ornament*18
            if name=='shore':
                part(name, f'FlowerBed{ornament}', [3, .4, 3], [x, 1.9, 31], [94, 151, 94], False, query=False)
                part(name, f'Flower{ornament}', [1, 1, 1], [x, 2.5, 31], [235, 196, 137], False, 'Ball', False)
            elif name=='bay':
                part(name, f'SalvagedMetal{ornament}', [4, 2+ornament%3, 4], [x, 2+ornament%3/2, 31], [137, 156, 164], False, query=False)
                part(name, f'MetalStripe{ornament}', [4.2, .4, 4.2], [x, 3+ornament%3, 31], [208, 173, 104], False, query=False)
            else:
                part(name, f'CrystalGarden{ornament}', [2.5, 4+ornament%3, 2.5], [x, 3+ornament%3/2, 31], [181, 153, 224], False, query=False)
                part(name, f'CrystalBud{ornament}', [1.4, 2, 1.4], [x+2, 2.5, 31], [213, 192, 237], False, 'Ball', False)
    for slot in range(1, 9):
        x=((slot-1)%4-1.5)*150
        z=-240-((slot-1)//4)*150
        island(f'Base{slot}', x, z, themes[0], True)
        detail_island(result,f'Base{slot}',x,z,'shore',True)
        part(f'Base{slot}', 'SpawnPad', [8, .5, 8], [x, 1.9, z+22], [219, 239, 187], False)
    part('EventArt', 'EventRing', [18, .4, 18], [400, 1.8, -50], [191, 143, 82], False)
    # Walkable event platform attaches to the northern shore.
    part('EventArt', 'EventPlatform', [26, 3, 30], [400, -.2, -49], [143, 132, 103])
    # Only one initial spawn; runtime teleports each owner to their assigned base.
    result.append(dict(group='shore', name='WelcomeSpawn', **{'class':'SpawnLocation'},
                       size=[8, 1, 8], position=[0, 2, 24], color=[220, 236, 194]))
    return result
