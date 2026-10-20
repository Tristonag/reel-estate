# Reel Estate

A Roblox game where you fish mystery crates out of the sea and build your own island from what you catch.

<!-- TODO: record a 20-second clip (cast, reel, crate reveal, placing an item on your island), turn it into a GIF, save it as docs/demo.gif, and this line shows it -->
![Gameplay](docs/demo.gif)

**Play it:** <!-- TODO: open this link in a private window and check the game page loads --> https://www.roblox.com/games/126846978606995

## What it is

You cast from your plot, hook floating containers (crates, barrels, bottles, chests, relics) and reel them in. Each one opens into an item with a rarity, and sometimes a Shiny, Golden or Rainbow variant. You either sell items for Shells or place them on your island, where they earn Shells over time, even while you're offline. Shells buy better rods (longer casts, more luck), bait and bigger islands, from a raft all the way up to a legendary atoll. Finishing sets in the Collection Book gives you permanent luck, rebirthing trades your progress for permanent bonuses, and every so often a shipwreck surfaces for the whole server.

## My role

I designed the game and directed the build: the core loop, the economy and its numbers, the island progression, monetization and the UI flow. Claude (an AI assistant) wrote much of the Luau inside Roblox Studio from my direction, and I tested, tuned and fixed everything until it played the way I wanted.

<!-- TODO: add one bug you hit and how it got fixed, in 2 or 3 sentences -->

## How it works

- **The server decides everything that matters.** The client only asks. `FishingService` decides whether a cast hooked something and what it was; `LootService` rolls the loot server-side so odds can't be tampered with; every remote is validated on the server.
- **Rate limiting.** `RateLimit` puts a per-player cooldown on remotes to stop spam and exploit floods.
- **Saving with session locking.** `DataService` loads, caches and saves player data. Each save records which server owns it, so a player hopping servers quickly can't load stale data and duplicate items.
- **Safe purchases.** `MonetizationService` records every developer-product receipt in the player's save and only reports a purchase as granted once that save succeeds, so a purchase is never granted twice or lost.
- **One config file.** `Config` holds every tunable number (rarities, drop weights, rods, islands, prices), so balancing never touches game logic.
- **Odds disclosure.** `OddsService` shows each player their exact odds for paid random items and hides them in regions where the law requires it.
- **Startup order.** `Server/Main` starts each service in a fixed order, with listeners before `DataService`, so no "player loaded" event is missed.

## Project layout

```text
src/
  server/            ServerScriptService.Server
    Main.server.luau   starts every service
    Services/          one module per system (Data, Fishing, Loot, Island, Shop, Idle, ...)
  shared/            ReplicatedStorage.Shared
    Config.luau        all balance numbers and items
    ...                formatting, grid and visual helpers
  client/            StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau   starts the client controllers
    ...                fishing, HUD, placement, shop and store UI
default.project.json  maps src/ back into the game (Rojo)
```

Models, the map and UI assets live in the Roblox place, not in this repo.

## Tools

Roblox Studio, Luau, Rojo-style project layout, Claude via the Roblox Studio MCP.
