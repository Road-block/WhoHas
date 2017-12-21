WhoHasConfig = {
   enabled   = 1,
   totals    = 1,
   stacks    = 1,
   inbox     = 1,
   keyring   = 1,
   bags      = 1,
   equipment = 1,
   allfactions = nil
}

WhoHas = {}

WhoHas.state = {
   savedName = "";
   player = "";
   realm = "";
   faction = "";
   tooltipText = {};
   altCache = {};
   playerCache = {};
   inventoryChanged = 1;
}

-- these are internal strings, not for display
WhoHas.categories = {
   "Inventory",
   "Bank",
   "Inbox",
   "Keyring",
   "Equipment",
   "InvBags",
   "BankBags",
}

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

function WhoHas.camelCase(word)
  return string.gsub(word,"(%a)([%w_']*)",function(head,tail) 
    return string.format("%s%s",string.upper(head),string.lower(tail)) 
    end)
end

-------------------------------------------------------------------------------
-- OnLoad
-------------------------------------------------------------------------------

function WhoHas.OnLoad()
   SlashCmdList["WHOHAS"] = WhoHas.ShowConfigFrame;
   tinsert(UISpecialFrames, "WhoHasConfigFrame");

   if (PossessionsData) then
      WhoHas.ScanAlts = WhoHas.ScanAltsPoss;
      WhoHas.ScanPlayer = WhoHas.ScanPlayerPoss;
      WhoHas.RefreshAlts = WhoHas.RefreshAltsPoss;
   elseif (myProfile) then
      WhoHas.ScanAlts = WhoHas.ScanAltsCP;
      WhoHas.ScanPlayer = WhoHas.ScanPlayerCP;
      WhoHas.RefreshAlts = WhoHas.RefreshAltsCP;
   else
      WhoHas.ScanAlts = WhoHas.DoNothing;
      WhoHas.ScanPlayer = WhoHas.DoNothing;
      WhoHas.RefreshAlts = WhoHas.DoNothing;
   end

   WhoHas.Orig_SetItemRef = SetItemRef
   SetItemRef             = WhoHas.SetItemRef

   WhoHas.Orig_SendMail   = SendMail
   SendMail               = WhoHas.SendMail

   WhoHas.Orig_ReturnInboxItem = ReturnInboxItem
   ReturnInboxItem             = WhoHas.ReturnInboxItem

   if (Baggins) then
      Baggins.Orig_CreateItemButton = Baggins.CreateItemButton;
      Baggins.CreateItemButton = WhoHas.Baggins_CreateItemButton;
   end

   if (Possessions_ItemButton_OnEnter) then
      WhoHas_Possessions_ItemButton_OnEnter = Possessions_ItemButton_OnEnter
      Possessions_ItemButton_OnEnter        = WhoHas.Possessions_ItemButton_OnEnter
   end

   WhoHas.timerFrame = CreateFrame("FRAME")
   for event in pairs(WhoHas.Events) do
      this:RegisterEvent(event);
   end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

WhoHas.Events = {}

function WhoHas.OnEvent()
   local func = WhoHas.Events[event];
   if (func) then
      func(arg1, arg2);
   end
end

function WhoHas.Events.PLAYER_LOGIN()
   if UnitIsConnected("player") and WhoHas.state.loaded then
      WhoHas.timeSinceLast = 0
      WhoHas.timerFrame:SetScript("OnUpdate",function() WhoHas.DelayInit(arg1) end)
      WhoHas.state.player = UnitName("player");
      WhoHas.state.realm = GetRealmName();
      WhoHas.state.faction = UnitFactionGroup("player");
   end
end

function WhoHas.Events.VARIABLES_LOADED()
   WhoHas.state.loaded = true
end

function WhoHas.DelayInit(elapsed)
   WhoHas.timeSinceLast = WhoHas.timeSinceLast + elapsed
   if WhoHas.timeSinceLast > 5 then
      WhoHas.timeSinceLast = 0
      WhoHas.timerFrame:SetScript("OnUpdate",nil)
      WhoHas.ScanAlts();
   end
