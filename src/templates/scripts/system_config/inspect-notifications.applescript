-- Run with osascript while a notification is visible in the logged-in GUI session.
-- Requires Accessibility permission. This inspects the UI; it does not dismiss it.
on attribute_text(theElement, attributeName)
	tell application "System Events"
		try
			set attributeValue to value of attribute attributeName of theElement
			if attributeValue is missing value then return "<missing>"
			return attributeValue as text
		on error
			return "<unavailable>"
		end try
	end tell
end attribute_text

set reportLines to {"Notification Center accessibility inspection"}
tell application "System Events"
	tell process "NotificationCenter"
		set notificationWindows to every window
		set end of reportLines to "Windows: " & (count notificationWindows)
		repeat with windowIndex from 1 to count notificationWindows
			set notificationWindow to item windowIndex of notificationWindows
			set end of reportLines to "Window " & windowIndex & ": " & my attribute_text(notificationWindow, "AXTitle")
			set elementsToInspect to {notificationWindow} & (entire contents of notificationWindow)
			repeat with elementIndex from 1 to count elementsToInspect
				set theElement to item elementIndex of elementsToInspect
				set end of reportLines to "  Element " & elementIndex
				repeat with attributeName in {"AXRole", "AXSubrole", "AXTitle", "AXDescription", "AXValue", "AXIdentifier"}
					set end of reportLines to "    " & attributeName & ": " & my attribute_text(theElement, attributeName as text)
				end repeat
				try
					set elementActions to every action of theElement
					set end of reportLines to "    Actions: " & (count elementActions)
					repeat with elementAction in elementActions
						try
							set end of reportLines to "      " & (name of elementAction) & " — " & (description of elementAction)
						on error errorMessage number errorNumber
							set end of reportLines to "      Action read failed (" & errorNumber & "): " & errorMessage
						end try
					end repeat
				on error errorMessage number errorNumber
					set end of reportLines to "    Actions unavailable (" & errorNumber & "): " & errorMessage
				end try
			end repeat
		end repeat
	end tell
end tell

-- Return one readable report on stdout for Packer to capture.
set reportText to ""
repeat with reportLine in reportLines
	set reportText to reportText & reportLine & linefeed
end repeat
return reportText
