local addonName, ns = ...
if ns.skipLoad then return end
local RoithiUI = _G.RoithiUI
local BagsMod = RoithiUI:GetModule("Bags")
local L = LibStub("AceLocale-3.0"):GetLocale("RoithiUI")

function BagsMod:GetOptions()
    local options = {
        type = "group",
        name = L["Bags"] or "Bags",
        order = 80,
        childGroups = "tab",
        args = {
            general = {
                type = "group",
                name = L["General & Automation"] or "General & Automation",
                order = 1,
                args = {
                    headerGeneral = {
                        type = "header",
                        name = L["General Settings"] or "General Settings",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable Modern Bags"] or "Enable Modern Bags",
                        order = 2,
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
                    headerAutomation = {
                        type = "header",
                        name = L["Automation & Vendors"] or "Automation & Vendors",
                        order = 10,
                    },
                    autoSellJunk = {
                        type = "toggle",
                        name = L["Auto-Sell Junk"] or "Auto-Sell Junk",
                        desc = L["Automatically sell poor quality (grey) items when visiting a vendor."] or "Automatically sell poor quality (grey) items when visiting a vendor.",
                        order = 11,
                        get = function() return self.db.autoSellJunk == true end,
                        set = function(_, val)
                            self.db.autoSellJunk = val
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    autoRepair = {
                        type = "toggle",
                        name = L["Auto-Repair Equipment"] or "Auto-Repair Equipment",
                        desc = L["Automatically repair damaged items when interacting with a repair-capable vendor."] or "Automatically repair damaged items when interacting with a repair-capable vendor.",
                        order = 12,
                        get = function() return self.db.autoRepair == true end,
                        set = function(_, val)
                            self.db.autoRepair = val
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    autoRepairSource = {
                        type = "select",
                        name = L["Repair Funding Source"] or "Repair Funding Source",
                        desc = L["Choose whether to pay repairs using your own gold or guild bank funds (falls back to personal gold if guild repair is unavailable or limit reached)."] or "Choose whether to pay repairs using your own gold or guild bank funds (falls back to personal gold if guild repair is unavailable or limit reached).",
                        order = 13,
                        values = {
                            ["PLAYER"] = L["Personal Gold (Own Money)"] or "Personal Gold (Own Money)",
                            ["GUILD"] = L["Guild Bank (Fallback to Personal)"] or "Guild Bank (Fallback to Personal)",
                        },
                        get = function() return self.db.autoRepairSource or "PLAYER" end,
                        set = function(_, val)
                            self.db.autoRepairSource = val
                        end,
                        disabled = function() return not self.db.enabled or not self.db.autoRepair end,
                    },
                    autoRepairCostThreshold = {
                        type = "range",
                        name = L["Repair Cost Warning Threshold (Gold)"] or "Repair Cost Warning Threshold (Gold)",
                        desc = L["If total repair costs exceed this amount in gold (1k to 50k), auto-repair is skipped and a warning is printed to chat showing the exact cost so you can review and repair manually. Click the number box to type custom values (e.g. 1800, 2400)."] or "If total repair costs exceed this amount in gold (1k to 50k), auto-repair is skipped and a warning is printed to chat showing the exact cost so you can review and repair manually. Click the number box to type custom values (e.g. 1800, 2400).",
                        order = 14,
                        min = 1000,
                        max = 50000,
                        step = 1,
                        bigStep = 500,
                        get = function() return self.db.autoRepairCostThreshold or 2000 end,
                        set = function(_, val)
                            self.db.autoRepairCostThreshold = val
                        end,
                        disabled = function() return not self.db.enabled or not self.db.autoRepair end,
                    },
                    headerTracking = {
                        type = "header",
                        name = L["New Item Tracking"] or "New Item Tracking",
                        order = 20,
                    },
                    newItemRetentionTimer = {
                        type = "range",
                        name = L["New Item Retention (Minutes)"] or "New Item Retention (Minutes)",
                        desc = L["How long items remain flagged as new after hovering over them (1 minute to 240 minutes / 4 hours)."] or "How long items remain flagged as new after hovering over them (1 minute to 240 minutes / 4 hours).",
                        order = 21,
                        min = 1,
                        max = 240,
                        step = 1,
                        get = function() return self.db.newItemRetentionTimer or 20 end,
                        set = function(_, val)
                            self.db.newItemRetentionTimer = val
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                },
            },
            window = {
                type = "group",
                name = L["Bag Window"] or "Bag Window",
                order = 2,
                args = {
                    headerGrid = {
                        type = "header",
                        name = L["Grid & Slot Layout"] or "Grid & Slot Layout",
                        order = 1,
                    },
                    slotSize = {
                        type = "range",
                        name = L["Slot Size"] or "Slot Size",
                        order = 2,
                        min = 24,
                        max = 48,
                        step = 1,
                        get = function() return self.db.slotSize or 36 end,
                        set = function(_, val)
                            self.db.slotSize = val
                            self:UpdateInventory()
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    columns = {
                        type = "range",
                        name = L["Columns"] or "Columns",
                        order = 3,
                        min = 6,
                        max = 18,
                        step = 1,
                        get = function() return self.db.columns or 10 end,
                        set = function(_, val)
                            self.db.columns = val
                            self:UpdateInventory()
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Slot Spacing"] or "Slot Spacing",
                        order = 4,
                        min = 1,
                        max = 10,
                        step = 1,
                        get = function() return self.db.spacing or 4 end,
                        set = function(_, val)
                            self.db.spacing = val
                            self:UpdateInventory()
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    qualityBorders = {
                        type = "toggle",
                        name = L["Color Borders by Quality"] or "Color Borders by Quality",
                        order = 5,
                        get = function() return self.db.qualityBorders ~= false end,
                        set = function(_, val)
                            self.db.qualityBorders = val
                            self:UpdateInventory()
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    headerPosition = {
                        type = "header",
                        name = L["Window Positioning"] or "Window Positioning",
                        order = 10,
                    },
                    point = {
                        type = "select",
                        name = L["Anchor Point"] or "Anchor Point",
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
                        get = function() return self.db.bagWindow and self.db.bagWindow.point or "BOTTOMRIGHT" end,
                        set = function(_, val)
                            self.db.bagWindow = self.db.bagWindow or {}
                            self.db.bagWindow.point = val
                            if self.mainFrame then
                                self.mainFrame:ClearAllPoints()
                                self.mainFrame:SetPoint(val, UIParent, val, self.db.bagWindow.x or -10, self.db.bagWindow.y or 10)
                            end
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    x = {
                        type = "range",
                        name = L["X Position"] or "X Position",
                        order = 12,
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
                                self.mainFrame:SetPoint(pt, UIParent, pt, val, self.db.bagWindow.y or 10)
                            end
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                    y = {
                        type = "range",
                        name = L["Y Position"] or "Y Position",
                        order = 13,
                        min = -1500,
                        max = 1500,
                        step = 1,
                        get = function() return self.db.bagWindow and self.db.bagWindow.y or 10 end,
                        set = function(_, val)
                            self.db.bagWindow = self.db.bagWindow or {}
                            self.db.bagWindow.y = val
                            if self.mainFrame then
                                local pt = self.db.bagWindow.point or "BOTTOMRIGHT"
                                self.mainFrame:ClearAllPoints()
                                self.mainFrame:SetPoint(pt, UIParent, pt, self.db.bagWindow.x or -10, val)
                            end
                        end,
                        disabled = function() return not self.db.enabled end,
                    },
                },
            },
            bagBar = {
                type = "group",
                name = L["Bag Bar"] or "Bag Bar",
                order = 3,
                args = {
                    headerBagBar = {
                        type = "header",
                        name = L["Bag Bar Display"] or "Bag Bar Display",
                        order = 1,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable Bag Bar"] or "Enable Bag Bar",
                        order = 2,
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
                        name = L["Button Size"] or "Button Size",
                        order = 3,
                        min = 20,
                        max = 48,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.buttonSize or 30 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.buttonSize = val
                            self:UpdateBagBarLayout()
                        end,
                        disabled = function() return not self.db.bagBar or self.db.bagBar.enabled == false end,
                    },
                    spacing = {
                        type = "range",
                        name = L["Button Spacing"] or "Button Spacing",
                        order = 4,
                        min = 0,
                        max = 12,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.spacing or 4 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.spacing = val
                            self:UpdateBagBarLayout()
                        end,
                        disabled = function() return not self.db.bagBar or self.db.bagBar.enabled == false end,
                    },
                    headerPosition = {
                        type = "header",
                        name = L["Positioning"] or "Positioning",
                        order = 10,
                    },
                    point = {
                        type = "select",
                        name = L["Anchor Point"] or "Anchor Point",
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
                        get = function() return self.db.bagBar and self.db.bagBar.point or "BOTTOMLEFT" end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.point = val
                            if self.bagBarFrame then
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(val, UIParent, val, self.db.bagBar.x or 286, self.db.bagBar.y or 285)
                                self:UpdateBagBarLayout()
                            end
                        end,
                        disabled = function() return not self.db.bagBar or self.db.bagBar.enabled == false end,
                    },
                    x = {
                        type = "range",
                        name = L["X Position"] or "X Position",
                        order = 12,
                        min = -2500,
                        max = 2500,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.x or 286 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.x = val
                            if self.bagBarFrame then
                                local pt = self.db.bagBar.point or "BOTTOMLEFT"
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(pt, UIParent, pt, val, self.db.bagBar.y or 285)
                                self:UpdateBagBarLayout()
                            end
                        end,
                        disabled = function() return not self.db.bagBar or self.db.bagBar.enabled == false end,
                    },
                    y = {
                        type = "range",
                        name = L["Y Position"] or "Y Position",
                        order = 13,
                        min = -1500,
                        max = 1500,
                        step = 1,
                        get = function() return self.db.bagBar and self.db.bagBar.y or 285 end,
                        set = function(_, val)
                            self.db.bagBar = self.db.bagBar or {}
                            self.db.bagBar.y = val
                            if self.bagBarFrame then
                                local pt = self.db.bagBar.point or "BOTTOMLEFT"
                                self.bagBarFrame:ClearAllPoints()
                                self.bagBarFrame:SetPoint(pt, UIParent, pt, self.db.bagBar.x or 286, val)
                                self:UpdateBagBarLayout()
                            end
                        end,
                        disabled = function() return not self.db.bagBar or self.db.bagBar.enabled == false end,
                    },
                },
            },
            categories = {
                type = "group",
                name = L["Category Filters"] or "Category Filters",
                order = 4,
                args = {
                    headerCategories = {
                        type = "header",
                        name = L["Category Filter Buttons"] or "Category Filter Buttons",
                        order = 1,
                    },
                    descCategories = {
                        type = "description",
                        name = L["Toggle which category tabs appear along the top edge of your bag window."] or "Toggle which category tabs appear along the top edge of your bag window.",
                        order = 2,
                    },
                },
            },
            typography = {
                type = "group",
                name = L["Typography & Badges"] or "Typography & Badges",
                order = 5,
                args = {
                    headerGeneralFont = {
                        type = "header",
                        name = L["General Typography"] or "General Typography",
                        order = 1,
                    },
                    font = {
                        type = "select",
                        name = L["Font Face"] or "Font Face",
                        order = 2,
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
                        order = 3,
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
                    showFontShadow = {
                        type = "toggle",
                        name = L["Enable Text Shadow"] or "Enable Text Shadow",
                        desc = L["Enables Blizzard's default offset text shadow. Keep disabled when Outline is active for crisp typography."] or "Enables Blizzard's default offset text shadow. Keep disabled when Outline is active for crisp typography.",
                        order = 4,
                        get = function() return self.db.showFontShadow == true end,
                        set = function(_, val)
                            self.db.showFontShadow = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    headerInterfaceText = {
                        type = "header",
                        name = L["Interface Text"] or "Interface Text",
                        order = 10,
                    },
                    categoryFontSize = {
                        type = "range",
                        name = L["Category Button Font Size"] or "Category Button Font Size",
                        order = 11,
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
                        order = 12,
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
                        order = 13,
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
                        order = 14,
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
                        order = 15,
                        min = 8,
                        max = 18,
                        step = 1,
                        get = function() return self.db.searchFontSize or 12 end,
                        set = function(_, val)
                            self.db.searchFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                        end,
                    },
                    headerItemCount = {
                        type = "header",
                        name = L["Item Stack Count"] or "Item Stack Count",
                        order = 20,
                    },
                    itemCountFont = {
                        type = "select",
                        name = L["Item Count Font Face"] or "Item Count Font Face",
                        order = 21,
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
                        order = 22,
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
                        order = 23,
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
                        order = 24,
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
                        order = 25,
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
                        order = 26,
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
                    headerItemLevel = {
                        type = "header",
                        name = L["Item Level Display"] or "Item Level Display",
                        order = 30,
                    },
                    showItemLevel = {
                        type = "toggle",
                        name = L["Show Item Level"] or "Show Item Level",
                        desc = L["Displays item levels directly on equippable gear icons."] or "Displays item levels directly on equippable gear icons.",
                        order = 31,
                        get = function() return self.db.showItemLevel ~= false end,
                        set = function(_, val)
                            self.db.showItemLevel = val
                            self:UpdateInventory()
                        end,
                    },
                    itemLevelFont = {
                        type = "select",
                        name = L["Item Level Font Face"] or "Item Level Font Face",
                        order = 32,
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
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    itemLevelFontOutline = {
                        type = "select",
                        name = L["Item Level Font Outline"] or "Item Level Font Outline",
                        order = 33,
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
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    itemLevelFontSize = {
                        type = "range",
                        name = L["Item Level Font Size"] or "Item Level Font Size",
                        order = 34,
                        min = 7,
                        max = 18,
                        step = 1,
                        get = function() return self.db.itemLevelFontSize or 12 end,
                        set = function(_, val)
                            self.db.itemLevelFontSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    itemLevelAnchor = {
                        type = "select",
                        name = L["Item Level Anchor"] or "Item Level Anchor",
                        order = 35,
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
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    itemLevelX = {
                        type = "range",
                        name = L["Item Level X Offset"] or "Item Level X Offset",
                        order = 36,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemLevelX or 2 end,
                        set = function(_, val)
                            self.db.itemLevelX = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    itemLevelY = {
                        type = "range",
                        name = L["Item Level Y Offset"] or "Item Level Y Offset",
                        order = 37,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.itemLevelY or -2 end,
                        set = function(_, val)
                            self.db.itemLevelY = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    colorItemLevelByQuality = {
                        type = "toggle",
                        name = L["Color Item Level by Quality"] or "Color Item Level by Quality",
                        desc = L["Color item level text according to the item's quality color instead of fixed gold."] or "Color item level text according to the item's quality color instead of fixed gold.",
                        order = 38,
                        get = function() return self.db.colorItemLevelByQuality ~= false end,
                        set = function(_, val)
                            self.db.colorItemLevelByQuality = val
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showItemLevel == false end,
                    },
                    questIndicatorHeader = {
                        type = "header",
                        name = L["Quest Indicator"] or "Quest Indicator",
                        order = 40,
                    },
                    questIndicatorSize = {
                        type = "range",
                        name = L["Quest Indicator Size"] or "Quest Indicator Size",
                        order = 41,
                        min = 10,
                        max = 32,
                        step = 1,
                        get = function() return self.db.questIndicatorSize or 16 end,
                        set = function(_, val)
                            self.db.questIndicatorSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    questIndicatorAnchor = {
                        type = "select",
                        name = L["Quest Indicator Anchor"] or "Quest Indicator Anchor",
                        order = 42,
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
                        get = function() return self.db.questIndicatorAnchor or "BOTTOMLEFT" end,
                        set = function(_, val)
                            self.db.questIndicatorAnchor = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    questIndicatorX = {
                        type = "range",
                        name = L["Quest Indicator X Offset"] or "Quest Indicator X Offset",
                        order = 43,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.questIndicatorX or 1 end,
                        set = function(_, val)
                            self.db.questIndicatorX = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    questIndicatorY = {
                        type = "range",
                        name = L["Quest Indicator Y Offset"] or "Quest Indicator Y Offset",
                        order = 44,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.questIndicatorY or 1 end,
                        set = function(_, val)
                            self.db.questIndicatorY = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                    },
                    junkIndicatorHeader = {
                        type = "header",
                        name = L["Junk Indicator"] or "Junk Indicator",
                        order = 50,
                    },
                    showJunkIndicator = {
                        type = "toggle",
                        name = L["Show Junk Indicator"] or "Show Junk Indicator",
                        desc = L["Display a gold coin icon on junk items in the bag."] or "Display a gold coin icon on junk items in the bag.",
                        order = 51,
                        get = function() return self.db.showJunkIndicator ~= false end,
                        set = function(_, val)
                            self.db.showJunkIndicator = val
                            self:UpdateInventory()
                        end,
                    },
                    junkIndicatorSize = {
                        type = "range",
                        name = L["Junk Indicator Size"] or "Junk Indicator Size",
                        order = 52,
                        min = 10,
                        max = 32,
                        step = 1,
                        get = function() return self.db.junkIndicatorSize or 14 end,
                        set = function(_, val)
                            self.db.junkIndicatorSize = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showJunkIndicator == false end,
                    },
                    junkIndicatorAnchor = {
                        type = "select",
                        name = L["Junk Indicator Anchor"] or "Junk Indicator Anchor",
                        order = 53,
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
                        get = function() return self.db.junkIndicatorAnchor or "BOTTOMLEFT" end,
                        set = function(_, val)
                            self.db.junkIndicatorAnchor = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showJunkIndicator == false end,
                    },
                    junkIndicatorX = {
                        type = "range",
                        name = L["Junk Indicator X Offset"] or "Junk Indicator X Offset",
                        order = 54,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.junkIndicatorX or 1 end,
                        set = function(_, val)
                            self.db.junkIndicatorX = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showJunkIndicator == false end,
                    },
                    junkIndicatorY = {
                        type = "range",
                        name = L["Junk Indicator Y Offset"] or "Junk Indicator Y Offset",
                        order = 55,
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return self.db.junkIndicatorY or 1 end,
                        set = function(_, val)
                            self.db.junkIndicatorY = val
                            if self.UpdateTypography then self:UpdateTypography() end
                            self:UpdateInventory()
                        end,
                        disabled = function() return self.db.showJunkIndicator == false end,
                    },
                },
            },
            searchHelp = {
                type = "group",
                name = L["Search Syntax"] or "Search Syntax",
                order = 6,
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
            order = 10 + idx,
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
            disabled = function() return not self.db.enabled end,
        }
    end

    return options
end
