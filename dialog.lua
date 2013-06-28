-- dialog.lua
--
-- Version 0.2
--
-- Copyright (C) 2010 David I. Gross. All Rights Reserved.
--
-- This software is is protected by the author's copyright, and may not be used, copied,
-- modified, merged, published, distributed, sublicensed, and/or sold, without
-- written permission of the author.
--
-- The above copyright notice and this permission notice shall be included in all copies
-- or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
--[[

	Open a settings entry window, get values, return values.

	new() returns a storyboard scene which is the dialog

]]

local S = {}

--local widget = require "widget-v1"
local widget = require "widget"
local settingsLib = require("settings")
local onSwipe = require("onSwipe")
local funx = require ("funx")


local storyboard = require "storyboard"
local scene = storyboard.newScene()

--widget.setTheme( "theme_ios" )



-------------------------------------------------
-- SETUP
-------------------------------------------------

-- Get settings
local settingsName = settingsName or "dialog"
local settings = settingsLib.new("settings.".. settingsName .. ".xml", system.ResourceDirectory)

-- What is the proper orientation for this book? We must draw it correctly.
-- If this is not a correct orientation, then obviously we reverse the height/width!
local screenW, screenH, viewableScreenW, viewableScreenH, screenOffsetW, screenOffsetH, midscreenX, midscreenY
local scalingRatio, bottom, top, tbHeight, contentAreaHeight

-------------------------------------------------
-- In case the screen changes, e.g. orientation change, this must called!
-------------------------------------------------
local function rebuildDisplaySettings()
	screenW, screenH = display.contentWidth, display.contentHeight
	viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
	screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
	midscreenX = screenW*(0.5)
	midscreenY = screenH*(0.5)

end
rebuildDisplaySettings()

local topStatusBarContentHeight = funx.getStatusBarHeight()

-------------------------------------------------
-- Load text formatting styles used by funx.lua text formatting
-- Load system and user text formatting styles used by funx.lua text formatting
-- Merge User and System styles, where user replace system
-------------------------------------------------
local textstyles = {}
if (funx.fileExists("_user/textstyles.txt", system.ResourceDirectory)) then
	textstyles = funx.loadTextStyles("_user/textstyles.txt", system.ResourceDirectory) or {}
end
local systemTextStyles = funx.loadTextStyles("textstyles.dialog.txt", system.ResourceDirectory) or {}
local userTextStyles = {}
local p = "_user/textstyles.txt"
if (funx.fileExists(p, system.ResourceDirectory)) then
	userTextStyles = funx.loadTextStyles(p, system.ResourceDirectory) or {}
end
if (userTextStyles) then
	-- merge with system styles, overwriting system
	for n,v in pairs(userTextStyles) do
		systemTextStyles[n] = v
	end
end
local textstyles = systemTextStyles

local sceneName = "settings"




-------------------------------------------------
-------------------------------------------------
-- Build settings elements
-- From a similar app:
-- Registration, contact Us, Social Networks,
-- other is a new screen, with About, Terms of Use, Legal Notices, Backups

-- Create the text input fields
-- Username/Password
local function makeTextInputField(g, label, x,y, fieldX, w,h, value, isSecure)

			---------------------------------------------------------------
			-- TextField Listener
			local function textFieldHandler( getObj )

					-- Use Lua closure in order to access the TextField object
					return function( event )
							print ("Event Phase:",event.phase)

							local text = tostring(getObj().text)

							if ( "began" == event.phase ) then
									-- This is the "keyboard has appeared" event

							elseif ( "ended" == event.phase ) then
									-- This event is called when the user stops editing a field:
									-- for example, when they touch a different field or keyboard focus goes away
									funx.tellUser ( "Text entered = " .. tostring( getObj().text ) )

							elseif ( "submitted" == event.phase ) then
									-- This event occurs when the user presses the "return" key
									-- (if available) on the onscreen keyboard
									--T.field.text = tostring( getObj().text )
funx.tellUser ( "Text entered = " .. tostring( getObj().text ) )
									-- Hide keyboard
									native.setKeyboardFocus( nil )
									submit()
							end
					end

			end


			 -- passes the text field object
			local function defaultHandler(event)
				textFieldHandler( function() return defaultField end )
			end
	label = label or ""
	local params = {
		text = label,
		width = fieldX,
		textstyles = textstyles,
		defaultStyle = "dialogLabel",
		cacheDir = "",
	}
	local labelText = funx.autoWrappedText( params )
	g:insert(labelText)
	labelText:setReferencePoint(display.TopLeftReferencePoint)
	labelText.x = x
	labelText.y = y + labelText.yAdjustment


	-- convert y to screen y
	local xScreen, yScreen = g:localToContent(x,y)

	-- Sign-in with registration, probably email, password?
	local textField = native.newTextField( 0, 0, w, settings.dialog.dialogFontSize )
	textField:setReferencePoint(display.TopLeftReferencePoint)
	textField.x = xScreen + fieldX
	textField.y = yScreen
	value = value or ""
	textField.text = value
	if (isSecure) then
		textField.isSecure = true
	end

	textField:addEventListener( "userInput", defaultHandler )

	return textField