end

function WhoHas.InventoryChanged()
   WhoHas.state.inventoryChanged = 1;
end

WhoHas.Events.UNIT_INVENTORY_CHANGED = WhoHas.InventoryChanged;
WhoHas.Events.BAG_UPDATE             = WhoHas.InventoryChanged;

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function WhoHas.OnShow()
   WhoHas.ShowTooltip(GameTooltip);
end

function WhoHas.SetItemRef(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11)
   WhoHas.Orig_SetItemRef(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11)
   WhoHas.ShowTooltip(ItemRefTooltip);
end

function WhoHas.Possessions_ItemButton_OnEnter(args)
   -- don't doctor tooltips inside of Possessions
   WhoHas.skip = true;
   WhoHas_Possessions_ItemButton_OnEnter(args);
   WhoHas.skip = nil;
end

function WhoHas.ShowConfigFrame()
   WhoHasConfigFrame:Show()
end

function WhoHas.SendMail(target, subject, body)
   WhoHas.Orig_SendMail(target, subject, body);
   
   -- proper-case the name
   local properName
   properName = WhoHas.camelCase(target);
   if (WhoHas.state.altCache[properName]) then
      for i = 1, 12 do
         local item, _, qty, _ = GetSendMailItem(i);
         if (item) then
            WhoHas.state.altCache[properName][item] = WhoHas.state.altCache[properName][item] or {};
            WhoHas.state.altCache[properName][item].Inbox = (WhoHas.state.altCache[properName][item].Inbox or 0) + qty;
         end
      end
   end
   WhoHas.InventoryChanged()
end

function WhoHas.ReturnInboxItem(mailID)
   local _, _, sender, _ = GetInboxHeaderInfo(mailID);

   sender = string.lower(sender);
   if (WhoHas.state.altCache[sender]) then
      for i = 1, 12 do
         local item, _, qty, _ = GetInboxItem(mailID, i);
         if (item) then
            WhoHas.state.altCache[sender][item] = WhoHas.state.altCache[sender][item] or {};
            WhoHas.state.altCache[sender][item].Inbox = (WhoHas.state.altCache[sender][item].Inbox or 0) + qty;
         end
      end
   end

   WhoHas.Orig_ReturnInboxItem(mailID);
   WhoHas.InventoryChanged()
end

-------------------------------------------------------------------------------
-- Test hooks - not used
-------------------------------------------------------------------------------

function WhoHas.ResetCursor()
   WhoHas.Orig_ResetCursor()
   GameTooltip:AddLine("ResetCursor");
   WhoHas.ShowTooltip(GameTooltip);
end

function WhoHas.CursorUpdate()
   WhoHas.Orig_CursorUpdate()
   GameTooltip:AddLine("CursorUpdate");
   WhoHas.ShowTooltip(GameTooltip);
end

function WhoHas.OnUpdate(self, elapsed)
   local owner = self:GetOwner();
   if (owner and owner.UpdateTooltip and not owner.WhoHas_UpdateTooltip) then
      owner.WhoHas_UpdateTooltip = owner.UpdateTooltip;
      owner.UpdateTooltip = WhoHas.UpdateTooltip;
   end
   WhoHas.Orig_OnUpdate(self, elapsed);
end

function WhoHas.UpdateTooltip(self)
   self:WhoHas_UpdateTooltip();
   GameTooltip:AddLine("UpdateTooltip");
   WhoHas.ShowTooltip(GameTooltip);
end

function WhoHas.SetInventoryItem(self, unit, slot, nameOnly)
   WhoHas.Orig_SetInventoryItem(self, unit, slot, nameOnly);
   GameTooltip:AddLine("SetInventoryItem");
   WhoHas.ShowTooltip(self);
end

function WhoHas.SetBagItem(self, bag, slot)
   WhoHas.Orig_SetBagItem(self, bag, slot);
   GameTooltip:AddLine("SetBagItem");
   WhoHas.ShowTooltip(self);
