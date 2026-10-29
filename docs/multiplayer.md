# Online multiplayer (Steam) — design draft

Branch: `ten_multiplayer`. Status: **draft**. Lobbies, round flow and snake movement/trails/deaths are synced; several powers and modifiers are still local-only (see TODO).

## Goals

- Steering must feel exactly like local play, whatever the ping.
- Everyone sees the same trails, so a death is never "I didn't hit anything on my screen".
- Works through NAT with no port forwarding, friends-only or public lobbies, invites from the Steam overlay.
- The project keeps opening and running in a plain Godot 4.6 editor (no Steam). Only the online menu needs the GodotSteam build.

## Transport: GodotSteam + Steam Networking

- GodotSteam 4.17 (the `T:\GodotSteam\4.6` build) ships `SteamMultiplayerPeer`. It plugs Steam Networking Sockets into Godot's high-level multiplayer API, so plain `@rpc` functions work.
- Traffic goes over **Steam Datagram Relay (SDR)**. That's Valve's backbone, which is often a *shorter* route than the public internet, with free NAT traversal and IPs never exposed to other players.
- Steam Lobbies handle matchmaking: create (friends-only/public), browse, invite through the overlay, and "Join game" from the friends list (`join_requested`). The host creates the lobby and runs `host_with_lobby`; members run `connect_to_lobby`.
- `no_delay` and `no_nagle` are on, so packets aren't batched up.
- Topology is host plus clients. Godot relays client-to-client RPCs through the host.

## Netcode model: owner-authoritative heads + dead reckoning

The snake game is unusual: a snake's whole future is determined by its position, angle, speed and **steering input** (-1/0/+1). Trails never move once laid. The netcode exploits that:

| Thing | Authority | How it is synced |
|---|---|---|
| Own snake head (movement, gaps, powers input) | **its owner** | Simulated locally with zero input delay. State sent 30x/s, **unreliable**, channel 1 |
| Trail segments | **their owner** | Every state packet carries the most recent segments (index + position + angle). Each is resent in ~10 packets, so packet loss doesn't need retransmits and there is no head-of-line blocking. Receivers place each index once |
| Other snakes' heads | predicted locally | **Dead reckoning**: from the last state plus its steering input, the arc the snake is following is extrapolated by (time since packet + one-way latency). Errors are smoothed out, and large jumps (teleport) snap |
| Own death | **its owner** | The owner tests its head against the trails it sees (exact copies of everyone's trails, only the newest few cm may be a few ms behind), then reports to the host (reliable) |
| Round start/spawns, deaths → scores, round end, match end | **host** | Reliable RPCs. The host rolls spawn positions and broadcasts them so everyone spawns identically |
| Power use | owner | Reliable event, replayed on the remote copy of that snake |

Why not the alternatives:

- **Host-authoritative movement** (clients send input, host simulates): every client steers with a full round trip of delay. That kills a game where you thread through 1-snake-wide gaps.
- **Lockstep/rollback**: needs a deterministic simulation (fixed-point physics, deterministic Area2D overlap order). That's a big rewrite of Player.gd, and rollback would also have to re-spawn trails.
- **Owner-authoritative + dead reckoning** gives zero-latency control. Remote heads are accurate while they keep steering the same way, and they correct within one packet when the steering changes. Trails, the thing you die on, are exact.

Timing: every peer keeps a **shared network clock**, the host's clock synced NTP-style (`SteamNet.net_time()`). It takes 8 quick samples on connect, then one per second, and the lowest-round-trip sample wins. Every state packet carries the time it was sent. Receivers extrapolate by exactly `net_time() - sent_at`, which covers network, host relay and frame-polling delays without estimating any of them.

Measured on the LAN debug transport (two windows, scripted steering, snake speed 150 px/s). Error is the distance between where a remote snake is shown and where its owner has it at that moment:

| Fake latency (each way) | Median | 90th percentile | Max |
|---|---|---|---|
| 0 ms | 1.8 px | 4.6 px | 15 px |
| 100 ms | 3.4 px | 10.8 px | 22 px |
| 200 ms | 8.4 px | 16.6 px | 28 px |

Trails are exact at any latency. Only the heads are predicted. A visual-only line bridges a remote snake's newest received segment to its predicted head (hidden while the owner is in a gap), so in-flight segments don't look like holes.

Known tradeoff: head-to-head and "who crossed first" races near the front of a trail are decided on the owner's screen. That's the standard compromise for this genre.

## Code map

- `scripts/net/steam_net.gd` — autoload `SteamNet`: Steam init, lobbies, invites, the peer, and the roster (peer → name + element slot). It also has a **LAN/ENet debug mode** and a **fake latency** setting for testing the netcode with two local game windows, without two Steam accounts.
- `scenes/net/online_lobby.tscn` / `scripts/net/online_lobby.gd` — lobby screen (Multiplayer button in the main menu).
- `scripts/net/net_session.gd` — in-game sync, added to `Playground` when `Global.isMultiplayerActive`.
- `Player.gd` — `net_remote` (driven by the network, never kills itself), `input_id` (online you always steer with the Player 1 keys), `body_laid` / `power_used` signals, `create_body_at()`, `use_power()`.
- `Playground.gd` — online branches: the host drives rounds, clients follow; `roll_spawn()`, `clear_round()`, `mark_player_dead()`.

## Running / testing

- **Steam:** Steam must be running. App id **480** (Spacewar) is used until Pune has its own app id. Run the project with the GodotSteam editor `T:\GodotSteam\4.6\godotsteam.461.editor.win64.exe`. Testing a real Steam match needs two machines/accounts.
- **Local netcode test:** start two instances, then click *LAN Host* in one and *LAN Join* in the other. Set *Fake latency* to check how dead reckoning behaves at 100–200 ms.
- **Exports** must use the GodotSteam export templates (`T:\GodotSteam\4.6\godotsteam-g461-s163-gs4171-templates.tar`) and ship `steam_api64.dll`.

## TODO (not synced yet)

- Water twin head: `twin_head.gd` reads Player4 keyboard input directly. It needs the same owner/remote split as Player.
- Fireball trail destruction: each machine destroys what its own copy of the fireball hits. It should be decided by the shooter and broadcast as a list of segment indices.
- Shrooms (spawned by the host; eating confirmed by the host) and the upgrade screen (each machine controls only its own row) are disabled online for now.
- Pause doesn't pause online (the menu still opens). Host migration, reconnects and spectators are not handled.
- Lobby polish: kicking, element choice, a ready check, rematch without leaving.