end


-- Make some text for the settings
local function buildSettingsText(g, t, w, x, y)

	local params = {
		text = t,
		width = w,
		textstyles = textstyles,
		defaultStyle = "dialogBody",
		cacheDir = "",
	}
	local text = funx.autoWrappedText( params )

	if (g) then
		g:insert(text)
	end
	text:setReferencePoint( display.TopLeftReferencePoint )
	text.x = x
	text.y = y + text.yAdjustment

	return text
end



-- Create the settings elements including background
local function buildSettingsElements(w,h)
	local g = display.newGroup()

	-- full-screen positioning rect
	local r = display.newRect(g,0,0,w,h)
local testing = false
	r.isVisible = testing
	r:setFillColor(240,0,0,50)
	r:setReferencePoint( display.TopLeftReferencePoint )
	r.x = 0
	r.y = 0

	local innermargins = {}
	for i,v in pairs(funx.split(settings.dialog.dialogInnerMargins)) do
		innermargins[#innermargins+1] = funx.applyPercent(v, screenW)
	end

	local params = {
		text = settings.dialog.dialogTitle,
		width = g.width - innermargins[1] - innermargins[3],
		textstyles = textstyles,
		defaultStyle = "dialogTitle",
		align = "center",
		cacheDir = "",
	}
	local titleText = funx.autoWrappedText( params )
	g:insert(titleText)

	-- title
	titleText:setReferencePoint( display.TopLeftReferencePoint )
	local color =  funx.stringToColorTable (settings.dialog.dialogTitleFontColor)
	titleText.x = innermargins[1]
	titleText.y = innermargins[2]

	return g
end


----------------------------------------
-- Close the dialog
-- It is a modal scene, by the way.

local function closeDialogButtonRelease()
	storyboard.hideOverlay("fade", 500)
	return true
end



---------------------------------------------------------------------------------
-- BEGINNING OF YOUR IMPLEMENTATION
-- Note, new event.params contains passed params to the openScene()
---------------------------------------------------------------------------------

-- Called when the scene's view does not exist:
function scene:createScene( event )
	local group = self.view
	rebuildDisplaySettings()

	local bkgd = display.newGroup()
	group:insert(bkgd)
	group.bkgd = bkgd

	local margins = {}
	for i,v in pairs(funx.split(settings.dialog.dialogWindowMargins)) do
		margins[#margins+1] = funx.applyPercent(v, screenW)
	end

	-- BACKGROUND + CLOSE BUTTON
	local r = display.newRoundedRect(bkgd, margins[1], margins[2], screenW - margins[1] - margins[3],screenH - margins[2] - margins[4], 10, 10)
	local color = funx.stringToColorTable (settings.dialog.dialogBackgroundColor)
	r:setFillColor(color[1], color[2], color[3], color[4])

	local bkgdWidth = bkgd.width
	local bkgdHeight = bkgd.height

	-- Close button
	local closeButton = widget.newButton{
		id = "dialogclose",
		defaultFile = settings.dialog.dialogCloseButton,
		overFile = settings.dialog.dialogCloseButtonOver,
		width = settings.dialog.dialogCloseButtonWidth,
		height = settings.dialog.dialogCloseButtonHeight,
		onRelease = closeDialogButtonRelease,
	}
	bkgd:insert(closeButton)
	closeButton:setReferencePoint(display.TopRightReferencePoint)
	-- allow 10 px for the shadow of the popup background
	closeButton.x = midscreenX + (bkgdWidth/2) + (closeButton.width/2)
	closeButton.y = midscreenY - (bkgdHeight)/2 - (closeButton.width/2)
end


-- Called BEFORE scene has moved onscreen:
function scene:willEnterScene( event )
	local group = self.view

	local x = 0
	local y = 0
	local t = ""
	local tblock = {}

	local bkgd = group.bkgd
	bkgd:setReferencePoint( display.CenterReferencePoint )

	-- SETTINGS ELEMENTS, text, etc.
	local settingsElements = buildSettingsElements(bkgd.width, bkgd.height)
	group:insert(settingsElements)
	group.dialogElements = settingsElements
	settingsElements:setReferencePoint( display.CenterReferencePoint )

	settingsElements.x = bkgd.x
	settingsElements.y = bkgd.y

	local innermargins = {}
	for i,v in pairs(funx.split(settings.dialog.dialogInnerMargins)) do
		innermargins[#innermargins+1] = funx.applyPercent(v, screenW)
	end

	local linespace = funx.applyPercent(settings.dialog.dialogTextLineHeight, screenH)
	local blockspace = funx.applyPercent(settings.dialog.dialogBlockSpacing, screenH)
	local spaceafter = funx.applyPercent(settings.dialog.dialogTextSpaceAfter, screenH)
	local blockwidth =  bkgd.width - innermargins[2] - innermargins[4]
	local contentY = funx.applyPercent(settings.dialog.dialogContentY, settingsElements.height)

	-- INFO TEXT
	-- Info, e.g. connected to which website...
	t = funx.substitutions(settings.dialog.msgDialogBookstore, { bookstore = settings.dialog.httpShelvesServer } )
	tblock = buildSettingsText(settingsElements, t, blockwidth, innermargins[2], funx.applyPercent(settings.dialog.dialogContentY, settingsElements.height))
	settingsElements:insert(tblock)
	y =  contentY + tblock.height + blockspace

	-- Sign-in instructions
	-- Info, e.g. connected to which website...
	t = settings.dialog.msgDialogSignin
	tblock = buildSettingsText(settingsElements, t, blockwidth, innermargins[2], y)
	settingsElements:insert(tblock)
	y = y + tblock.height + spaceafter

	-- TEXT INPUT
	-- Create the text input fields. Not OpenGL so let's handle this separately.
	-- Positioning won't come from the group, so we have to translate positions.
	-- Use the margins (above) to position
	-- The text field has its own X position so fields can be left-aligned.
	-- Pass field X position as distance from left side, not dependent on length of the label.
	local x = innermargins[2]--midscreenX - (settingsElements.width/2) + innermargins[2]
	local fieldX = x + funx.applyPercent(settings.dialog.dialogTextInputFieldXOffset, screenH)
	local usernameField = makeTextInputField(settingsElements, "Username:", x, y, fieldX, 300, 30, event.params.username, false)
	y = y + linespace + spaceafter

	local pwField = makeTextInputField(settingsElements, "Password:", x, y, fieldX, 200, 30, event.params.password, true)	-- true->is password
	y = y + linespace + blockspace


	-- Child Lock instructions
	t = settings.dialog.msgDialogChildLock
	tblock = buildSettingsText(settingsElements, t, blockwidth, innermargins[2], y)
	settingsElements:insert(tblock)
	y = y + tblock.height + spaceafter

	local syspwField = makeTextInputField(settingsElements, "Child Lock:", x, y, fieldX, 40, 30, event.params.syspassword, true)	-- true->is password

	-- Save the text fields for later destruction
	self.nativeTextfields = { username = usernameField, password = pwField, syspassword = syspwField }

end



-- Called immediately after scene has moved onscreen:
function scene:enterScene( event )
	local group = self.view

	-----------------------------------------------------------------------------

	-- Save the event.params into the scene itself b/c event.params
	-- is not available after this point.
	group.params = event.params

	-----------------------------------------------------------------------------

end


-- Called when scene is about to move offscreen:
function scene:exitScene( event )
	local group = self.view

funx.dump(event.params)
local params = group.params

	-- Remove the settings elements, since these might change and are rebuilt each time.
	group.dialogElements:removeSelf()

	if (self.nativeTextfields) then
		-- Get text field values
		for i,f in pairs(self.nativeTextfields) do
			params[i] = f.text
			funx.tellUser ( "Text entered = " ..  f.text )
			f:removeSelf()
		end

		if (params) then
			local fn = params.paramsFileName or "saved_dialog_values"
			local res = funx.saveTable(params, fn .. ".json", system.DocumentsDirectory)
			if (not res) then
				funx.telluser("SYSTEM ERROR: Could not save the settings!")
			end
		end

		self.nativeTextfields = nil
	end
end


-- Called AFTER scene has finished moving offscreen:
function scene:didExitScene( event )
	local group = self.view

	-----------------------------------------------------------------------------

	--	This event requires build 2012.782 or later.

	-----------------------------------------------------------------------------

end


-- Called prior to the removal of scene's "view" (display group)
function scene:destroyScene( event )
	local group = self.view

	-----------------------------------------------------------------------------

	--	INSERT code here (e.g. remove listeners, widgets, save state, etc.)

	-----------------------------------------------------------------------------

end


---------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
---------------------------------------------------------------------------------

-- "createScene" event is dispatched if scene's view does not exist
scene:addEventListener( "createScene", scene )

-- "willEnterScene" event is dispatched before scene transition begins
scene:addEventListener( "willEnterScene", scene )

-- "enterScene" event is dispatched whenever scene transition has finished
scene:addEventListener( "enterScene", scene )

-- "exitScene" event is dispatched before next scene's transition begins
scene:addEventListener( "exitScene", scene )

-- "didExitScene" event is dispatched after scene has finished transitioning out
scene:addEventListener( "didExitScene", scene )

-- "destroyScene" event is dispatched before view is unloaded, which can be
-- automatically unloaded in low memory situations, or explicitly via a call to
-- storyboard.purgeScene() or storyboard.removeScene().
scene:addEventListener( "destroyScene", scene )

-- "overlayBegan" event is dispatched when an overlay scene is shown
scene:addEventListener( "overlayBegan", scene )

-- "overlayEnded" event is dispatched when an overlay scene is hidden/removed
scene:addEventListener( "overlayEnded", scene )

---------------------------------------------------------------------------------

return scene