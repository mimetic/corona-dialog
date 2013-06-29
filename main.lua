
local storyboard = require "storyboard"
storyboard.isDebug = true

local dialog = require ("dialog")


-- A function the dialog can call with the results,
-- to save them or use them.
-- The alternative is to check "storyboard.dialogResults" which is set by the dialog.
local function saveResults(results)
	funx.dump(results)
	if (results) then
		local fn = "saved_dialog_values"
		local res = funx.saveTable(results, fn .. ".json", system.DocumentsDirectory)
		if (not res) then
			funx.telluser("SYSTEM ERROR: Could not save the results!")
		end
	end
end



local function OpenDialogButtonRelease()
	local params = {
		fields = {
			username = "MyUserName",
			password = "MyPassword",
			syspassword = "MySysPass",
			email = "dgross@mimetic.com",
		},
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
		openButton.x = 100
		openButton.y = 100
		openButton:toFront()

        -----------------------------------------------------------------------------

end
scene:addEventListener( "createScene" )

-- the following event is dispatched once the overlay is in place
function scene:overlayBegan( event )
    print( "Main scene says, showing overlay: " .. event.sceneName )
end
scene:addEventListener( "overlayBegan" )

-- the following event is dispatched once overlay is removed
function scene:overlayEnded( event )
    print( "Main scene says, Overlay removed: " .. event.sceneName )
	funx.dump(storyboard.dialogResults)
	print( "----" )

end
scene:addEventListener( "overlayEnded" )

storyboard.gotoScene("main")
--------------------------------------------

OpenDialogButtonRelease()