end

-------------------------------------------------------------------------------
-- Baggins support
-------------------------------------------------------------------------------

-- Nasty Baggins hacks here

-- Baggins doesn't really need the periodic UpdateTooltip
-- as far as I can tell.  When it's called, it wipes out
-- the current tooltip, which no other UpdateTooltip seems to do.
-- Any method I try to use to restore the tooltip results in everything
-- *except* Baggins getting the tooltip info twice.
-- So, here we hijack the original Baggins UpdateTooltip method and rename
-- it, so that GameTooltip doesn't call it.  But we need to leave
-- a method named UpdateTooltip in place for the Baggins
-- OnEnter handler.  And we also have to hook the original OnEnter
-- handler to call the renamed UpdateTooltip function.

function WhoHas.Baggins_CreateItemButton(self, sectionframe, item)
   local button = self:Orig_CreateItemButton(sectionframe, item);
   button.OrigOnEnter = button:GetScript("OnEnter");
   button:SetScript("OnEnter", WhoHas.Baggins_OnEnter);
   button.OrigUpdateTooltip = button.UpdateTooltip;
   button.UpdateTooltip = WhoHas.DoNothing;
   return button;
end

function WhoHas.Baggins_OnEnter(button)
   button = button or this;
   button:OrigOnEnter();
   button:OrigUpdateTooltip();
end

-------------------------------------------------------------------------------
-- Tooltip display
-------------------------------------------------------------------------------

function WhoHas.ShowTooltip(tooltip, link)
   if (tooltip and WhoHasConfig.enabled and not WhoHas.skip) then
      local name = getglobal(tooltip:GetName().."TextLeft1"):GetText();
      if (not name or name == "") then
         return;
      end

      if (WhoHas.state.inventoryChanged) then
         WhoHas.ScanPlayer();
         WhoHas.state.inventoryChanged = nil;
         WhoHas.state.savedName = "";
      end

      if (name ~= WhoHas.state.savedName) then
         WhoHas.state.tooltipText = {};
         WhoHas.state.savedName = name;
         WhoHas.GetText(name, WhoHas.state.tooltipText);
      end

      for i, line in ipairs(WhoHas.state.tooltipText) do
         tooltip:AddLine(line);
      end
      tooltip:Show();
   end
end

function WhoHas.GetText(name, text)
   local total = WhoHas.ListOwners(name, text);
   if (WhoHasConfig.totals and total > 0) then
      table.insert(text, string.format(WhoHas.formats.total, total));
   end
   if (WhoHasConfig.stacks) then
      local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, invTexture = GetItemInfo(name);
      if (itemStackCount and itemStackCount > 1) then
         table.insert(text, string.format(WhoHas.formats.stack, itemStackCount));
      end
   end
end

function WhoHas.ListOwners(name, text)
   local total = 0;
   if (WhoHas.state.playerCache[name]) then
      total = total + WhoHas.ListChar(WhoHas.state.player, WhoHas.state.playerCache[name], text);
   end
   for charName, charData in pairs(WhoHas.state.altCache) do
      if (charData[name]) then
         total = total + WhoHas.ListChar(charName, charData[name], text);
      end
   end
   return total;
end

function WhoHas.ListChar(charName, charData, text)
   local total = 0;
   for i, category in ipairs(WhoHas.categories) do
      local count = charData[category];
      if count and count > 0 then
         table.insert(text, string.format(WhoHas.formats[category], count, charName));
         total = total + count;
      end
   end
   return total;
end

-------------------------------------------------------------------------------
-- Possessions support
-------------------------------------------------------------------------------

WhoHas.Poss = {}
WhoHas.Poss.Lauchsuppe = {
   Inventory = { 0, 1, 2, 3, 4 },
   Bank      = { -1, 5, 6, 7, 8, 9, 10, 11 },
   Keyring   = { -2 },
   Equipment = { -3 },
   Inbox     = { -4 },
   InvBags   = { -5 },
   BankBags  = { -6 }
}

