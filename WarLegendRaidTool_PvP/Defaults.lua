---@type string
local AddonName = ...
---@class Data
local Data = select(2, ...)

local allieDefaults15man = {
	Enabled = true,
	minPlayerCount = 6,
	maxPlayerCount = 15,

	Position_X = 150,
	Position_Y = 600,
	BarWidth = 180,
	BarHeight = 28,
	BarVerticalGrowdirection = "downwards",
	BarVerticalSpacing = 3,
	BarColumns = 1,
	BarHorizontalGrowdirection = "rightwards",
	BarHorizontalSpacing = 100,
	
	PlayerCount = {
		Enabled = true,
	},

	ButtonModules = {
		-- WarLegend: after the room of the Dispel debuffs (right of the class icon, Modules/Dispel.lua), smaller than
		-- the enemies' one: no room under the frame here, and the enemy cast bars come from the other side
		CastBar = {
			Enabled = false,
			Scale = 1,
			Points = {
				{
					Point = "LEFT",
					RelativeFrame = "Dispel",
					RelativePoint = "RIGHT",
					OffsetX = 28,
				},
			},
		},
		SpecClassPriorityOne = {
			Cooldown = {
				FontSize = 20,
			},
			Points = {
				{
					Point = "TOPLEFT",
					RelativeFrame = "Button",
					RelativePoint = "TOPRIGHT",
				}
			}
		},
	},

	Framescale = 1,
}
local enemyDefault15man = {
	Enabled = true,
	minPlayerCount = 6,
	maxPlayerCount = 15,

	Position_X = 1100,
	Position_Y = 600,
	BarWidth = 180,
	BarHeight = 28,
	BarVerticalGrowdirection = "downwards",
	BarVerticalSpacing = 3,
	BarColumns = 1,
	BarHorizontalGrowdirection = "rightwards",
	BarHorizontalSpacing = 100,

	PlayerCount = {
		Enabled = true,
	},

	ButtonModules = {
		CastBar = {
			Enabled = false,
			Points = {
				{
					Point = "RIGHT",
					RelativeFrame = "SpecClassPriorityOne",
					RelativePoint = "LEFT",
					OffsetX = -28
				},
			}
		},
		SpecClassPriorityOne = {
			Cooldown = {
				FontSize = 20,
			},
			Points = {
				{
					Point = "TOPRIGHT",
					RelativeFrame = "Button",
					RelativePoint = "TOPLEFT",
				}
			}
		},
	},

	Framescale = 1,
}

