-- BountifulDelveTab
-- Adds a Bountiful Delves tab to the World Map using LibWorldMapTabs.
-- Requires: LibStub, LibWorldMapTabs-1.5
-- Compatible with: Midnight (12.0+)
--
-- Author: Sinorita@Tichondrius-US (you)
--
-- Credits:
--   LanceDH        — LibWorldMapTabs library and TextureAtlasViewer
--   Kemayo         — DelverView (confirmed delve atlas naming conventions)
--   Thunderz96     — DelveGuide (confirmed delves-bountiful/delves-regular atlas names)
--   WorldQuestTab  — QuestLog-main-background atlas and QuestLogBorderFrameTemplate usage
--

-- ============================================================
-- Constants
-- ============================================================

local ACTIVE_ATLAS    = "delves-bountiful"
local INACTIVE_ATLAS  = "delves-bountiful"
local TOOLTIP_TEXT    = "Bountiful Delves"
local ATLAS_BOUNTIFUL = "delves-bountiful"
local ATLAS_REGULAR   = "delves-regular"
local PIN_TEMPLATE    = "DelveEntrancePinTemplate"

-- ============================================================
-- Hardcoded Midnight delve list
-- areaPoiIDs confirmed in-game on patch 12.0
-- ============================================================

local MIDNIGHT_DELVES = {
    { name = "Atal'Aman",          areaPoiID = 8444 },
    { name = "Collegiate Calamity", areaPoiID = 8425 },
    { name = "Shadowguard Point",   areaPoiID = 8431 },
    { name = "Sunkiller Sanctum",   areaPoiID = 8430 },
    { name = "The Darkway",         areaPoiID = 8440 },
    { name = "The Grudge Pit",      areaPoiID = 8434 },
    { name = "The Gulf of Memory",  areaPoiID = 8435 },
    { name = "The Shadow Enclave",  areaPoiID = 8437 },
    { name = "Torment's Rise",      areaPoiID = 8445 },
    { name = "Twilight Crypts",     areaPoiID = 8441 },
}

-- ============================================================
-- Bountiful status cache
-- Keyed by areaPoiID, value = true (bountiful) / false (regular)
-- Updated whenever the world map is open and pins are visible
-- ============================================================

local bountyCache = {}  -- [areaPoiID] = true/false
local pinCache    = {}  -- [areaPoiID] = pin reference (for click-to-track)

local function ScanMapPins()
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end

    for i = 1, canvas:GetNumChildren() do
        local pin = select(i, canvas:GetChildren())
        if pin and pin.pinTemplate == PIN_TEMPLATE and pin.poiInfo then
            local id    = pin.poiInfo.areaPoiID
            local atlas = pin.poiInfo.atlasName or ""
            if id then
                bountyCache[id] = (atlas == ATLAS_BOUNTIFUL)
                pinCache[id]    = pin
            end
        end
    end
end

-- ============================================================
-- Build sorted display list from hardcoded table + cache
-- ============================================================

local function GetDelveDisplayList()
    local results = {}
    for _, delve in ipairs(MIDNIGHT_DELVES) do
        local isBountiful = bountyCache[delve.areaPoiID]  -- nil = unknown, false = regular, true = bountiful
        table.insert(results, {
            name        = delve.name,
            areaPoiID   = delve.areaPoiID,
            isBountiful = isBountiful,
            pin         = pinCache[delve.areaPoiID],
        })
    end

    -- Sort: bountiful first, then unknown, then regular — all alphabetical within group
    table.sort(results, function(a, b)
        local function sortKey(d)
            if d.isBountiful == true  then return 0 end
            if d.isBountiful == nil   then return 1 end
            return 2
        end
        local ka, kb = sortKey(a), sortKey(b)
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)

    return results
end

-- ============================================================
-- Content frame population
-- ============================================================

local rows = {}

