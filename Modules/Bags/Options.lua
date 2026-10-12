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
                    newItemRetentionTimer = {
                        type = "range",
                        name = L["New Item Retention (Minutes)"],
                        desc = L["How long items remain flagged as new after hovering over them (1 minute to 240 minutes / 4 hours)."],
                        order = 3,
                        min = 1,
                        max = 240,
                        step = 1,
                        get = function() return self.db.newItemRetentionTimer or 20 end,
                        set = function(_, val)
                            self.db.newItemRetentionTimer = val
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
                    point = {
                        type = "select",
                        name = L["Anchor Point"],
                        order = 5,
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
                        order = 6,
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
                        order = 7,
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
            typography = {
                type = "group",
                name = L["Typography & Text Sizing"] or "Typography & Text Sizing",
                order = 3.5,
                inline = true,
                args = {
                    font = {
                        type = "select",
                        name = L["Font Face"] or "Font Face",
                        order = 1,
                        dialogControl = "LSM30_Font",
                        values = function()
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            return LSM and LSM:HashTable("font") or { ["Friz Quadrata TT"] = "Friz Quadrata TT" }
                        end,
                        get = function() return self.db.font or "Friz Quadrata TT" end,
                        set = function(_, val)
                            self.db.font = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    fontOutline = {
                        type = "select",
                        name = L["Font Outline"] or "Font Outline",
                        order = 2,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.fontOutline = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    categoryFontSize = {
                        type = "range",
                        name = L["Category Button Font Size"] or "Category Button Font Size",
                        order = 3,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.categoryFontSize or 12 end,
                        set = function(_, val)
                            self.db.categoryFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    freeSlotsFontSize = {
                        type = "range",
                        name = L["Free Slots Font Size"] or "Free Slots Font Size",
                        order = 4,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.freeSlotsFontSize or 12 end,
                        set = function(_, val)
                            self.db.freeSlotsFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                        end,
                    },
                    freeSlotsAnchor = {
                        type = "select",
                        name = L["Free Slots Anchor"] or "Free Slots Anchor",
                        order = 5,
                        values = {
                            ["RIGHT"] = L["Right"] or "Right",
                            ["CENTER"] = L["Center"] or "Center",
                            ["LEFT"] = L["Left"] or "Left",
                        },
                        get = function() return self.db.freeSlotsAnchor or "RIGHT" end,
                        set = function(_, val)
                            self.db.freeSlotsAnchor = val
                            if self.UpdateTypography then self:UpdateTypography() end
                        end,
                    },
                    goldFontSize = {
                        type = "range",
                        name = L["Gold / Currency Font Size"] or "Gold / Currency Font Size",
                        order = 6,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.goldFontSize or 12 end,
                        set = function(_, val)
                            self.db.goldFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                        end,
                    },
                    searchFontSize = {
                        type = "range",
                        name = L["Search Bar Font Size"] or "Search Bar Font Size",
                        order = 7,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.searchFontSize or 12 end,
                        set = function(_, val)
                            self.db.searchFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                        end,
                    },
                    itemCountFont = {
                        type = "select",
                        name = L["Item Count Font Face"] or "Item Count Font Face",
                        order = 8,
                        dialogControl = "LSM30_Font",
                        values = function()
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            return LSM and LSM:HashTable("font") or { ["Roithi Thick"] = "Roithi Thick", ["Friz Quadrata TT"] = "Friz Quadrata TT" }
                        end,
                        get = function() return self.db.itemCountFont or self.db.font or "Roithi Thick" end,
                        set = function(_, val)
                            self.db.itemCountFont = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemCountFontOutline = {
                        type = "select",
                        name = L["Item Count Font Outline"] or "Item Count Font Outline",
                        order = 9,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.itemCountFontOutline or self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.itemCountFontOutline = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemCountFontSize = {
                        type = "range",
                        name = L["Item Count Font Size"] or "Item Count Font Size",
                        order = 10,
                        min = 8,
                        max = 20,
                        step = 1,
                        get = function() return self.db.itemCountFontSize or 12 end,
                        set = function(_, val)
                            self.db.itemCountFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemCountAnchor = {
                        type = "select",
                        name = L["Item Count Anchor"] or "Item Count Anchor",
                        order = 11,
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
                        get = function() return self.db.itemCountAnchor or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.itemCountAnchor = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemCountX = {
                        type = "range",
                        name = L["Item Count X Offset"] or "Item Count X Offset",
                        order = 12,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemCountX or -2 end,
                        set = function(_, val)
                            self.db.itemCountX = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemCountY = {
                        type = "range",
                        name = L["Item Count Y Offset"] or "Item Count Y Offset",
                        order = 13,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemCountY or 2 end,
                        set = function(_, val)
                            self.db.itemCountY = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelFont = {
                        type = "select",
                        name = L["Item Level Font Face"] or "Item Level Font Face",
                        order = 14,
                        dialogControl = "LSM30_Font",
                        values = function()
                            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                            return LSM and LSM:HashTable("font") or { ["Roithi Thick"] = "Roithi Thick", ["Friz Quadrata TT"] = "Friz Quadrata TT" }
                        end,
                        get = function() return self.db.itemLevelFont or self.db.font or "Roithi Thick" end,
                        set = function(_, val)
                            self.db.itemLevelFont = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelFontOutline = {
                        type = "select",
                        name = L["Item Level Font Outline"] or "Item Level Font Outline",
                        order = 15,
                        values = {
                            ["NONE"] = L["None"] or "None",
                            ["OUTLINE"] = L["Outline"] or "Outline",
                            ["THICKOUTLINE"] = L["Thick Outline"] or "Thick Outline",
                        },
                        get = function() return self.db.itemLevelFontOutline or self.db.fontOutline or "OUTLINE" end,
                        set = function(_, val)
                            self.db.itemLevelFontOutline = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelFontSize = {
                        type = "range",
                        name = L["Item Level Font Size"] or "Item Level Font Size",
                        order = 16,
                        min = 7,
                        max = 18,
                        step = 1,
                        get = function() return self.db.itemLevelFontSize or 12 end,
                        set = function(_, val)
                            self.db.itemLevelFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelAnchor = {
                        type = "select",
                        name = L["Item Level Anchor"] or "Item Level Anchor",
                        order = 17,
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
                        get = function() return self.db.itemLevelAnchor or "TOPLEFT" end,
                        set = function(_, val)
                            self.db.itemLevelAnchor = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelX = {
                        type = "range",
                        name = L["Item Level X Offset"] or "Item Level X Offset",
                        order = 18,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemLevelX or 2 end,
                        set = function(_, val)
                            self.db.itemLevelX = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelY = {
                        type = "range",
                        name = L["Item Level Y Offset"] or "Item Level Y Offset",
                        order = 19,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemLevelY or -2 end,
                        set = function(_, val)
                            self.db.itemLevelY = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    colorItemLevelByQuality = {
                        type = "toggle",
                        name = L["Color Item Level by Quality"] or "Color Item Level by Quality",
                        desc = L["Color item level text according to the item's quality color instead of fixed gold."],
                        order = 20,
                        get = function() return self.db.colorItemLevelByQuality ~= false end,
                        set = function(_, val)
                            self.db.colorItemLevelByQuality = val
                            self:UpdateInventory()
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
                            "• |cffffcc00slot:<name|num>|r or |cffffcc00s:<name|num>|r - " .. (L["Equipment slot by name or slot ID (e.g. slot:head, slot:1, s:ring, s:13)"] or "Equipment slot by name or slot ID (e.g. slot:head, slot:1, s:ring, s:13)") .. "\n" ..
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
