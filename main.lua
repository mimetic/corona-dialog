
local storyboard = require "storyboard"
storyboard.isDebug = true

-- This creates a dialog generator function
local dialog = require ("dialog")
local settings_gui = require("settings_gui")

-- Local settings for an app, e.g. current user, etc.
local system_settings = {
	user = {
		authorized = true,
		username = "iggie",
		password = "nookie",
		displayname = "David Gross",
		bookstore = "My Bookstore",
		adultpassword = "abc",
	},
}

system_settings = {
	user = {
		authorized = false,
		username = "iggie",
		password = "nookie",
		displayname = "David Gross",
		bookstore = "My Bookstore",
		adultpassword = "abc",
	},
}


local function onUpdateSettings(values)
	print ("Main: onUpdateSettings(values)")
	funx.dump (values)

	-- Things to do:


	-- We can check for the status, or not. 
	-- If we want 'cancel' to be a 'close', which is how iOS seems to do things,
	-- we don't care what the status is. We assume, in iOS fashion, that all
	-- changes are good changes. If you don't believe me, try the iOS System Settings
	-- and see!
	
	-- To check status:
	--[[
	if (values.status == "ok") then
		-- Save new settings to disk
	else
		-- do nothing, changes were cancelled or error happened
	end
	--]]
end



settings_gui.init(system_settings, onUpdateSettings)
--settings_gui.showSettingsDialog()

settings_gui.showDialog("signinDialog")