local function PopulateDelveList(scrollChild, contentFrame)
    for _, row in ipairs(rows) do
        row:Hide()
    end

    local delves = GetDelveDisplayList()
    local ROW_HEIGHT = 32
    local yOffset = -4

    for i, delve in ipairs(delves) do
        if not rows[i] then
            local row = CreateFrame("Button", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.05)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

            row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 8, 2)
            row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -6, 2)
            row.nameLabel:SetJustifyH("LEFT")

            row.descLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.descLabel:SetPoint("LEFT", row.icon, "RIGHT", 8, -9)
            row.descLabel:SetPoint("RIGHT", row, "RIGHT", -6, -9)
            row.descLabel:SetJustifyH("LEFT")
            row.descLabel:SetTextColor(0.6, 0.6, 0.6)

            row.divider = row:CreateTexture(nil, "ARTWORK")
            row.divider:SetHeight(1)
            row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 0)
            row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
            row.divider:SetColorTexture(0.25, 0.25, 0.25, 0.8)

            rows[i] = row
        end

        local row = rows[i]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
        row:SetHeight(ROW_HEIGHT)

        -- Icon and label based on known status
        if delve.isBountiful == true then
            row.icon:SetAtlas(ATLAS_BOUNTIFUL, false)
            row.nameLabel:SetText("|cFFFFD700" .. delve.name .. "|r")
            row.descLabel:SetText("Bountiful Delve")
            row.descLabel:SetTextColor(0.2, 0.8, 0.2)
        elseif delve.isBountiful == false then
            row.icon:SetAtlas(ATLAS_REGULAR, false)
            row.nameLabel:SetText(delve.name)
            row.descLabel:SetText("Delve")
            row.descLabel:SetTextColor(0.6, 0.6, 0.6)
        else
            -- Status unknown — not yet seen on map
            row.icon:SetAtlas(ATLAS_REGULAR, false)
            row.icon:SetDesaturated(true)
            row.nameLabel:SetText("|cFF888888" .. delve.name .. "|r")
            row.descLabel:SetText("Status unknown — open map to refresh")
            row.descLabel:SetTextColor(0.5, 0.5, 0.5)
        end

        -- Reset desaturation for known entries
        if delve.isBountiful ~= nil then
            row.icon:SetDesaturated(false)
        end

        row.icon:SetSize(22, 22)

        -- Click to super-track using areaPoiID directly
        local capturedID = delve.areaPoiID
        row:SetScript("OnClick", function()
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedMapPin then
                C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, capturedID)
            end
        end)

        row:Show()
        yOffset = yOffset - ROW_HEIGHT
    end

    scrollChild:SetHeight(math.abs(yOffset) + 4)
end

-- ============================================================
-- Addon initialization
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end

    C_Timer.After(0, function()
        local ok, err = pcall(function()
            local tabLib = LibStub("LibWorldMapTabs")

            local tabData = {
                tooltipText   = TOOLTIP_TEXT,
                activeAtlas   = ACTIVE_ATLAS,
                inactiveAtlas = INACTIVE_ATLAS,
                useAtlasSize  = false,
            }

            local newTab       = tabLib:CreateTab(tabData)
            local contentFrame = tabLib:CreateContentFrameForTab(newTab)

            -- ── Background ───────────────────────────────────────
            local bg = contentFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(contentFrame)
            bg:SetAtlas("QuestLog-main-background", false)

            local borderFrame = CreateFrame("Frame", nil, contentFrame, "QuestLogBorderFrameTemplate")
            borderFrame:SetAllPoints(contentFrame)

            -- ── Header ───────────────────────────────────────────
            local header = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -10)
            header:SetText("|cFFFFD700Bountiful Delves|r")

            local subHeader = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            subHeader:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
            subHeader:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -10, -2)
            subHeader:SetJustifyH("LEFT")
            subHeader:SetWordWrap(true)
            subHeader:SetTextColor(0.6, 0.6, 0.6)
            subHeader:SetText("All Midnight delves — open map zones to refresh status.")

            local divider = contentFrame:CreateTexture(nil, "ARTWORK")
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", subHeader, "BOTTOMLEFT", 0, -4)
            divider:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, -4)
            divider:SetColorTexture(0.3, 0.3, 0.3, 0.8)

            -- ── Scroll frame ─────────────────────────────────────
            local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame)
            scrollFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)
            scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -4, 4)

            local scrollChild = CreateFrame("Frame", nil, scrollFrame)
            scrollChild:SetWidth(1)
            scrollChild:SetHeight(1)
            scrollFrame:SetScrollChild(scrollChild)

            scrollFrame:SetScript("OnSizeChanged", function(sf, w, h)
                scrollChild:SetWidth(w)
            end)

            -- ── Refresh logic ────────────────────────────────────
            local function Refresh()
                if contentFrame:IsShown() then
                    PopulateDelveList(scrollChild, contentFrame)
                end
            end

            -- Scan pins and refresh whenever the map changes
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                -- Scan multiple times to catch pins that load after the map change
                for _, delay in ipairs({0.1, 0.3, 0.6, 1.0, 2.0}) do
                    C_Timer.After(delay, function()
                        ScanMapPins()
                        Refresh()
                    end)
                end
            end)

            -- Refresh when tab becomes active
            local originalSetChecked = newTab.SetChecked
            newTab.SetChecked = function(tab, checked)
                originalSetChecked(tab, checked)
                if checked then
                    C_Timer.After(0.1, function()
                        ScanMapPins()
                        Refresh()
                    end)
                end
            end

            -- Initial populate (shows unknown status until map is browsed)
            Refresh()

        end)

        if not ok then
            print("|cFFFF4444[BountifulDelveTab]|r Failed to initialize: " .. tostring(err))
            print("Make sure LibWorldMapTabs-1.5 is installed.")
        end
    end)
end)
