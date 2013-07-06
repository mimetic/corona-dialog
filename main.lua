
local storyboard = require "storyboard"
storyboard.isDebug = true

-- This creates a new dialog
local dialog = require ("dialog")




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--[[
Wordpress connection

Verify the user with WordPress

--]]

local mb_api = require ("mb_api")


--------------------------------------------
screenW, screenH = display.contentWidth, display.contentHeight
viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
midscreenX = screenW*(0.5)
midscreenY = screenH*(0.5)
	
-- testing output:
local outA = display.newText( "Output", 100, 20, screenW, screenH, "Helvetica", 18 )
local outB = display.newText( "Output", 100, 40, screenW, screenH, "Helvetica", 18 )


local function verify_user(results)

		function onError(result)
			print ("ERROR:")
			funx.dump(result)
		end

		function onSuccess(result)
			print ("onSuccess:")
			funx.dump(result)
	
			local t = "status: " .. mb_api.result.status
			outA.text = t

			t = "displayname: " .. mb_api.result.user.displayname
			outB.text = t
		end

	--------------------------------------------
	local username = results.username
	local password = results.password
	local url = "http://localhost/photobook/wordpress/"
	
	mb_api.getUserInfo(url, username, password, onSuccess, onError)

end




local function cancelled(results)
	funx.tellUser ("Cancelled")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------




------------------------------------------------
-- MUST have another scene around if you want to call an overlay, or it crashes!
local scene = storyboard.newScene("main")

local widget = require "widget"

local function OpenDialogButtonRelease(event)
	-- Show the dialog
	dialog:show(event.target.id)
end

function scene:createScene( event )
        local group = self.view

        -----------------------------------------------------------------------------

        -- Testing open button
		local openButton = widget.newButton{
			id = "login",
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


local name = "login"

-- Options for the storyboard
local options = {
	effect = "fade",
	time = 250,
	isModal = true,
}

-- Options for the dialog builder
local params = {
	name = name,
	substitutions = {
		bookstore = "My Bookstore",
	},
	paramsFileName = "dialog_saved_params",
	dialogStructure = "dialog.structure.settings.json",
	restoreValues = true,	-- restore previous results from disk
	saveValues = true,	-- save the results to disk
	onSubmitButton = verify_user, -- set this function or have another scene check storyboard.dialogResults
	onCancelButton = cancelled, -- set this function or have another scene check storyboard.dialogResults
	showSavedFeedback = false,	-- show "saved" if save succeeds
	options = options,
}


-- Creates a new dialog scene
dialog.new(params)

dialog:show(name)