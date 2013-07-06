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

	Create, open, and remove a dialog screen.
	
	You can make custom dialog settings for each window using the settings file (an XML file!!!):
		(default) = dialog.settings.default.xml
	and/or
		dialog.settings.{name}.xml
		
	The structure of the dialog, meaning settings for text blocks and text input, as well as some size, colors, text, settings are in (a JSON file!!!):
		(default) = dialog.structure.default.json
	or
		dialog.structure.{name}.json

	local dialog = require("dialog")
	
	local name = "MyDialog"
	dialog.new(name) 	: creates a new storyboard scene which is a dialog 
	dialog:show(name)	: show the dialog
	dialog:remove(name)	: remove the dialog scene and clear it from memory

	The dialog table structure:
	dialog.window = {
		params = {},	-- save the setup params including storyboard options
		status = {},	-- the status includes flags, such as saveValues
		results = {},	-- the results of the dialog, i.e. the data
	}

	GOTCHA:
	- the label and description text blocks use textstyles, so the settings in the dialog structure probably won't have any effect. You'll wonder why change those values and nothing happens!!!

]]

local S = { window = {} };



local widget = require "widget"
local settingsLib = require("settings")
local onSwipe = require("onSwipe")
local funx = require ("funx")


local storyboard = require "storyboard"

local DIALOG_VALUES_FILE = "dialog.values.json"

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

-- A function the dialog can call with the results,
-- to save them or use them.
-- The alternative is to check "storyboard.dialogResults" which is set by the dialog.
local function saveValuesToDocuments(name, results, showSavedFeedback)
	--funx.dump(results)
	if (results) then
		local all_results = funx.loadTable(DIALOG_VALUES_FILE, system.DocumentsDirectory) or {}
		all_results[name] = results
		local res = funx.saveTable(all_results, DIALOG_VALUES_FILE, system.DocumentsDirectory)
		if (res and showDialogFeedback) then
			funx.tellUser("Saved")
		elseif (not res) then
			funx.tellUser("SYSTEM ERROR: Could not save the results to "..DIALOG_VALUES_FILE)
		end
	end	
