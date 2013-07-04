
local storyboard = require "storyboard"
storyboard.isDebug = true

local dialog = require ("dialog")




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--[[
Wordpress connection

Verify the user with WordPress

--]]

local mb_api = require ("mb_api")

function dumpResult()
	print ("STATUS:")
	funx.dump(mb_api.status)
	print ("mb_api.result = ")
	funx.dump(mb_api.result)
end

function onError(event)
	print ("ERROR:")
	funx.dump(mb_api.status)
end

function onSuccess(result)
	print ("onSuccess:")
	dumpResult()
	
	local t = "status: " .. mb_api.result.status
	local o_a = display.newText( t, 20, 20, screenW, screenH, "Helvetica", 18 )

	t = "displayname: " .. mb_api.result.user.displayname
	local o_b = display.newText( t, 20, 40, screenW, screenH, "Helvetica", 18 )
	
	
end

local function verify_user(username, password)
	local url = "http://localhost/photobook/wordpress/"
	--local username = "david"
	--local password = "nookie"
	local params = {}
	local controller = "auth"
	local method = "generate_auth_cookie"
	local action = mb_api.getCurrentUserInfo
	local callback = onSuccess
	local onerror = onError

	mb_api.access(url, username, password, controller, method, params, action, callback, onerror)

end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- A function the dialog can call with the results,
-- to save them or use them.
-- The alternative is to check "storyboard.dialogResults" which is set by the dialog.
local function saveResults(results)
	--funx.dump(results)
	if (results) then
		local fn = "saved_dialog_values"
		local res = funx.saveTable(results, fn .. ".json", system.DocumentsDirectory)
		if (res) then
			funx.tellUser("Saved")
		else
			funx.tellUser("SYSTEM ERROR: Could not save the results!")
		end
	end
	
	-- Check this info against the WordPress site
	verify_user(results.username, results.password)
	
	
end



local function OpenDialogButtonRelease()
	local fields = funx.loadTable("saved_dialog_values.json", system.DocumentsDirectory)
	local params = {
		fields = fields,
		substitutions = {
			bookstore = "My Bookstore",
		},
		paramsFileName = "dialog_saved_params",
		dialogStructure = "dialog.structure.settings.json",
		saveResults = saveResults,	-- set this function or have another scene check storyboard.dialogResults
	}

	local options = {
		effect = "fade",
		time = 250,
		isModal = true,
		params = params,
	}

	storyboard.showOverlay( "dialog", options )
end



------------------------------------------------
-- MUST have another scene around if you want to call an overlay, or it crashes!
local widget = require "widget"

local scene = storyboard.newScene("main")

function scene:createScene( event )
        local group = self.view

        -----------------------------------------------------------------------------

        -- Testing open button
		local openButton = widget.newButton{
			id = "dialogopen",
			defaultFile = "_ui/button-gear-gray.png",
			overFile = "_ui/button-gear-gray-over.png",
			width = 44,
			height = 44,
			onRelease = OpenDialogButtonRelease,
		}
		group:insert(openButton)
		openButton.x = 40
		openButton.y = 40
		openButton:toFront()

        -----------------------------------------------------------------------------

end
scene:addEventListener( "createScene" )

-- the following event is dispatched once the overlay is in place
function scene:overlayBegan( event )
    --print( "Main scene says, showing overlay: " .. event.sceneName )
end
scene:addEventListener( "overlayBegan" )

-- the following event is dispatched once overlay is removed
function scene:overlayEnded( event )
    --print( "Main scene says, Overlay removed: " .. event.sceneName )
	--funx.dump(storyboard.dialogResults)
	--print( "----" )

end
scene:addEventListener( "overlayEnded" )

storyboard.gotoScene("main")
--------------------------------------------

OpenDialogButtonRelease()