Data.defaultSettings = {
	profile = {
		Locked = false,
		Debug = false,
		


		DisableRaidFramesInBattleground = false,

		ShowBGEInBattleground = true,

		MyTarget_Color = {1, 1, 1, 1},
		MyTarget_BorderSize = 2,
		MyFocus_Color = {0, 0.988235294117647, 0.729411764705882, 1},
		MyFocus_BorderSize = 2,
		ShowTooltips = true,
		EnableMouseWheelPlayerTargeting = false,
		ConvertCyrillic = true,

		PlayerCount = {
			Text = {
				FontSize = 14,
				JustifyV = "MIDDLE",
				JustifyH = "LEFT"
			}
		},

		RoleSortingOrder = "HEALER_TANK_DAMAGER",

		Cooldown = {
			ShowNumber = true,
			DrawSwipe = true,
		},

		Text = {
			FontColor = {1, 1, 1, 1},
			FontOutline = "",
			EnableShadow = false,
			ShadowColor = {0, 0, 0, 1}
		},


		Enemies = {
			Enabled = true,

			RangeIndicator_Enabled = true,
			RangeIndicator_Range = 40, --not used anymore, but kept for compatibility
			RangeIndicator_Range_InCombat = 40,
			RangeIndicator_Range_OutOfCombat = 40,
			RangeIndicator_Alpha = 0.55,
			RangeIndicator_Everything = true,
			RangeIndicator_Frames = {},


			ActionButtonUseKeyDown = false,
			UseClique = false,


			LeftButtonType = "Target",
			LeftButtonValue = "",
			RightButtonType = "Focus",
			RightButtonValue = "",
			MiddleButtonType = "Custom",
			MiddleButtonValue = "",

			playerCountConfigs = {
				{
					Enabled = true,
					minPlayerCount = 1,
					maxPlayerCount = 5,

					Position_X = 1100,
					Position_Y = 600,
					BarWidth = 200,
					BarHeight = 47,
					BarVerticalGrowdirection = "downwards",
					BarVerticalSpacing = 40,
					BarColumns = 1,
					BarHorizontalGrowdirection = "rightwards",
					BarHorizontalSpacing = 100,

					PlayerCount = {
						Enabled = false,
					},
					ButtonModules = {
						SpecClassPriorityOne = {
							Width = 52,
							Cooldown = {
								FontSize = 26,
							},
						},
						CastBar = {
							Enabled = true,
							Points = {
								{
									Point = "RIGHT",
									RelativeFrame = "SpecClassPriorityOne",
									RelativePoint = "LEFT",
									OffsetX = -28
								}
							}
						},
						healthBar = {
							HealthTextEnabled = true,
							HealthTextType = "health",
							HealthText = {
								FontSize = 18,
								JustifyV = "BOTTOM"
							}
						},
						Name = {
							Text = {
								JustifyV = "TOP"
							}
						},
						Power = {
							Height = 8,
						},
						RaidTargetIcon = {
							Enabled = false
						},
					},

					Framescale = 1,
				},
				enemyDefault15man,
				{
					Enabled = true,
					minPlayerCount = 16,
					maxPlayerCount = 40,

					Position_X = 1100,
					Position_Y = 600,
					BarWidth = 180,
					BarHeight = 22,
					BarVerticalGrowdirection = "downwards",
					BarVerticalSpacing = 1,
					BarColumns = 1,
					BarHorizontalGrowdirection = "rightwards",
					BarHorizontalSpacing = 100,

					PlayerCount = {
						Enabled = true,
					},
					ButtonModules = {
						CastBar = {
							Enabled = false,
							Points = {
								{
									Point = "RIGHT",
									RelativeFrame = "SpecClassPriorityOne",
									RelativePoint = "LEFT",
									OffsetX = -28
								}
							}
						},
						Power = {
							Enabled = false,
						},
					},

					Framescale = 1,

				}
			},
		},
		Allies = {
			Enabled = true,

			RangeIndicator_Enabled = true,
			RangeIndicator_Range = 40, --not used anymore, but kept for compatibility
			RangeIndicator_Range_InCombat = 40,
			RangeIndicator_Range_OutOfCombat = 40,
			RangeIndicator_Alpha = 0.55,
			RangeIndicator_Everything = true,
			RangeIndicator_Frames = {},

			ActionButtonUseKeyDown = false,
			UseClique = false,

			LeftButtonType = "Target",
			LeftButtonValue = "",
			RightButtonType = "Focus",
			RightButtonValue = "",
			MiddleButtonType = "Custom",
			MiddleButtonValue = "",

			playerCountConfigs = {
				{
					Enabled = true,
					minPlayerCount = 1,
					maxPlayerCount = 5,

					Position_X = 150,
					Position_Y = 600,
					BarWidth = 200,
					BarHeight = 47,
					BarVerticalGrowdirection = "downwards",
					BarVerticalSpacing = 40,
					BarColumns = 1,
					BarHorizontalGrowdirection = "rightwards",
					BarHorizontalSpacing = 100,

					PlayerCount = {
						Enabled = false,
					},
					ButtonModules = {
						-- WarLegend: under the frame, not right of the class icon where the Dispel debuffs are (40 between
						-- rows here). Offsets are screen units: OffsetX leaves room for its icon, left of the bar
						CastBar = {
							Enabled = true,
							Points = {
								{
									Point = "TOPLEFT",
									RelativeFrame = "Button",
									RelativePoint = "BOTTOMLEFT",
									OffsetX = 23,
									OffsetY = -5,
								},
							},
						},
						SpecClassPriorityOne = {
							Width = 52,
							Cooldown = {
								FontSize = 26,
							},
							Points = {
								{
									Point = "TOPLEFT",
									RelativeFrame = "Button",
									RelativePoint = "TOPRIGHT",
								}
							}
						},
						healthBar = {
							HealthTextEnabled = true,
							HealthTextType = "health",
							HealthText = {
								FontSize = 18,
								JustifyV = "BOTTOM"
							}
						},
						Name = {
							Text = {
								JustifyV = "TOP"
							}
						},
						Power = {
							Height = 8,
						},
						RaidTargetIcon = {
							Enabled = false
						},
					},

					Framescale = 1,

				},
				allieDefaults15man,
				{
					Enabled = true,
					minPlayerCount = 16,
					maxPlayerCount = 40,

					Position_X = 150,
					Position_Y = 600,
					BarWidth = 180,
					BarHeight = 22,
					BarVerticalGrowdirection = "downwards",
					BarVerticalSpacing = 1,
					BarColumns = 1,
					BarHorizontalGrowdirection = "rightwards",
					BarHorizontalSpacing = 100,

					PlayerCount = {
						Enabled = true,
					},
					ButtonModules = {
						-- WarLegend: as in allieDefaults15man, after the room of the Dispel debuffs
						CastBar = {
							Enabled = false,
							Scale = 1,
							Points = {
								{
									Point = "LEFT",
									RelativeFrame = "Dispel",
									RelativePoint = "RIGHT",
									OffsetX = 28,
								}
							}
						},
						Power = {
							Enabled = false,
						},
						SpecClassPriorityOne = {
							Points = {
								{
									Point = "TOPLEFT",
									RelativeFrame = "Button",
									RelativePoint = "TOPRIGHT",
								}
							}
						},
					},


					Framescale = 1,

				}
			},
		},
		ButtonModules = {},
	}
}