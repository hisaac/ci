-- Dismiss alerts exposed by Notification Center, not widgets or stored history.
-- The English macOS 27 UI exposes a custom action with the description "Close".
on find_close_action()
	tell application "System Events"
		if not (exists process "NotificationCenter") then return missing value
		tell process "NotificationCenter"
			set notificationWindows to every window
			repeat with notificationWindow in notificationWindows
				set notificationElements to entire contents of notificationWindow
				repeat with theElement in notificationElements
					set elementSubrole to missing value
					if exists attribute "AXSubrole" of theElement then
						set elementSubrole to value of attribute "AXSubrole" of theElement
					end if
					if elementSubrole is "AXNotificationCenterAlert" then
						repeat with elementAction in every action of theElement
							if description of elementAction is "Close" then
								return contents of elementAction
							end if
						end repeat
						error "A notification alert has no Close action; run inspect-notifications.applescript for details."
					end if
				end repeat
			end repeat
		end tell
	end tell
	return missing value
end find_close_action

set closeRequests to 0
-- Bound both Close requests and retries while windows disappear during animation.
repeat 31 times
	try
		set closeAction to my find_close_action()
		if closeAction is missing value then
			return "No visible notification alerts remain. Close actions requested: " & closeRequests
		end if
		if closeRequests is 30 then
			error "Notification alerts remain after 30 Close requests."
		end if
		tell application "System Events" to perform closeAction
		set closeRequests to closeRequests + 1
	on error errorMessage number errorNumber
		-- Invalid index / missing object: discard the stale reference and rescan.
		if errorNumber is not -1719 and errorNumber is not -1728 then
			error errorMessage number errorNumber
		end if
	end try
	-- Let the UI settle, then rescan rather than reuse stale element references.
	delay 0.2
end repeat
error "Notification Center did not settle after 31 scans."
