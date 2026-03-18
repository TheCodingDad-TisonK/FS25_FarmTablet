# Mod Integrations

Farm Tablet integrates with five companion mods from the TisonK mod suite. Integration apps appear in the sidebar **automatically** when the companion mod is loaded — no configuration or setup required.

---

## How Detection Works

When a savegame finishes loading, `AppRegistry:autoDetect()` checks for each companion mod by looking for its global manager object. If found, the app is registered. If not found, the app is not added to the sidebar (no "mod not installed" placeholder).

If you add a companion mod mid-session, restart the game to trigger detection.

---

## 💰 Income Mod

**App ID:** `income_mod`  
**Requires:** [FS25_IncomeMod](https://github.com/TheCodingDad-TisonK/FS25_IncomeMod)  
**Detection:** `g_currentMission.incomeManager`

**What it shows:**
- Current enabled/disabled status
- Payment mode (Hourly / Daily / Weekly)
- Payment amount per cycle

**Actions:**
- **ENABLE** button — turns the mod on
- **DISABLE** button — turns the mod off

Both buttons take effect immediately and save the setting.

---

## 📉 Tax Mod

**App ID:** `tax_mod`  
**Requires:** [FS25_TaxMod](https://github.com/TheCodingDad-TisonK/FS25_TaxMod)  
**Detection:** `g_currentMission.taxManager`

**What it shows:**
- Current enabled/disabled status
- Tax rate tier (Low / Medium / High)
- Return percentage (how much tax is refunded as a rebate)
- Total taxes paid this session

**Actions:**
- **ENABLE** / **DISABLE** buttons

---

## 🤝 NPC Favor

**App ID:** `npc_favor`  
**Requires:** [FS25_NPCFavor](https://github.com/TheCodingDad-TisonK/FS25_NPCFavor)  
**Detection:** `g_NPCSystem` or `g_currentMission.npcFavorSystem`

**What it shows:**

*Town Reputation section:*
- Reputation score (0–100) with label: Respected ≥ 70 · Neutral ≥ 40 · Poor < 40
- Colour-coded reputation bar

*Favors section:*
- Number of active favors
- Total completed favors
- Total money earned from favors

*Active Favors (up to 3):*
- NPC name and task description
- Completion % and hours remaining

*Relationships section:*
- All active NPCs sorted by relationship score (highest first)
- Per-NPC score, status label (Friend / Neutral / Cold), and bar
- NPC role shown in brackets (e.g. `[Agronomist]`)

---

## 🌱 Seasonal Crop Stress

**App ID:** `crop_stress`  
**Requires:** [FS25_SeasonalCropStress](https://github.com/TheCodingDad-TisonK/FS25_SeasonalCropStress)  
**Detection:** `g_cropStressManager` (via `getfenv(0)`)

**What it shows:**

*Status banner:*
- Active / Disabled status
- Difficulty setting

*Field list:*
- Field ID with crop type in brackets
- Soil moisture % and colour-coded bar
- Drought stress indicator — if stress > 5%, shows `!XX%` in red

**Bar colour thresholds:**

| Colour | Moisture Level |
|--------|---------------|
| 🟢 Green | ≥ 40% |
| 🟡 Yellow | ≥ 25% |
| 🔴 Red | < 25% |

> **Tip:** Fields with a red `!XX%` stress indicator need immediate irrigation to prevent yield loss.

---

## 🧪 Soil Fertilizer

**App ID:** `soil_fertilizer`  
**Requires:** [FS25_SoilFertilizer](https://github.com/TheCodingDad-TisonK/FS25_SoilFertilizer)  
**Detection:** `g_SoilFertilityManager`, `g_soilFertilizerManager`, or `g_currentMission.soilFertilityManager`

**What it shows:**

*Status banner:*
- Active / Disabled status
- PF DLC indicator (if Precision Farming DLC is active)

*Field list:*
- Each owned field with crop name
- `[FERT!]` warning flag if the field needs fertilizing
- SELECT / DESEL button to pin a field for detailed view

*Soil detail panel (selected field):*
- Nitrogen — value and status (Good / Fair / Poor)
- Phosphorus — value and status
- Potassium — value and status
- pH — value with colour (green if 6.0–7.5, yellow outside range)
- Organic matter %
- Last crop type
- Days since last harvest
- "Needs Fertilizer" flag

**Nutrient colour coding:**

| Colour | Status |
|--------|--------|
| 🟢 Green | Good |
| 🟡 Yellow | Fair |
| 🔴 Red | Poor |

> **pH note:** Optimal range is 6.0–7.5. Outside this range, nutrient uptake is reduced even if absolute nutrient levels look fine.

---

## Troubleshooting Integration Apps

**An app isn't appearing in the sidebar**

1. Confirm the companion mod is enabled in the mod manager for this savegame
2. Reload the savegame (the tablet checks for mods when the mission finishes loading)
3. Check `log.txt` with debug mode on — detection failures are logged at `[FarmTablet System]`

**The app says "mod not installed" even though the mod is loaded**

This shouldn't happen in v2 (companion apps are only registered after confirming the manager exists). If you see this, enable debug mode and check the log — the detection global name may have changed in a newer version of the companion mod.

**Integration buttons (Enable/Disable) don't seem to work**

The tablet writes directly to the companion mod's settings object. If the mod has its own validation or save system, changes may not persist until the companion mod saves. Check the companion mod's documentation.
