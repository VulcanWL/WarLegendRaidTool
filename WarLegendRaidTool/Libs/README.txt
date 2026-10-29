Libraries used by WarLegend RaidTool, one copy for the four addons (the Raid, PvP and Skyborne addons depend on this
one, which loads first). Upstream code unchanged, only the line endings (and LibRangeCheck's two "do-not-package"
blocks, removed as its own packager does):

- LibStub.lua: public domain (Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke).
- CallbackHandler-1.0.lua: Ace3, BSD license (Nevcairiel and the Ace3 team).
- LibRangeCheck-3.0.lua: version 38 (commit 95a6313, https://github.com/WeakAuras/LibRangeCheck-3.0 ), MIT license
  (mitch0 and the WoWUIDev Community). Range of the battleground frames (PvP addon), after the game's own checks.
- HereBeDragons-2.0.lua, HereBeDragons-Pins-2.0.lua: HereBeDragons 35 / Pins 17 by Hendrik "Nevcairiel" Leppkes
  (commit 90a7b2d, https://github.com/Nevcairiel/HereBeDragons ), BSD license, with the WoW: Forever client upstream.
  Guild map (GuildPositions.lua) and transports (Transports.lua).

LibRangeCheck-3.0 license (MIT):
Copyright (c) 2023 The WoWUIDev Community
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
