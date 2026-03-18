# Apps Reference

Farm Tablet ships with 10 built-in apps and supports 5 companion-mod integration apps. All apps are accessible from the sidebar.

---

## Built-in Apps

### 📊 Dashboard
**Sidebar label:** `DASH`  
**App ID:** `dashboard`

The default home screen. Gives you a full-farm overview at a glance.

| Section | What It Shows |
|---------|--------------|
| Balance card | Current farm balance (green = positive, red = overdrawn) · active loan amount |
| Finances | Income · Expenses · Net profit/loss for the current session |
| Farm | Active field count · total vehicle count |
| World | In-game day · season (if Seasons mod installed) · current time |
| Weather | Live condition label · temperature · links to Weather app for full forecast |

> **Tip:** The balance uses green/red colour coding. If the number is red, you are overdrawn.

---

### 🌤 Weather
**Sidebar label:** `WTH`  
**App ID:** `weather`

Full weather information including a multi-day forecast.

| Section | What It Shows |
|---------|--------------|
| Hero card | Condition icon (rain/storm/fog/clear) · large condition label · temperature |
| Wind | Speed (km/h) · compass direction (N/NE/E/SE/S/SW/W/NW) |
| Conditions | Temperature with feel label (Freezing / Cold / Cool / Mild / Warm / Hot) · cloud cover % · humidity (if available) · precipitation bar |
| Forecast | Up to 5 future days — condition type and max temperature per day |

**Condition colour coding:**

| Colour | Condition |
|--------|-----------|
| Blue | Rain |
| Purple | Storm |
| Grey | Fog or Overcast |
| Yellow/Gold | Sunny / Clear |

> **Note:** The forecast requires the game to have forecast data available. On some maps or early in a new save it may be absent.

---

### 🌾 Field Status
**Sidebar label:** `FLD`  
**App ID:** `field_status`

A full list of every field you own with crop and growth information.

**Summary badges** (top of screen):
- `X READY` — fields that can be harvested now
- `X GROW` — fields with active crops
- `X EMPTY` — fallow/empty fields

**Table columns:**

| Column | Meaning |
|--------|---------|
| `#` | Field ID number |
| `CROP` | Crop type name (e.g. Wheat, Canola) or "Empty" |
| `HA` | Field area in hectares |
| `STATE` | Current growth stage |

**State dot colours:**

| Colour | State |
|--------|-------|
| 🟢 Green | Ready to harvest |
| 🔵 Blue | Growing normally |
| 🟡 Yellow | Seeded / germinated / ripening |
| ⚪ Grey | Empty / fallow / withered |

> **Scrolling:** If you own more fields than fit on screen, scroll the mouse wheel over the content area to see more.

---

### 🐄 Animal Husbandry
**Sidebar label:** `ANI`  
**App ID:** `animals`

Shows every animal pen you own with care status indicators.

Each pen card shows:
- Animal type and count vs capacity (e.g. `Cows (12 / 20)`)
- **FOOD** bar — percentage of food trough filled
- **WATER** bar — percentage of water trough filled
- **STRAW / CLEAN** bar — cleanliness or straw level

**Bar colour thresholds (all three metrics):**

| Colour | Level |
|--------|-------|
| 🟢 Green | ≥ 60% |
| 🟡 Yellow | ≥ 25% |
| 🔴 Red | < 25% |

> **Productivity:** All three bars affect output. Keep everything green for maximum milk, eggs, wool, and manure.

---

### 🔧 Workshop
**Sidebar label:** `WRK`  
**App ID:** `workshop`

Nearby vehicle diagnostics. Shows any motorised vehicle within **35 metres**.

**Vehicle list** (up to 6 vehicles):
- Vehicle name and distance
- Wear % — colour coded (green ≤ 30%, yellow ≤ 65%, red > 65%)
- SELECT / DESEL button to pin a vehicle

**Diagnostics panel** (after selecting a vehicle):
- Full vehicle name
- Fuel level: `XX% (xxxL / xxxL)` with colour bar
- Wear %: `XX%` with colour bar
- Operating hours

**REPAIR button:**  
Appears when a workshop placeable is on your farm **and** the selected vehicle has more than 2% wear. Clicking it instantly restores the vehicle to new condition.

> **Multiplayer:** On a dedicated server the repair is sent as a network event. On a listen-server it is applied locally.

---

### ⛏ Digging
**Sidebar label:** `DIG`  
**App ID:** `digging`

Real-time terrain information for excavation work. Updates every **500 ms** automatically while open.

| Row | Value |
|-----|-------|
| X | Player east-west world position (metres) |
| Y | Player elevation (metres above sea level) |
| Z | Player north-south world position (metres) |
| Vehicle | Name of controlled vehicle (if in one) |
| Speed | Vehicle speed in km/h |
| Attached | Up to 2 attached implements |
| Ground Level | Terrain height at current X/Z position (metres) |
| Above Ground | Distance above or below original terrain level |

> **Below ground:** A negative "Above Ground" value means you have dug below the original terrain surface. Useful for precision excavation depth.

---

### 🪣 Bucket Tracker
**Sidebar label:** `BCK`  
**App ID:** `bucket_tracker`

Automatically tracks fill-and-dump cycles for loaders, excavators, and material handlers.

**Detected vehicle types:** wheel loader, front loader, excavator, backhoe, telehandler, skid steer, material handler — and any vehicle with a bucket/loader/grapple/fork implement attached.

**Summary cards** (top of screen):
- `LOADS` — total dump cycles this session
- `WEIGHT` — total estimated weight moved (tonnes)
- `ITEMS` — number of entries in load history

**Active vehicle panel:** shows current vehicle fill level and material as a bar.

**Load history:** the 8 most recent dumps, each showing material type and estimated weight.

**Weight estimation:** approximate kg/litre densities used:

| Material | Density |
|----------|---------|
| Dirt | 1.5 kg/L |
| Stones | 1.8 kg/L |
| Gravel | 1.7 kg/L |
| Sand | 1.6 kg/L |
| Soil | 1.4 kg/L |
| Other | 1.0 kg/L |

**RESET button:** clears all history and resets session totals to zero.

---

### 🛒 App Store
**Sidebar label:** `APPS`  
**App ID:** `app_store`

Lists every registered app grouped by category. Use the **OPEN** button on any row to jump directly to that app.

Categories: Built-in · Farming · Finance · Mod Integrations

---

### ⚙️ Settings
**Sidebar label:** `SET`  
**App ID:** `settings`

Full scrollable configuration panel. See [settings-reference.md](settings-reference.md) for the complete reference.

---

### 📋 Updates
**Sidebar label:** `UPD`  
**App ID:** `updates`

Full changelog — every released version with its list of changes, newest first.

---

## Mod Integration Apps

These apps only appear in the sidebar when their companion mod is active in the current savegame. See [mod-integrations.md](mod-integrations.md) for full details.

| App | App ID | Requires |
|-----|--------|---------|
| 💰 Income Mod | `income_mod` | FS25_IncomeMod |
| 📉 Tax Mod | `tax_mod` | FS25_TaxMod |
| 🤝 NPC Favor | `npc_favor` | FS25_NPCFavor |
| 🌱 Crop Stress | `crop_stress` | FS25_SeasonalCropStress |
| 🧪 Soil Fertilizer | `soil_fertilizer` | FS25_SoilFertilizer |

---

## The Info (i) Button

Every app has a small **i** button in the bottom-right corner of its content area. Clicking it opens a help sub-page that explains everything the app shows and all the colour/threshold meanings. Click **< BACK** to return to the app.
