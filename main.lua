require( 'scripts.dmc.dmc_kolor' )
require ( 'scripts.patches.refPointConversions' )

local funx = require( "funx" )

--------------------------------------------
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
local midscreenX = screenW*(0.5)
local midscreenY = screenH*(0.5)


local storyboard = require "storyboard"
storyboard.isDebug = true

-- This is the specialized module to handle the app settings GUI
local settings_gui = require("scripts.dialog.settings_gui")

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






-- THIS IS FOR TESTING:
------------------------------------------------
local scene = storyboard.newScene("main")
local widget = require "widget"

local settingsDialogName = "settingsDialog"
local signInDialogName = "signinDialog"
local newAccountDialogName = "createAccountDialog"

function scene:createScene( event )
        local group = self.view

        -----------------------------------------------------------------------------
		local r = display.newRect(group, 0,0,screenW,screenH)
		funx.anchorTopLeftZero(r)

			--- Show a dialog based on a button id.
			local function OpenDialogButtonRelease(event)
				settings_gui.showDialog(event.target.id)
			end




        -- Testing open dialog #1 button
		local openButton = widget.newButton{
			id = signInDialogName,
			defaultFile = "_ui/button-gear-gray.png",
			overFile = "_ui/button-gear-gray-over.png",
			width = 44,
			height = 44,
			onRelease = OpenDialogButtonRelease,
		}
		group:insert(openButton)
		openButton.x = 40
		openButton.y = 80
		openButton:toFront()

        -- Testing open dialog #2 button
		local openButtonB = widget.newButton{
			id = newAccountDialogName,
			defaultFile = "_ui/button-gear-gray.png",
			overFile = "_ui/button-gear-gray-over.png",
			width = 44,
			height = 44,
			onRelease = OpenDialogButtonRelease,
		}
		group:insert(openButtonB)
		openButtonB.x = 100
		openButtonB.y = 80
		openButtonB:toFront()
		openButtonB:setFillColor( 250,50,50, 250 )


        -- Testing open dialog #2 button
		local openButtonC = widget.newButton{
			id = settingsDialogName,
			defaultFile = "_ui/button-gear-gray.png",
			overFile = "_ui/button-gear-gray-over.png",
			width = 44,
			height = 44,
			onRelease = OpenDialogButtonRelease,
		}
		group:insert(openButtonC)
		openButtonC.x = 160
		openButtonC.y = 80
		openButtonC:toFront()
		openButtonC:setFillColor( 50,50,250, 250 )



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


local testing = true
		if (testing) then
			local widget = require ( "widget" )
			local wf = false
			local function toggleWireframe()
				wf = not wf
				display.setDrawMode( "wireframe", wf )
				if (not wf) then
					display.setDrawMode( "forceRender" )
				end
				print ("WF = ",wf)
			end
		
			local wfb = widget.newButton{
						label = "WIREFRAME",
						labelColor = { default={ 200, 1, 1 }, over={ 250, 0, 0, 0.5 } },
						fontSize = 20,
						x =10,
						y=10,
						onRelease = toggleWireframe,
					}
			wfb:toFront()
			funx.anchorTopLeft(wfb)
		end

