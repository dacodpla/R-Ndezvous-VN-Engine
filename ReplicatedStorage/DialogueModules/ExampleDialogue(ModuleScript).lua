-- ExampleDialogue(ModuleScript).lua
-- Showcases: transitions, SFX, BGM, face/animation changes, lookAt, typewriter sounds,
-- choices, sync teleport, actions, and afterDialogue instructions — with 4th-wall breaks.

return {
	-- Intro transition
	{
		transition = {
			type = "staticText",
			messages = { "Meta Test – Every Feature Active" },
			duration = 2
		},
		-- Initial actions: move NPCs into place before the scene starts
		actions = {
			{ actor = "Haruka", moveTo = Vector3.new(50, 0.5, 150), waitUntilArrive = true },
			{ actor = "Takumi", moveTo = Vector3.new(48, 0.5, 152) }
		}
	},

	-- Standard line with BGM and face change
	{
		speaker = "Haruka",
		text = "Welcome, Player… we’re literally inside a GitHub example script!",
		bgm = "mysteryTheme",
		face = "happy",
		animation = "IdleTalk",
		typeSound = "MainType",
		lookAt = "Takumi"
	},

	-- SFX and head turn
	{
		speaker = "Takumi",
		text = "Yup. The dev is testing **every** single feature—watch closely!",
		sfx = "alert",
		head = "default",
		face = "default",
		animation = "IdleTalk",
		typeSound = "MainType"
	},

	-- Choice branch demonstration
	{
		speaker = "Ayaka",
		text = "How do you feel about characters breaking the fourth wall?",
		choices = {
			resetOnRepeat = true,
			{
				text = "Love it!",
				next = {
					{ speaker = "Ayaka", text = "Hehe~ Meta humor is the best!", face = "happy", animation = "JumpExcited" },
					{ speaker = "Zlarc", text = "Figures. You’re as chaotic as the dev.", face = "smirk", animation = "IdleRetro2" }
				}
			},
			{
				text = "Please stop.",
				next = {
					{ speaker = "Ayaka", text = "Alright, alright… back to immersion.", face = "sad", animation = "IdleSad" },
					{ speaker = "Zlarc", text = "Finally, someone serious around here.", face = "angry", animation = "IdleRetro2" }
				}
			}
		}
	},

	-- Teleport transition mid-scene
	{
		transition = {
			type = "syncTeleport",
			messages = { "Reality glitches—you all warp elsewhere!" },
			duration = 1.5,
			teleport = { target = "MetaRoom" }
		},
		actions = {
			-- Move an NPC immediately after teleport
			{ actor = "Zlarc", moveTo = Vector3.new(60, 0.5, 145), waitUntilArrive = false }
		}
	},

	-- AfterDialogue instructions will trigger after this line completes
	{
		speaker = "Zlarc",
		text = "When this ends, watch what happens—flags, attributes, and following behaviors!",
		face = "annoyed",
		animation = "IdleRetro2",
		typeSound = "ZlarcType",
		afterDialogue = {
			-- Story flag setting
			{ type = "SetFlag", flag = "MetaExampleSeen", value = true },
			-- Start following the player
			{ type = "FollowPlayer", npc = "Haruka" },
			-- Change dialogue module for Ayaka
			{ type = "ChangeDialogue", npc = "Ayaka", newDialogue = "Ayaka_PostMeta" },
			-- Modify an attribute on an interactable object
			{ type = "SetAttribute", target = "MysteryBox", key = "Unlocked", value = true },
			-- Destroy a placeholder object
			{ type = "Destroy", target = "TemporaryWall" },
		}
	},

	-- Wrap-up line
	{
		speaker = "Takumi",
		text = "And… scene! This proves every system works—animations, SFX, choices, actions, after-dialogue, all of it.",
		face = "default",
		animation = "IdleTalk",
		typeSound = "MainType"
	}
}
