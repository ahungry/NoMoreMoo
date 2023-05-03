local defaultFrame = DEFAULT_CHAT_FRAME
local defaultWrite = DEFAULT_CHAT_FRAME.AddMessage
local log = function(text, r, g, b, group, holdTime)
  defaultWrite(defaultFrame, tostring(text), r, g, b, group, holdTime)
end

local hookChatFrame = function(frame)
   if (not frame) then return end

   local original = frame.AddMessage
   if (original) then
      frame.AddMessage = function(t, message, ...)
         if (NoMoreMoo_Enabled) then
            local is_gm = string.find(message, "^%[%d+. ([^%]]+)%] <DND>")
            local is_mod_reference = string.find(string.lower(message), "nomoremoo")

            if (is_gm or is_mod_reference) then
               original(t, "Skipping suppression on GM/mod reference messages", unpack (arg))
               original(t, message, unpack (arg))
               return
            end

            local found, _, channel, player, comment = string.find(message, "^%[%d+. ([^%]]+)%].*%[([^%]]+)%][^ ]* (.*)")

            if (found and channel) then
               channel = string.lower(channel)
               if ((channel == "world") or (channel == "trade") or (channel == "nmm")) then
                  -- TODO: Rollup of multiple messages and report all that came through
                  -- TODO: Split gold/moo into separate filters
                  if (NoMoreMoo_FindKeyword(message) and not NoMoreMoo_IsItemLink(message)) then
                     original(t, string.format("Saw a moo by %s (%s) at %s - ignoring it", player, comment, time()), unpack (arg))
                     return
                  end
               end
            end
         end
         original(t, message, unpack (arg))
      end
   else
      log("Tried to hook non-chat frame")
   end
end

-- /script DEFAULT_CHAT_FRAME:AddMessage("\124cffff70dd[Arcanite Reaper]\124h\124r", 5);
-- /script SendChatMessage("\124cffff70dd[Moo]\124h\124r" ,"CHANNEL" ,DEFAULT_CHAT_FRAME.editBox.languageID,"5");
function NoMoreMoo_IsItemLink(message)
   if (string.find(message, "\124Hitem:")) then
      return true
   end
   return false
end

function NoMoreMoo_FindKeyword(message)
  for pattern, _ in pairs(NoMoreMoo_KeyWords) do
    if (string.find(message, pattern)) then
      return true
    end
  end
  return false
end

function NoMoreMoo_OnLoad()
  this:RegisterEvent("VARIABLES_LOADED")

	-- Set up slash commands.
	SlashCmdList["NOMOREMOO"] = NoMoreMoo_CmdRelay
	SLASH_NOMOREMOO1 = "/nmm"
	SLASH_NOMOREMOO2 = "/NoMoreMoo"
end

local hookFunctions = function()
  hookChatFrame(ChatFrame1)
  hookChatFrame(ChatFrame2)
  hookChatFrame(ChatFrame3)
  hookChatFrame(ChatFrame4)
  hookChatFrame(ChatFrame5)
  hookChatFrame(ChatFrame6)
  hookChatFrame(ChatFrame7)
end

local initialize = function()
   -- NoMoreMoo_KeyWords = NoMoreMoo_KeyWords or {["[Mm]+[Oo]+"] = true}
   -- TODO: Merge user settings with the specialized checks we always want
   NoMoreMoo_KeyWords = {["[Mm]+[Oo][Oo]+"] = true, ["\124c"] = true}
   NoMoreMoo_Enabled = NoMoreMoo_Enabled or true
   hookFunctions()

   log(string.format("NoMoreMoo loaded (%s)", (NoMoreMoo_Enabled and "enabled") or "disabled"))
end

-- Event handler.  Checks for non-WhoFrame /whos.
function NoMoreMoo_OnEvent()
	if (event == "VARIABLES_LOADED") then
    initialize()
	end
end

local commands = setmetatable({

  ["add"] = function(args)
    local found, _, keyword = string.find(args or "", "^%s*(%S+)")
    if (found) then
      NoMoreMoo_KeyWords[keyword] = true
      log(string.format("Added '%s' to list." , keyword))
    else
      log("/nmm add <keyword> - add a keyword to the list.")
    end
  end,

  ["del"] = function(args)
    local found, _, keyword = string.find(args or "", "^%s*(%S+)")
    if (found) then
      if (NoMoreMoo_KeyWords[keyword]) then
        NoMoreMoo_KeyWords[keyword] = nil
        log(string.format("Removed '%s' from the list." , keyword))
      else
        log(string.format("'%s' is not on the list." , keyword))
      end
    else
      log("/nmm del <keyword> - removes a keyword from the list.")
    end
  end,

  ["on"] = function(args)
    NoMoreMoo_Enabled = true
    log("NoMoreMoo enabled")
  end,


  ["off"] = function(args)
    NoMoreMoo_Enabled = false
    log("NoMoreMoo disabled")
  end,

  ["list"] = function()
    local keywords = {}
    log("Keywords on the list:")
    for keyword,_ in pairs(NoMoreMoo_KeyWords) do
      table.insert(keywords, keyword)
    end
    log(table.concat(keywords, ", "))
  end,

}, {
  __index = function()
    return function()
      log("NoMoreMoo - Filters World channel by keywords")
      log("Commands:")
      log("  /nmm add <keyword> - add a keyword to the list.")
      log("  /nmm del <keyword> - removes a keyword from the list.")
      log("  /nmm list          - lists all keywords currently active.")
      log("  /nmm on/off        - temporarily disables or re-enables World Filter.")
      log("Note: all keywords are treated as regular expressions!")
    end
  end
})

-- Command-line handler.  Passes to other functions.
function NoMoreMoo_CmdRelay(args)
	if args then
		_, _, cmd, subargs = string.find (args, "^%s*(%S-)%s(.+)$")
		if not cmd then
			cmd = args
		end
    commands[string.lower(cmd)](subargs)
	end
end