WhoHas.Poss.Siz = {
   Inventory = { 0, 1, 2, 3, 4 },
   Bank      = { -1, 5, 6, 7, 8, 9, 10, 11 },
   Equipment = { -2 },
   Inbox     = { -3 },
   Keyring   = { -4 }
}

function WhoHas.ScanPlayerPoss()
   local slots;

   if (POSS_USEDBANKBAGS_CONTAINER) then
      slots = WhoHas.Poss.Lauchsuppe;
   else
      slots = WhoHas.Poss.Siz;
   end

   local charData;
   if (PossessionsData and PossessionsData[WhoHas.state.realm]) then
      charData = PossessionsData[WhoHas.state.realm][string.lower(WhoHas.state.player)];
   end
   if (charData) then
      WhoHas.state.playerCache = {};
      WhoHas.ScanCharPoss(WhoHas.state.player, charData, slots, WhoHas.state.playerCache);
   end
end

function WhoHas.ScanAltsPoss()
   local slots;

   if (POSS_USEDBANKBAGS_CONTAINER) then
      slots = WhoHas.Poss.Lauchsuppe;
   else
      slots = WhoHas.Poss.Siz;
   end
   local properName
   local realm = tostring(WhoHas.state.realm)
   if (PossessionsData and PossessionsData[realm] and next(PossessionsData[realm])) then
      for charName, charData in pairs(PossessionsData[realm]) do
         if (charName and charData and (WhoHasConfig.allfactions or charData.faction == WhoHas.state.faction)) then
            -- Possessions lower-cases character names, annoyingly
            properName = WhoHas.camelCase(charName);
            if (properName ~= WhoHas.state.player) then
               WhoHas.state.altCache[properName] = {};
               WhoHas.ScanCharPoss(properName, charData, slots, WhoHas.state.altCache[properName]);
            end
         end
      end
   end
end

function WhoHas.RefreshAltsPoss()
   local slots;

   if (POSS_USEDBANKBAGS_CONTAINER) then
      slots = WhoHas.Poss.Lauchsuppe;
   else
      slots = WhoHas.Poss.Siz;
   end

   if (WhoHas.state.altsChanged and PossessionsData and PossessionsData[WhoHas.state.realm]) then
      for i, charName in ipairs(WhoHas.state.altsChanged) do
         local charData = PossessionsData[WhoHas.state.realm][string.lower(charName)];
         if (charData) then
            WhoHas.state.altCache[charName] = {};
            WhoHas.ScanCharPoss(charName, charData, slots, WhoHas.state.altCache[charName]);
         end
      end
   end
end

function WhoHas.ScanCharPoss(charName, charData, slots, cache)
   if (charData and charData.items) then
      WhoHas.ScanBagsPoss(charName, "Inventory", charData.items, slots.Inventory, cache);
      WhoHas.ScanBagsPoss(charName, "Bank", charData.items, slots.Bank, cache);
      if (WhoHasConfig.inbox) then
         WhoHas.ScanBagsPoss(charName, "Inbox", charData.items, slots.Inbox, cache);
      end
      if (WhoHasConfig.keyring) then
         WhoHas.ScanBagsPoss(charName, "Keyring", charData.items, slots.Keyring, cache);
      end
      if (WhoHasConfig.equipment) then
         WhoHas.ScanBagsPoss(charName, "Equipment", charData.items, slots.Equipment, cache);
      end
      if (WhoHasConfig.bags and slots.InvBags) then
         WhoHas.ScanBagsPoss(charName, "InvBags", charData.items, slots.InvBags, cache);
      end
      if (WhoHasConfig.bags and slots.BankBags) then
         WhoHas.ScanBagsPoss(charName, "BankBags", charData.items, slots.BankBags, cache);
      end
   end
end

