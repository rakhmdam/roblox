"""Original procedural block art, deterministically baked into editable place geometry."""
def parts():
    result = []

    def part(group, name, size, position, color, collide=True):
        result.append(dict(group=group, name=name, size=size, position=position,
                           color=color, collide=collide))

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
        for index, (dx, dz) in enumerate([(-36, -29), (36, -29), (-36, 28), (36, 28)]):
            part(group, f'Trunk{index}', [2.5, 8, 2.5], [x+dx, 5, z+dz], [130, 92, 63])
            part(group, f'Crown{index}', [10, 8, 10], [x+dx, 12, z+dz], accent, False)
        for index in range(6):
            part(group, f'Rock{index}', [3+index%3, 2+index%2, 3],
                 [x-42+index*16, 1, z-42], [149, 159, 148], False)
        if not base:
            part(group, 'IslandGate', [10, 10, 2], [x, 6, z+38], accent, False)

    themes = [([124, 174, 104], [137, 208, 143]),
              ([111, 140, 139], [168, 183, 166]),
              ([124, 114, 151], [182, 153, 219])]
    part('Ocean', 'Water', [1300, 1, 1000], [350, -6, -100], [56, 148, 172], False)
    for index, name in enumerate(['shore', 'bay', 'cave']):
        island(name, index*400, 0, themes[index])
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