end

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S.new(params)

	params.name = params.name or "dialog"
	params.name = funx.trim(params.name)
	local scene = storyboard.newScene(params.name)

	-- Table to hold the definition of a dialog window, text fields and text.
	local dialogDefinition = {}
	--widget.setTheme( "theme_ios" )

	local window = { 
		params = params,
		status = {},
		results = {},
	}
		

	-------------------------------------------------
	-- SETUP
	-------------------------------------------------

	-- Get settings
	local settingsName = "dialog.settings.".. params.name .. ".xml"
	if ( funx.fileExists(settingsName, system.ResourceDirectory) ) then
		settingsName = "dialog.settings.default.xml"
	end
	local settings = settingsLib.new(settingsName, system.ResourceDirectory)

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
	local systemTextStyles = funx.loadTextStyles("dialog.textstyles.txt", system.ResourceDirectory) or {}
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




	-------------------------------------------------
	-------------------------------------------------
	-- Build settings elements
	-- From a similar app:
	-- Registration, contact Us, Social Networks,
	-- other is a new screen, with About, Terms of Use, Legal Notices, Backups



	-------------------------------------------------
	-- makeTextInputField
	-- Create the text input fields
	-- Username/Password
	--[[
	Possible values are:

	"default" the default keyboard, supporting general text, numbers and punctuation
	"number" a numeric keypad
	"decimal" a keypad for entering decimal values
	"phone" a keypad for entering phone numbers
	"url" a keyboard for entering website URLs
	"email" a keyboard for entering email addresses

	From settings:
		<dialogFont value="Avenir-Light" />
		<dialogFontSize value="18" />
		<dialogFontColor value="100,100,100,100%" />
		<dialogTextLineHeight value="24" />
		<dialogTextSpaceAfter value="24" />
		<dialogBlockSpacing value="40" />
		<dialogInfoTextAlignment value="Center" />

	--]]

	local function makeTextInputField(g, label, desc, style, x,y, fieldX, w,h, value, isSecure, inputType, isTextBlock, fieldType)

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
	
		local linespace = funx.applyPercent(dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight, screenH)
		local spaceafter = funx.applyPercent(dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter, screenH)

	
	
		-- Write the description
		local descText = ""
		desc = desc or ""
		if (desc ~= "") then
			local p = {
				text = desc,
				font = dialogDefinition.dialogDescFont or settings.dialog.dialogDescFont,
				size = dialogDefinition.dialogDescFontSize or settings.dialog.dialogDescFontSize,
				width = funx.applyPercent(dialogDefinition.fieldDescWidth or settings.dialog.fieldDescWidth, screenW),
				textstyles = textstyles,
				defaultStyle = style or "dialogDescription",
				cacheDir = "",
			}
			descText = funx.autoWrappedText( p )
			g:insert(descText)
			descText:setReferencePoint(display.TopLeftReferencePoint)
			descText.x = x
			descText.y = y + descText.yAdjustment
			y = y + descText.height + funx.applyPercent(dialogDefinition.spaceAfterDesc or settings.dialog.spaceAfterDesc, screenH)
		end


		local font = dialogDefinition.dialogFont or settings.dialog.dialogFont
		local fontsize = dialogDefinition.dialogFontSize or settings.dialog.dialogFontSize


		-- Write the label
		local labelText = "" 	-- need height of this later
		label = label or ""
		if (label ~= "") then
			local p = {
				text = label,
				font = font,
				size = fontsize,
				width = dialogDefinition.fieldLabelWidth or settings.dialog.fieldLabelWidth,
				textstyles = textstyles,
				defaultStyle = "dialogLabel",
				cacheDir = "",
			}
			labelText = funx.autoWrappedText( p )
			g:insert(labelText)
			labelText:setReferencePoint(display.TopLeftReferencePoint)
			labelText.x = x
			labelText.y = y + labelText.yAdjustment
		end

		if (not isTextBlock) then
			if (fieldType == "textbox") then
				-- convert y to screen y
				local xScreen, yScreen = g:localToContent(x,y)

				-- Create the native textfield
				local textBox = native.newTextBox( 0, 0, w, h )
				textBox:setReturnKey('default')
				textBox.isEditable = true
				textBox:setReferencePoint(display.TopLeftReferencePoint)
				textBox.x = xScreen + fieldX
				textBox.y = yScreen
				textBox.font = native.newFont( font, fontsize )
				value = value or ""
				textBox.text = value
				textBox:addEventListener( "userInput", defaultHandler )
				return textBox, y
			else
				-- Text Field
				-- convert y to screen y
				local xScreen, yScreen = g:localToContent(x,y)

				-- Create the native textfield
				local textField = native.newTextField( 0, 0, w, labelText.height )
				textField:setReturnKey('next')
				textField:setReferencePoint(display.TopLeftReferencePoint)
				textField.x = xScreen + fieldX
				textField.y = yScreen
				textField.inputType = inputType or "default"
				textField.font = native.newFont( font, fontsize )
				value = value or ""
				textField.text = value
				textField.isSecure = isSecure

				textField:addEventListener( "userInput", defaultHandler )
				return textField, y
			end
		end -- if not text block
		
	end



	--------------------------------------------------------------------------------
	--[[
	Create text fields based on the settings file.

	Input Types for dialog fields:
		"default" the default keyboard, supporting general text, numbers and punctuation
		"number" a numeric keypad
		"decimal" a keypad for entering decimal values
		"phone" a keypad for entering phone numbers
		"url" a keyboard for entering website URLs
		"email" a keyboard for entering email addresses

	Each entry in the file MUST have a unique 'id' if it is an input field. If it does
	not have an id, with will be treated as an informational text block.

	Sample JSON structure for a dialog:
	(The 'value' fields are overwritten by values set in 'fields', in the params)
	[
	  {
		"desc": "You are connected to the bookstore {bookstore}.",
		"style": "dialogLargeDescription"
	  },
	  {
		"isSecure": false,
		"value": "OogaBooga",
		"label": "Username",
		"id": "username",
		"height": 30,
		"width": 300,
		"desc": "Enter your username and password to access books from the bookstore.",
		"inputType": "default"
	  },
	  {
		"isSecure": true,
		"value": "pass",
		"label": "Password",
		"id": "password",
		"height": 30,
		"width": 300,
		"desc": "",
		"inputType": "default"
	  },
	  {
		"isSecure": true,
		"value": "syspass",
		"label": "SysPass",
		"id": "syspassword",
		"height": 30,
		"width": 300,
		"desc": "Lock all books marked 18+ years with a pass code.",
		"inputType": "default"
	  }
	]
	--]]	


	local function makeTextFields(g, dialogDefinition, w,h, x,y )
		local textFields = {}

		local innermargins = {}
		for i,v in pairs(funx.split(settings.dialog.dialogInnerMargins)) do
			innermargins[#innermargins+1] = funx.applyPercent(v, screenW)
		end

		local linespace = funx.applyPercent(dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight, screenH)
		local spaceafter = funx.applyPercent(dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter, screenH)

		local fieldX = x + funx.applyPercent(dialogDefinition.dialogTextInputFieldXOffset or settings.dialog.dialogTextInputFieldXOffset, screenH)

		local k = 1
		for i,f in pairs(dialogDefinition) do
			if (not f.id) then
				-- Make a text block
				local style = f.style or "dialogLargeDescription"
				makeTextInputField(g, f.label, f.desc, f.style, x, y, fieldX, f.width, f.height, nil, nil, nil, true )
			else
				-- Make a text input field
				local style = f.style or "dialogDescription"
				textFields[f.id], y = makeTextInputField(g, f.label, f.desc, f.style, x, y, fieldX, f.width, f.height, f.value, f.isSecure, f.inputType, false, f.fieldType)
				k = k + 1
			end
			y = y + linespace + spaceafter
		end

		return textFields
	end




	-- Make some text for the settings
	local function buildSettingsText(g, t, w, x, y)

		local p = {
			text = t,
			width = w,
			textstyles = textstyles,
			defaultStyle = "dialogBody",
			cacheDir = "",
		}
		local text = funx.autoWrappedText( p )

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

		-- a string in the form, L,T,R,B
		local innermargins = {}
		local im = dialogDefinition.dialogInnerMargins or settings.dialog.dialogInnerMargins
		for i,v in pairs(funx.split(im)) do
			innermargins[#innermargins+1] = funx.applyPercent(v, screenW)
		end

		local p = {
			text = dialogDefinition.dialogTitle or settings.dialog.dialogTitle,
			width = g.width - innermargins[1] - innermargins[3],
			textstyles = textstyles,
			defaultStyle = "dialogTitle",
			align = "center",
			cacheDir = "",
		}
		local titleText = funx.autoWrappedText( p )
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
		S.window[params.name].status.cancel = false
		S.window[params.name].status.submit = true
		storyboard.hideOverlay("fade", 500)
		return true
	end


	----------------------------------------
	-- Cancel the dialog
	-- It is a modal scene, by the way.

	local function cancelDialogButtonRelease()
		S.window[params.name].status.cancel = true
		S.window[params.name].status.submit = false
		storyboard.hideOverlay("fade", 500)
		return true
	end



	---------------------------------------------------------------------------------
	-- BEGINNING OF YOUR IMPLEMENTATION
	-- Note, new params contains passed params to the dialog object
	---------------------------------------------------------------------------------

	-- Called when the scene's view does not exist:
	-- Some settings come from either the dialog definition OR the settings file, with the
	-- dialog definition taking precendent. Other settings should be the same though the app
	-- only come from the settings.
	function scene:createScene( event )
		local group = self.view
		rebuildDisplaySettings()

		local bkgd = display.newGroup()
		group:insert(bkgd)
		group.bkgd = bkgd

		-- The structure of the dialog is a JSON file in the system folder
		local filename
		if (params.name) then
			filename = "dialog.structure." .. funx.trim(params.name) .. ".json"
		else
			filename = "dialog.structure.default.json"
		end
		dialogDefinition = funx.loadTable(filename, system.ResourceDirectory)

		local margins = {}
		for i,v in pairs(funx.split(dialogDefinition.dialogWindowMargins or settings.dialog.dialogWindowMargins)) do
			margins[#margins+1] = funx.applyPercent(v, screenW)
		end

		local backgroundColor = dialogDefinition.dialogBackgroundColor or settings.dialog.dialogBackgroundColor
		local rrectCorners = 10
	
		-- BACKGROUND + CLOSE BUTTON + CANCEL BUTTON
		local r = display.newRoundedRect(bkgd, margins[1], margins[2], screenW - margins[1] - margins[3],screenH - margins[2] - margins[4], rrectCorners, rrectCorners)
		local color = funx.stringToColorTable (backgroundColor)
		r:setFillColor(color[1], color[2], color[3], color[4])

		local bkgdWidth = r.width
		local bkgdHeight = r.height

		-- Close button - same as "OK"
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
		r:setReferencePoint(display.TopRightReferencePoint)

		-- top right corner
		--closeButton.x = midscreenX + (bkgdWidth/2) + (closeButton.width/2)
		--closeButton.y = midscreenY - (bkgdHeight)/2 - (closeButton.width/2)
		--closeButton.y = r.y - (closeButton.height/2)

		-- Inside top right
		closeButton.x = midscreenX + (bkgdWidth/2) - 20
		closeButton.y = r.y + 20


		-- Cancel button
		local cancelButton = widget.newButton{
			id = "dialogcancel",
			defaultFile = settings.dialog.dialogCancelButton,
			overFile = settings.dialog.dialogCancelButtonOver,
			width = settings.dialog.dialogCancelButtonWidth,
			height = settings.dialog.dialogCancelButtonHeight,
			onRelease = cancelDialogButtonRelease,
		}
		bkgd:insert(cancelButton)
	
		-- top right on edge
		cancelButton:setReferencePoint(display.TopRightReferencePoint)
	
		-- allow 10 px for the shadow of the popup background
		cancelButton.x = midscreenX + (bkgdWidth/2) + (cancelButton.width/2) - cancelButton.width - 20
		--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
		cancelButton.y = r.y - (cancelButton.height/2)

		-- top right inside, 2nd position
		cancelButton:setReferencePoint(display.TopRightReferencePoint)
		-- allow 10 px for the shadow of the popup background
		cancelButton.x = midscreenX + (bkgdWidth/2)  - cancelButton.width - (2*20)
		--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
		cancelButton.y = r.y + 20


	end



	-- Called BEFORE scene has moved onscreen:
	function scene:willEnterScene( event )
		local group = self.view
	
		-- Structure of dialog was read into 'dialogDefinition' in 'create'

		if (dialogDefinition) then
	
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
			for i,v in pairs(funx.split(dialogDefinition.dialogInnerMargins or settings.dialog.dialogInnerMargins)) do
				innermargins[#innermargins+1] = funx.applyPercent(v, screenW)
			end

			local linespace = funx.applyPercent(dialogDefinition.dialogTextLineHeight or dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight, screenH)
			local blockspace = funx.applyPercent(dialogDefinition.dialogBlockSpacing or dialogDefinition.dialogBlockSpacing or settings.dialog.dialogBlockSpacing, screenH)
			local spaceafter = funx.applyPercent(dialogDefinition.dialogTextSpaceAfter or dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter, screenH)
			local blockwidth =  bkgd.width - innermargins[2] - innermargins[4]
			local contentY = funx.applyPercent(dialogDefinition.dialogContentY or dialogDefinition.dialogContentY or settings.dialog.dialogContentY, settingsElements.height)

			-- INFO TEXT
			-- Info, e.g. connected to which website...
			y =  contentY

	

			-- Enter the values from params into the table
			
			-- If params.fields is set, use those values
			-- Otherwise, if restoreValues is set, try to get the values from a saved
			-- table in the documents folder
			local fields = {}
			if (params.fields and type(params.fields) == "table" ) then
				fields = params.fields
			elseif (params.restoreValues) then
				all_results = funx.loadTable(DIALOG_VALUES_FILE, system.DocumentsDirectory)
				fields = all_results[params.name]
			end
			
			local subs = params.substitutions
			for i, f in pairs(dialogDefinition.elements) do
				-- Subsitutions in the label/desc fields		
				f.label = funx.substitutions (f.label, subs)
				f.desc = funx.substitutions (f.desc, subs)
		
				if (fields[f.id] and fields[f.id] ~= "") then
					f.value = fields[f.id]
				end
			end

			x = innermargins[2]--midscreenX - (settingsElements.width/2) + innermargins[2]

			self.nativeTextfields = makeTextFields(settingsElements, dialogDefinition.elements, settingsElements.width, settingsElements.height, x,y)

			-- Clear flags created when the dialog is close
			S.window[params.name].didExitScene = false
			S.window[params.name].destroyScene = false

		end
	
	end



	-- Called immediately after scene has moved onscreen:
	function scene:enterScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		-- Save the params into the scene itself b/c params
		-- is not available after this point.
		group.params = params

		-----------------------------------------------------------------------------

	end


	-- Called when scene is about to move offscreen:
	function scene:exitScene( event )
		local group = self.view
		local results = {}
		-- Get the params, saved for us by enterScene
		local params = group.params

		-- Remove the settings elements, since these might change and are rebuilt each time.
		group.dialogElements:removeSelf()
		
		-- Remove any native text fields
		if (self.nativeTextfields) then
			-- Get text field values
			for id,f in pairs(self.nativeTextfields) do
				results[id] = f.text
				--funx.tellUser ( "Text entered = " ..  f.text )
				f:removeSelf()
			end

			self.nativeTextfields = nil
		end
		
		-- Save results to the module's window table, e.g. dialog.window['mydialog'].results
		S.window[params.name].results = results
		
		-- Submit hit (i.e. "OK" button)
		if ( S.window[params.name].status.submit ) then
			-- save?
			if (params.saveValues) then
				saveValuesToDocuments(params.name, results, params.showSavedFeedback)
			end
			-- execute the success function passed in params
			if (params.onSubmitButton) then
				params.onSubmitButton(results)
			end
		elseif (S.window[params.name].status.cancel) then
			if (params.onSubmitButton) then
				params.onCancelButton(results)
			end
		end
		

	end


	-- Called AFTER scene has finished moving offscreen:
	function scene:didExitScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		S.window[params.name].didExitScene = true

		-----------------------------------------------------------------------------
		

	end


	-- Called prior to the removal of scene's "view" (display group)
	function scene:destroyScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		S.window[params.name].destroyScene = true

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

	-- DO NOT NEED BECAUSE THE DIALOG IS AN OVERLAY AND CANNOT CALL ANOTHER ONE
	-- "overlayBegan" event is dispatched when an overlay scene is shown
	--scene:addEventListener( "overlayBegan", scene )

	-- "overlayEnded" event is dispatched when an overlay scene is hidden/removed
	--scene:addEventListener( "overlayEnded", scene )

	---------------------------------------------------------------------------------
	-- Save the params, settings, and results in an easily accessible place
	S.window[params.name] = window

end -- new()



---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S:show(name)
	if (not self.window[name]) then
		return false
	end
	if (self.window[name].destroyScene) then
		S.new(self.window[name].params)
	end
	
	storyboard.showOverlay( name, self.window[name].params.options )
end -- show()


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S:remove(name)
	self.window[name] = nil
end -- show()


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

return S