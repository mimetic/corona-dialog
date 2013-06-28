
local storyboard = require "storyboard"
storyboard.isDebug = true

local dialog = require ("dialog")






local function OpenDialogButtonRelease()

	local params = {
		username = "dgross",
		password = "pass",
		syspassword = "syspass",
		email = "dgross@mimetic.com",
		paramsFileName = "dialog_saved_params",
	}

	local options = {
		effect = "fade",
		time = 500,
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
end
scene:addEventListener( "overlayEnded" )

storyboard.gotoScene("main")
--------------------------------------------

