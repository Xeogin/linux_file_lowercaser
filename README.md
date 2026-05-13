## WHAT IS THIS
Linux games and servers have problems with loading packed file assets (and loose files sometimes!) due to recent changes.

Relevant issue here: https://github.com/ValveSoftware/Source-1-Games/issues/6868

@rtldg tracked the problem down [here](https://github.com/ValveSoftware/source-sdk-2013/issues/865) and @shavitush made a [client-side hook](https://github.com/ValveSoftware/Source-1-Games/issues/6868#issuecomment-2707662934) to fix it (which requires `-insecure`), but servers still encounter the issue so here's a sourcemod plugin to fix it too.

Update: This now includes a global detour for FindMaterial, which attempts to fix "unintentional wallhacks" (geometry transparency) for Linux clients by forcing world textures to lowercase before they are networked.

Note: It might not work for the first map that's loaded on a server because the plugin doesn't load before map files are mounted maybe I guess idk?

## HOW ARE SERVERS BROKEN
bsps that pack models will possibly have collision problems, and world geometry may become transparent for Linux players because the engine fails to find textures with uppercase letters, breaking the Z-buffer.

an example map that's somehow broken without this plugin:
- bhop_friendsjump @ setpos `-10239.424805 8130.023438 -2911.968750 ; setang 18.701771 0.225578 0.000000`

## DOES IT SUPPORT CSS/HL2DM/DODS
Yes. While originally for CSS, the FindMaterial and OnEntityCreated hooks provide a global fix that has been verified to target HL2DM as well. Use the provided gamedata to ensure symbols match your branch.