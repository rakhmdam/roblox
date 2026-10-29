"""Original procedural block art, deterministically baked into editable place geometry."""
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
            part(group, 'IslandGate', [10, 10, 2], [x, 6, z+38], accent, False)
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
        part(f'Base{slot}', 'SpawnPad', [8, .5, 8], [x, 1.9, z+22], [219, 239, 187], False)
    part('EventArt', 'EventRing', [18, .4, 18], [400, 1.8, -50], [191, 143, 82], False)
    # Walkable event platform attaches to the northern shore.
    part('EventArt', 'EventPlatform', [26, 3, 30], [400, -.2, -49], [143, 132, 103])
    # Only one initial spawn; runtime teleports each owner to their assigned base.
    result.append(dict(group='shore', name='WelcomeSpawn', **{'class':'SpawnLocation'},
                       size=[8, 1, 8], position=[0, 2, 24], color=[220, 236, 194]))
    return result
