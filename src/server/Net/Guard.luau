--!strict
-- Проверка аргументов, пришедших от клиента. Клиенту нельзя доверять ни тип,
-- ни размер, ни диапазон значения: всё приходит как unknown и проверяется здесь.

local Guard = {}

-- Непустая строка не длиннее maxLength байт, без управляющих символов.
function Guard.shortString(value: unknown, maxLength: number): string?
	if type(value) ~= "string" then
		return nil
	end
	local text = value :: string
	if #text == 0 or #text > maxLength or string.find(text, "%c") then
		return nil
	end
	return text
end

return table.freeze(Guard)
