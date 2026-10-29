--!strict
local positions: {{number}} = {}
for row = 0, 5 do
	for column = 0, 5 do
		local x = if column < 3 then -25 + column * 8 else 9 + (column - 3) * 8
		table.insert(positions, {x, 2.8, -25 + row * 6})
	end
end
return table.freeze({positions=positions})
