-- cspell:ignore hmod winmm
-- Original reference tones; game-native alert IDs play the game's sounds on export.
local M={}
function M.alert(styles)
	local values=styles.PlayAlertSound or styles.PlayAlertSoundPositional
	if not values then return nil,"No numbered alert is configured. Custom sound files are preserved on export." end
	local id=tonumber(values[1]);if not id or id<1 or id>16 or id~=math.floor(id) then return nil,"No reference tone for this alert." end
	return id
end
function M.play(styles)
	local id,why=M.alert(styles);if not id then return false,why end
	local ffi=require("ffi");if ffi.os~="Windows" then return false,"Audio preview is available on Windows. Export retains the game's alert ID." end
	pcall(ffi.cdef,"int __stdcall PlaySoundA(const char *pszSound, void *hmod, unsigned int fdwSound);")
	local sound=ffi.load("winmm")
	local root=GetScriptPath();local filename=(root~="" and root.."/" or "").."Assets/LootFilters/alert-"..id..".wav"
	M.filename=filename;M.library=sound
	if sound.PlaySoundA(filename,nil,0x00020003)==0 then return false,"Could not play the reference tone." end
	return true,"Playing a reference tone for alert "..id..". The game's exact sound plays in game."
end
return M
