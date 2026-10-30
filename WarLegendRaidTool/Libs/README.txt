Libraries used by WarLegend RaidTool, one copy for the four addons (the Raid, PvP and Skyborne addons depend on this
one, which loads first). A library only one load-on-demand addon uses lives in that addon's Libs instead, so it loads
with it (LibRangeCheck-3.0: WarLegendRaidTool_PvP/Libs). Upstream code unchanged, only the line endings:

- LibStub.lua: public domain (Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke).
- CallbackHandler-1.0.lua: Ace3, BSD license (Nevcairiel and the Ace3 team).
- HereBeDragons-2.0.lua, HereBeDragons-Pins-2.0.lua: HereBeDragons 35 / Pins 17 by Hendrik "Nevcairiel" Leppkes
  (commit 90a7b2d, https://github.com/Nevcairiel/HereBeDragons ), BSD license, with the WoW: Forever client upstream.
  Guild map (GuildPositions.lua) and transports (Transports.lua).

HereBeDragons license (BSD):
Copyright (c) Hendrik Leppkes. All rights reserved.
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met: redistributions of source code must retain the above copyright notice, this list of
conditions and the following disclaimer; redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or other materials provided with the
distribution; neither the name of the developer nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DAMAGES ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE.
