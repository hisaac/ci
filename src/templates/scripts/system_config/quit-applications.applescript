-- Request a normal quit, leaving only Finder running.
-- Unsaved documents may prompt; this does not force-quit or discard changes.
tell application "System Events"
	set appNames to name of every application process whose background only is false
end tell

repeat with appName in appNames
	set targetName to appName as text
	if targetName is not "Finder" then
		try
			tell application targetName to quit
		on error errorMessage
			log ("Could not quit " & targetName & ": " & errorMessage)
		end try
	end if
end repeat
