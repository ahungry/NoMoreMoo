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
            local is_gm = string.find(message, "^%[%d+. ([^%]]+)%] <GM>")
            local is_mod_reference = string.find(string.lower(message), "nomoremoo")

            if (is_gm or is_mod_reference) then
               -- original(t, "Skipping suppression on GM/mod reference messages", unpack (arg))
               original(t, message, unpack (arg))
               return
            end

            -- local found, _, channel, player, comment = string.find(message, "^%[%d+. ([^%]]+)%].*%[([^%]]+)%][^ ]* (.*)")
            -- Try to prevent too far forward read
            local found, _, channel, player, comment = string.find(message, "^%[%d+. ([^%]]+)%][^%[]*%[([^%]]+)%][^ ]* (.*)")

            if (found and channel) then
               channel = string.lower(channel)
               if ((channel == "world") or (channel == "trade") or (channel == "nmm")) then
                  -- TODO: Rollup of multiple messages and report all that came through
                  -- TODO: Split gold/moo into separate filters
                  if (NoMoreMoo_FindKeyword(comment) and not
                      (NoMoreMoo_IsItemLink(comment) or
                       NoMoreMoo_IsClickedLink(comment) or
                       NoMoreMoo_IsNotValidReference(comment))) then
                     -- TODO: make a /nmm debug toggle to control this (see enable/disable)
                     -- original(t, string.format("Saw a moo by %s (%s) at %s - ignoring it", player, comment, time()), unpack (arg))

                     local playerk = string.lower(player)
                     if (not NoMoreMoo_Spamnet[playerk]) then
                        NoMoreMoo_Spamnet[playerk] = {}
                     end
                     local spam = NoMoreMoo_Spamnet[playerk]
                     table.insert(spam, message)
                     -- spam[#spam+1] = message -- string.format("[%s]: %s", player, comment)
                     NoMoreMoo_Spamnet[playerk] = spam -- perhaps redundant if this is by ref

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

function NoMoreMoo_IsClickedLink(message)
   -- -- Or is a clicked reference of some sort - the gold sellers usually don't have the rectangle brackets
   if (string.find(message, "%]")) then
      return true
   end
   return false
end

function NoMoreMoo_IsNotValidReference(message)
   -- -- Or is a clicked reference of some sort - the gold sellers usually don't have the rectangle brackets
   local msg = string.lower(message)
   if (string.find(msg, "moon")) then
      return true
   end
   if (string.find(msg, "mood")) then
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
   NoMoreMoo_KeyWords = {
      ["[Mm]+[Oo][Oo]+"] = true,
      ["\124c"] = true,
      ["[Nn][Oo][Ss][Tt].*100"] = true,
      ["N[O0]ST1"] = true,
      ["nost1"] = true,
      [" GOLD "] = true,
      ["items-Gold-Level-Bags"] = true,
      ["[Nn]....[Ee]....[Ee]....[Dd]....[Mm]....[Aa]....[Nn]....[Aa]"] = true
   }
   NoMoreMoo_Enabled = NoMoreMoo_Enabled or true
   NoMoreMoo_Spamnet = {}
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

  -- ["list"] = function()
  --   local keywords = {}
  --   log("Keywords on the list:")
  --   for keyword,_ in pairs(NoMoreMoo_KeyWords) do
  --     table.insert(keywords, keyword)
  --   end
  --   log(table.concat(keywords, ", "))
  -- end,

  ["list"] = function()
     local spamlist = " --> "
     for spammer, _ in pairs(NoMoreMoo_Spamnet) do
        if ("" == spamlist) then
           spamlist = spammer
        else
           spamlist = string.format("%s, %s", spamlist, spammer)
        end
     end
     log("The following spammers were caught in the net: ")
     log(spamlist)
  end,

  ["net"] = function(args)
     local playerk = string.lower(args)
     if (not NoMoreMoo_Spamnet[playerk]) then
        log(string.format("Player: %s is not in the spam net.", playerk))
        return
     end
     for _, message in pairs(NoMoreMoo_Spamnet[playerk]) do
        log(message)
     end
  end,

  ["clear"] = function(args)
     NoMoreMoo_Spamnet = {}
  end,

}, {
  __index = function()
    return function()
      log("NoMoreMoo - Get rid of moo and gold spam")
      log("Commands:")
      log("  /nmm list           - list everyone spammer in the spamnet.")
      log("  /nmm net <spammer>  - List all caught messages by <spammer>.")
      log("  /nmm clear          - remove all the spam net data")
      -- log("  /nmm add <keyword> - add a keyword to the list.")
      -- log("  /nmm del <keyword> - removes a keyword from the list.")
      log("  /nmm on/off         - temporarily disables or re-enables NoMoreMoo.")
      -- log("Note: all keywords are treated as regular expressions!")
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
