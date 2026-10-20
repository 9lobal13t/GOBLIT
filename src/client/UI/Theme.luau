--!strict
-- Визуальные константы интерфейса: цвета, шрифты, размеры.
-- Палитра — тёмный фон с тёплыми и магическими акцентами, как в окружении (ТЗ 21.1).
--
-- Шрифт — Montserrat: интерфейс на русском, а для Montserrat кириллица в Roblox проверена
-- на практике (docs/LESSONS_BRAINROT_BANDITS.md, раздел 3). Для Builder Sans подтверждения
-- кириллицы найти не удалось. Символы в тексте — только распространённые (× … —).

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {
	Colors = {
		Panel = hex("#16131c"),
		PanelRaised = hex("#211c2a"),
		Control = hex("#2c2636"),
		Border = hex("#3a3347"),
		Text = hex("#f2eef7"),
		TextDim = hex("#a59db3"),
		Accent = hex("#9b6bff"),
		AccentDim = hex("#3a2b5c"),

		Health = hex("#e0475b"),
		HealthBack = hex("#3a1820"),
		Stamina = hex("#f2c14e"),
		StaminaBack = hex("#3a3018"),

		Gold = hex("#f4cf72"),
		Shards = hex("#b46bff"),
		Knowledge = hex("#6bb6ff"),

		Info = hex("#6bb6ff"),
		Success = hex("#5fd35f"),
		Warning = hex("#f2c14e"),
		Error = hex("#ff5d6c"),
	},

	Fonts = {
		Regular = Font.new(MONTSERRAT, Enum.FontWeight.Regular),
		Medium = Font.new(MONTSERRAT, Enum.FontWeight.Medium),
		Bold = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
		Heavy = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
	},

	TextSize = {
		Small = 14,
		Body = 16,
		Title = 22,
		Big = 28,
	},

	-- Минимальная высота любой кнопки: удобная цель для пальца (44 точки).
	TouchTarget = 44,
	CornerRadius = 8,
	PanelTransparency = 0.12,
}

return table.freeze(Theme)
