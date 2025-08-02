return {
	{
		transition = {
			type = "staticText",
			messages = { "Day 1 - Arrival" },
			duration = 2
		}
	},
	{
		speaker = "Ayaka",
		text = "HIIIIIII TAKUMI!!!!",
		typeSound = "ayakaType",
		sfx = "alert",
		animation = "JumpExcited",
		face = "happy",
		head = "SmilingHead"
	},
	{
		speaker = "Takumi",
		text = "Ayaka?! You're here already?",
		typeSound = "MainType",
		animation = "Shock",
		face = "surprised",
		head = "default"
	},
	{
		speaker = "Ayaka",
		text = "Of course! I couldn’t wait!",
		typeSound = "ayakaType",
		animation = "IdleExcited",
		face = "wink",
		bgm = "happyTheme",
		lookAt = "Takumi"
	},
	{
		speaker = "Zlarc",
		text = "Tch. Loud as always...",
		face = "annoyed",
		animation = "IdleRetro2",
		typeSound = "ZlarcType",
		lookAt = "Ayaka"
	},
	{
		transition = {
			type = "syncTeleport",
			messages = { "Later that day..." },
			duration = 1.5,
			teleport = {
				target = "LobbySpot"
			}
		}
	},
	{
		speaker = "Ayaka",
		text = "Hey, Takumi... be honest with me.",
		typeSound = "ayakaType",
		animation = "IdleSad",
		face = "neutral"
	},
	{
		speaker = "Ayaka",
		text = "Do you like this game?",
		typeSound = "ayakaType",
		face = "neutral",
		choices = {
			resetOnRepeat = true,
			{
				text = "Yeah! It's amazing.",
				next = {
					{
						speaker = "Ayaka",
						text = "Yay~ I knew you’d say that!",
						animation = "JumpExcited",
						face = "happy",
						typeSound = "ayakaType"
					},
					{
						speaker = "Zlarc",
						text = "Disgusting.",
						face = "angry",
						animation = "IdleRetro2"
					}
				}
			},
			{
				text = "Not really...",
				next = {
					{
						speaker = "Ayaka",
						text = "O-oh... I see...",
						face = "sad",
						animation = "IdleSad",
						typeSound = "ayakaType"
					},
					{
						speaker = "Zlarc",
						text = "Finally. Some honesty.",
						face = "smirk",
						animation = "IdleRetro2"
					}
				}
			}
		}
	},
	{
		speaker = "Takumi",
		text = "Anyway, let's move on.",
		face = "default",
		typeSound = "MainType"
	}
}
