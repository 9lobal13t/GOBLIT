--!strict
-- Визуальные константы интерфейса: цвета, шрифты, размеры.
-- Палитра — тёмный фон с тёплыми и магическими акцентами, как в окружении (ТЗ 21.1).

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local Theme = {
	Colors = {
		Panel = hex("#16131c"),
		PanelRaised = hex("#211c2a"),
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
		Regular = Font.fromEnum(Enum.Font.BuilderSans),
		Medium = Font.fromEnum(Enum.Font.BuilderSansMedium),
		Bold = Font.fromEnum(Enum.Font.BuilderSansBold),
		Heavy = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	},

	TextSize = {
		Small = 14,
		Body = 16,
		Title = 22,
		Big = 28,
	},

	CornerRadius = 8,
	PanelTransparency = 0.12,
}

return table.freeze(Theme)
