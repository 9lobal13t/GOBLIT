--!strict
-- Визуальные константы интерфейса: цвета, шрифты, размеры.
-- Палитра — тёмный фон с тёплыми и магическими акцентами, как в окружении (ТЗ 21.1).
--
-- Шрифт — Roboto. В Montserrat кириллица рисуется с промежутками внутри слов почти во всех
-- начертаниях, и дефект зависит от размера текста (проверка R19, docs/PITFALLS.md). Из семи
-- проверенных семейств чистыми на размерах 11–22 оказались Roboto, Nunito и SourceSans;
-- выбран Roboto как самый разборчивый на мелком тексте телефона.
-- Символы в тексте — только распространённые (× … —).
--
-- Семейство берётся из Enum.Font, а не строкой: путь к файлу семейства тогда не нужно угадывать.
local ROBOTO = Font.fromEnum(Enum.Font.Roboto).Family

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
		Regular = Font.new(ROBOTO, Enum.FontWeight.Regular),
		Medium = Font.new(ROBOTO, Enum.FontWeight.Medium),
		Bold = Font.new(ROBOTO, Enum.FontWeight.Bold),
		Heavy = Font.new(ROBOTO, Enum.FontWeight.ExtraBold),
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