function WhoHas.ScanBagsPoss(char, slot, bags, bagIndex, cache)
   for _, index in pairs(bagIndex) do
      if (bags[index]) then
         for i, item in pairs(bags[index]) do
            if (item and item[1]) then
               local name = item[1];
               local count = item[3] or 1;
               if (not cache[name]) then
                  cache[name] = {};
               end
               cache[name][slot] = count + (cache[name][slot] or 0);
            end
         end
      end
   end
end

-------------------------------------------------------------------------------
-- CharacterProfiler support
-------------------------------------------------------------------------------

function WhoHas.ScanPlayerCP()
   local charData;
   if (myProfile and myProfile[WhoHas.state.realm] and myProfile[WhoHas.state.realm].Character) then
      charData = myProfile[WhoHas.state.realm].Character[WhoHas.state.player];
   end
   if (charData) then
      WhoHas.state.playerCache = {};
      WhoHas.doBagsCP(charName, charData.Inventory, "Inventory", WhoHas.formats.Inventory, WhoHas.state.playerCache);
      WhoHas.doBagsCP(charName, charData.Bank, "Bank", WhoHas.formats.Bank, WhoHas.state.playerCache);
      WhoHas.doInboxCP(charName, charData.MailBox, "Inbox", WhoHas.formats.Inbox, WhoHas.state.playerCache);
   end
end

function WhoHas.ScanAltsCP()
   if (myProfile and myProfile[WhoHas.state.realm] and myProfile[WhoHas.state.realm].Character) then
      for charName, charData in pairs(myProfile[WhoHas.state.realm].Character) do
         if (charName ~= WhoHas.state.player and (WhoHasConfig.allfactions or charData and charData.FactionEn == WhoHas.state.faction)) then
            WhoHas.state.altCache[charName] = {};
            WhoHas.doBagsCP(charName, charData.Inventory, "Inventory", WhoHas.formats.Inventory, WhoHas.state.altCache[charName]);
            WhoHas.doBagsCP(charName, charData.Bank, "Bank", WhoHas.formats.Bank, WhoHas.state.altCache[charName]);
            WhoHas.doInboxCP(charName, charData.MailBox, "Inbox", WhoHas.formats.Inbox, WhoHas.state.altCache[charName]);
         end
      end
   end
end

function WhoHas.RefreshAltsCP()
   if (WhoHas.state.altsChanged and myProfile and myProfile[WhoHas.state.realm] and myProfile[WhoHas.state.realm].Character) then
      for i, charName in ipairs(WhoHas.state.altsChanged) do
         local charData = myProfile[WhoHas.state.realm].Character[charName];
         WhoHas.state.altCache[charName] = {};
         WhoHas.doBagsCP(charName, charData.Inventory, "Inventory", WhoHas.formats.Inventory, WhoHas.state.altCache[charName]);
         WhoHas.doBagsCP(charName, charData.Bank, "Bank", WhoHas.formats.Bank, WhoHas.state.altCache[charName]);
         WhoHas.doInboxCP(charName, charData.MailBox, "Inbox", WhoHas.formats.Inbox, WhoHas.state.altCache[charName]);
      end
   end
end

function WhoHas.doBagsCP(char, bags, slot, format, cache)
   if (bags) then
      for bag, bagData in pairs(bags) do
         if (bagData.Slots) then
            for i = 1, bagData.Slots do
               local item = bagData.Contents[i]
               if (item and item.Name) then
                  local count = item.Quantity or 1;
                  if (not cache[item.Name]) then
                     cache[item.Name] = {};
                  end
                  cache[item.Name][slot] = count + (cache[item.Name][slot] or 0);
               end
            end
         end
      end
   end
end

function WhoHas.doInboxCP(char, inbox, slot, format, cache)
   if (inbox) then
      for i, msg in ipairs(inbox) do
         if (msg) then
            local item = msg.Item;
            if (item and item.Name) then
               local count = item.Quantity or 1;
               if (not cache[item.Name]) then
                  cache[item.Name] = {};
               end
               cache[item.Name][slot] = count + (cache[item.Name][slot] or 0);
            end
         end
      end
   end
end

function WhoHas.DoNothing()
end
