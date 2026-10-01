local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local BagsMod = RoithiUI:GetModule("Bags")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function BagsMod:GetOptions()
    local options = {
        type = "group",
        name = L["Bags"],
        order = 80,
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Modern Bags"],
                        order = 1,
                        get = function() return self.db.enabled ~= false end,
                        set = function(_, val)
                            self.db.enabled = val
                            if val then
                                self:Enable()
                            else
                                self:Disable()
                                if self.RestoreBlizzardBags then self:RestoreBlizzardBags() end
                                if self.RestoreBlizzardBagBar then self:RestoreBlizzardBagBar() end
                            end
                        end,
                    },
                    autoSellJunk = {
                        type = "toggle",
                        name = L["Auto-Sell Junk"],
                        desc = L["Automatically sell poor quality (grey) items when visiting a vendor."],
                        order = 2,
                        get = function() return self.db.autoSellJunk == true end,
                        set = function(_, val)
                            self.db.autoSellJunk = val
                        end,
                    },
                },
            },
            bagBar = {
                type = "group",
                name = L["Bag Bar"],
                order = 2,
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = L["Enable Bag Bar"],
                        order = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.enabled ~= false end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.enabled = val
                            if self.bagBarFrame then
                                self.bagBarFrame:SetShown(val)
                            end
                        end,
                    },
                    buttonSize = {
                        type = "range",
                        name = L["Button Size"],
                        order = 2,
                        min = 20,
                        max = 48,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.buttonSize or 30 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.buttonSize = val
                            self:UpdateBagBarLayout()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Button Spacing"],
                        order = 3,
                        min = 0,
                        max = 12,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.spacing or 4 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.spacing = val
                            self:UpdateBagBarLayout()
                        end,
                    },
                    point = {
                        type = "select",
                        name = L["Anchor Point"],
                        order = 4,
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOP"] = "TOP",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                            ["RIGHT"] = "RIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOM"] = "BOTTOM",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return self.db.bagBar and self.db.bagBar.point or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.point = val
                            if self.bagBarFrame then
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(val, UIParent, val, self.db.bagBar.x or -10, self.db.bagBar.y or 40)
                                self:UpdateBagBarLayout()
                            end
                        end,
                    },
                    x = {
                        type = "range",
                        name = L["X Position"],
                        order = 5,
                        min = -2500,
                        max = 2500,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.x or -10 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.x = val
                            if self.bagBarFrame then
                                local pt = self.db.bagBar.point or "BOTTOMRIGHT"
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(pt, UIParent, pt, val, self.db.bagBar.y or 40)
                                self:UpdateBagBarLayout()
                            end
                        end,
                    },
                    y = {
                        type = "range",
                        name = L["Y Position"],
                        order = 6,
                        min = -1500,
                        max = 1500,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.y or 40 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.y = val
                            if self.bagBarFrame then
                                local pt = self.db.bagBar.point or "BOTTOMRIGHT"
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(pt, UIParent, pt, self.db.bagBar.x or -10, val)
                                self:UpdateBagBarLayout()
                            end
                        end,
                    },
                },
            },
            window = {
                type = "group",
                name = L["Bag Window"],
                order = 3,
                inline = true,
                args = {
                    slotSize = {
                        type = "range",
                        name = L["Slot Size"],
                        order = 1,
                        min = 24,
                        max = 48,
                        step = 1,
                        get = function() return self.db.slotSize or 36 end,
                        set = function(_, val)
                            self.db.slotSize = val
                            self:UpdateInventory()
                        end,
                    },
                    columns = {
                        type = "range",
                        name = L["Columns"],
                        order = 2,
                        min = 6,
                        max = 18,
                        step = 1,
                        get = function() return self.db.columns or 10 end,
                        set = function(_, val)
                            self.db.columns = val
                            self:UpdateInventory()
                        end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Slot Spacing"],
                        order = 3,
                        min = 1,
                        max = 10,
                        step = 1,
                        get = function() return self.db.spacing or 4 end,
                        set = function(_, val)
                            self.db.spacing = val
                            self:UpdateInventory()
                        end,
                    },
                    qualityBorders = {
                        type = "toggle",
                        name = L["Color Borders by Quality"],
                        order = 4,
                        get = function() return self.db.qualityBorders ~= false end,
                        set = function(_, val)
                            self.db.qualityBorders = val
                            self:UpdateInventory()
                        end,
                    },
                    showEmptySlots = {
                        type = "toggle",
                        name = L["Show Empty Slots in All View"],
                        order = 5,
                        get = function() return self.db.showEmptySlots ~= false end,
                        set = function(_, val)
                            self.db.showEmptySlots = val
                            self:UpdateInventory()
                        end,
                    },
                    point = {
                        type = "select",
                        name = L["Anchor Point"],
                        order = 6,
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOP"] = "TOP",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                            ["RIGHT"] = "RIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOM"] = "BOTTOM",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                        },
                        get = function() return self.db.bagWindow and self.db.bagWindow.point or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.bagWindow = self.db.bagWindow or {}
                            self.db.bagWindow.point = val
                            if self.mainFrame then
                                self.mainFrame:ClearAllPoints()
                                self.mainFrame:SetPoint(val, UIParent, val, self.db.bagWindow.x or -10, self.db.bagWindow.y or 80)
                            end
                        end,
                    },
                    x = {
                        type = "range",
                        name = L["X Position"],
                        order = 7,
                        min = -2500,
                        max = 2500,
                        step = 1,
                        get = function() return self.db.bagWindow and self.db.bagWindow.x or -10 end,
                        set = function(_, val)
                            self.db.bagWindow = self.db.bagWindow or {}
                            self.db.bagWindow.x = val
                            if self.mainFrame then
                                local pt = self.db.bagWindow.point or "BOTTOMRIGHT"
                                self.mainFrame:ClearAllPoints()
                                self.mainFrame:SetPoint(pt, UIParent, pt, val, self.db.bagWindow.y or 80)
                            end
                        end,
                    },
                    y = {
                        type = "range",
                        name = L["Y Position"],
                        order = 8,
                        min = -1500,
                        max = 1500,
                        step = 1,
                        get = function() return self.db.bagWindow and self.db.bagWindow.y or 80 end,
                        set = function(_, val)
                            self.db.bagWindow = self.db.bagWindow or {}
                            self.db.bagWindow.y = val
                            if self.mainFrame then
                                local pt = self.db.bagWindow.point or "BOTTOMRIGHT"
                                self.mainFrame:ClearAllPoints()
                                self.mainFrame:SetPoint(pt, UIParent, pt, self.db.bagWindow.x or -10, val)
                            end
                        end,
                    },
                },
            },
            categories = {
                type = "group",
                name = L["Category Filter Buttons"],
                order = 4,
                inline = true,
                args = {},
            },
            searchHelp = {
                type = "group",
                name = L["Search Engine & Filter Sets Guide"] or "Search Engine & Filter Sets Guide",
                order = 5,
                inline = true,
                args = {
                    intro = {
                        type = "description",
                        name = "|cffffd100" .. (L["Bag Search Engine Syntax"] or "Bag Search Engine Syntax") .. ":|r\n" ..
                            (L["The search bar supports non-destructive highlighting with multi-token AND logic. Non-matching items are dimmed while matching items pop out."] or "The search bar supports non-destructive highlighting with multi-token AND logic. Non-matching items are dimmed while matching items pop out.") .. "\n\n" ..
                            "• |cffffcc00name:<text>|r or |cffffcc00<text>|r - " .. (L["Partial item name match (e.g. flask, potion, sword)"] or "Partial item name match (e.g. flask, potion, sword)") .. "\n" ..
                            "• |cffffcc00type:<val>|r - " .. (L["Item type/slot (gear, weapon, armor, consumable, reagent, trinket, etc.)"] or "Item type/slot (gear, weapon, armor, consumable, reagent, trinket, etc.)") .. "\n" ..
                            "• |cffffcc00bind:<val>|r - " .. (L["Bind status (bop, boe, bou, account/boa)"] or "Bind status (bop, boe, bou, account/boa)") .. "\n" ..
                            "• |cffffcc00reagent:<yes|no>|r - " .. (L["Matches crafting reagents (or simply 'reagents')"] or "Matches crafting reagents (or simply 'reagents')") .. "\n" ..
                            "• |cffffcc00exp:<val>|r - " .. (L["Expansion filter (tww, df, sl, bfa, classic)"] or "Expansion filter (tww, df, sl, bfa, classic)") .. "\n" ..
                            "• |cffffcc00quality:<val>|r - " .. (L["Quality name or index (epic, rare, uncommon, poor, or q:4)"] or "Quality name or index (epic, rare, uncommon, poor, or q:4)") .. "\n" ..
                            "• |cffffcc00ilvl:<expr>|r - " .. (L["Item level comparison (ilvl:>600, ilvl:<550, ilvl:600-630)"] or "Item level comparison (ilvl:>600, ilvl:<550, ilvl:600-630)") .. "\n" ..
                            "• |cffffcc00boss:<name>|r - " .. (L["Drop source boss from item tooltip (e.g. boss:ansurek)"] or "Drop source boss from item tooltip (e.g. boss:ansurek)") .. "\n" ..
                            "• |cffffcc00zone:<name>|r - " .. (L["Drop source zone from item tooltip (e.g. zone:nerub-ar)"] or "Drop source zone from item tooltip (e.g. zone:nerub-ar)") .. "\n" ..
                            "• |cffffcc00junk|r, |cffffcc00new|r, |cffffcc00fav|r - " .. (L["Shorthand flags"] or "Shorthand flags") .. "\n\n" ..
                            "|cff00ff00" .. (L["Combined Example:"] or "Combined Example:") .. "|r |cfffffffftype:gear quality:epic ilvl:>600|r\n" ..
                            "|cff00ff00" .. (L["Custom Filter Tabs:"] or "Custom Filter Tabs:") .. "|r " .. (L["Click the [+] button next to the search box to save the current query as a custom category tab. Right-click the tab to delete it."] or "Click the [+] button next to the search box to save the current query as a custom category tab. Right-click the tab to delete it."),
                        order = 1,
                        fontSize = "medium",
                    },
                },
            },
        },
    }

    local catArgs = options.args.categories.args
    local catList = self.CATEGORIES or {}
    for idx, cat in ipairs(catList) do
        local catId = cat.id
        catArgs[catId] = {
            type = "toggle",
            name = cat.name,
            order = idx,
            get = function()
                return not self.db.enabledCategories or self.db.enabledCategories[catId] ~= false
            end,
            set = function(_, val)
                self.db.enabledCategories = self.db.enabledCategories or {}
                self.db.enabledCategories[catId] = val
                if self.mainFrame then
                    -- Recreate category buttons
                    if self.catContainer then
                        self.catContainer:Hide()
                        self.catContainer = nil
                        self:CreateCategoryButtons()
                    end
                    self:UpdateInventory()
                end
            end,
        }
    end

    return options
end
