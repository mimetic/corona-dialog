-- dialog.lua
--
-- Version 0.1
--
-- Copyright (C) 2013 David I. Gross. All Rights Reserved.
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
		status = {},	-- the status includes flags, such as writeValues
		results = {},	-- the results of the dialog, i.e. the data
	}

	GOTCHA:
	- the label and description text blocks use textstyles, so the settings in the dialog structure probably won't have any effect. You'll wonder why change those values and nothing happens!!!

Input Types in the structure:
	Possible values are:

	"default" the default keyboard, supporting general text, numbers and punctuation
	"number" a numeric keypad
	"decimal" a keypad for entering decimal values
	"phone" a keypad for entering phone numbers
	"url" a keyboard for entering website URLs
	"email" a keyboard for entering email addresses


--]]

local S = { window = {} };



local widget = require "widget"
local settingsLib = require("settings")
--local onSwipe = require("onSwipe")
local funx = require ("funx")


local storyboard = require "storyboard"

local DIALOG_VALUES_FILE = "dialog.values.json"

-- Get dialog module default settings
S.settings = settingsLib.new("dialog.settings.default.xml", system.ResourceDirectory)

-------------------------------------------------
-- Load text formatting styles used by funx.lua text formatting
-- Load system and user text formatting styles used by funx.lua text formatting
-- Merge User and System styles, where user replace system
-------------------------------------------------

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
S.textstyles = systemTextStyles

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



----------------------------------------
-- Close the dialog
-- If the dialog is NOT modal:
	-- If the cancelToSceneName is set, then go to that scene.
	-- Otherwise, go to the previous scene
-- If it is modal, just close it

function S.closeDialog(windowname)
	local windowName = windowname or storyboard.getCurrentSceneName()
	S.window[windowname].status =  {
		cancel = false,
		submit = true,
	}
	if (S.window[windowname].params.isModal) then
		storyboard.hideOverlay("fade", 500)
	else
		local previous_scene_name = S.window[windowname].params.cancelToSceneName or storyboard.getPrevious()
		if (previous_scene_name) then
			storyboard.gotoScene(previous_scene_name, S.window[windowname].params.options)
		end
	end
	return true
end


local function closeDialogButtonRelease(event)
	local windowname = event.target.id
	return S.closeDialog(windowname)
end


----------------------------------------
-- Cancel the dialog
-- If the dialog is NOT modal:
	-- If the cancelToSceneName is set, then go to that scene.
	-- Otherwise, go to the previous scene
-- If it is modal, just close it

local function cancelDialogButtonRelease(event)
	local windowname = event.target.id
	S.window[windowname].status.cancel = true
	S.window[windowname].status.submit = false
	if (S.window[windowname].params.isModal) then
		storyboard.hideOverlay("fade", 500)
	else
		local previous_scene_name = S.window[windowname].params.cancelToSceneName or storyboard.getPrevious()
		if (previous_scene_name) then
			storyboard.gotoScene(previous_scene_name, S.window[windowname].params.options)
		end
	end
	return true
end




--- A function the dialog can call with the results,
-- to save them or use them.
-- The alternative is to check "storyboard.dialogResults" which is set by the dialog.
function S:addValuesToDocuments(name, results, showSavedFeedback)
	--funx.dump(results)
	if (results) then
		local all_results = funx.loadTable(DIALOG_VALUES_FILE, system.DocumentsDirectory) or {}
		all_results[name] = funx.tableMerge(all_results[name], results)
		local res = funx.saveTable(all_results, DIALOG_VALUES_FILE, system.DocumentsDirectory)
		if (res and showDialogFeedback) then
			funx.tellUser("Saved")
		elseif (not res) then
			funx.tellUser("SYSTEM ERROR: Could not save the results to "..DIALOG_VALUES_FILE)
		end
	end
end

-- A function the dialog can call with the results,
-- to save them or use them.
-- The alternative is to check "storyboard.dialogResults" which is set by the dialog.
function saveValuesToDocuments(name, results, showSavedFeedback)
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


--- Get native field values
-- If no scene name is provided, the current scene is used
-- If a confirmation field doesn't match, don't return the value of the source field
-- Also, don't return the confirmation field as a value

function S:getFieldValues(windowName)
	local windowName = windowName or storyboard.getCurrentSceneName()
	local r = {}
	if (self.window[windowName] and self.window[windowName].elements and self.window[windowName].elements.fields) then
		-- Get text field values
		for id,f in pairs(self.window[windowName].elements.fields) do
			r[id] = f.text
		end

		-- Now deal with confirmations after we've fully loaded the table
		for id,f in pairs(self.window[windowName].elements.fields) do
			if (f.isConfirmation) then
				print (id, "is a confirmation field", f.isConfirmation)
				if (f.text ~= r[f.isConfirmation]) then
					r[f.isConfirmation] = nil
				end
				r[id] = nil
			end
		end

	end
	return r
end


function S:updateScreenFieldValues(windowName, values)
	local windowName = windowName or storyboard.getCurrentSceneName()
	if (self.window[windowName] and self.window[windowName].elements and self.window[windowName].elements.fields) then
		-- Get text field values
		for id,f in pairs(self.window[windowName].elements.fields) do
			f.text = values[id]
			--print ("updating "..id.." with ".. values[id])
		end
	end
end


--- Update a dialog
-- Use conditions to show/hide elements
-- @param windowName
-- @param conditions (table)
-- @result

function S:updateDialogByConditions(windowName, conditions)
	local windowName = windowName or storyboard.getCurrentSceneName()
	if (conditions) then
		self.window[windowName].conditions = conditions
	end
	local dialogDefinition = S.window[windowName].dialogDefinition
	if (self.window[windowName] and self.window[windowName].elements ) then
		for id,f in pairs(self.window[windowName].elements.all) do
			local c = f.condition
			local cc = conditions[f.condition]
			if (f.condition and not conditions[f.condition]) then
				f.isVisible = false
				--print ("updateDialogByConditions: Hide ",id)
			else
				f.isVisible = true
				--print ("updateDialogByConditions: Show ",id)
			end

		end
	end
end


--- Make a textblock in the dialog
-- Since this in the new() function, the 'window' it knows is the one for this dialog.
-- So, we don't have to pass the dialog definition at all.
-- NOTE: the font & size are ignored! The style comes from 'dialogDescription' style,
-- assuming it exists. Font/size are fallbacks in worst case.
function S:makeTextBlock(windowName, params)
	local windowName = windowName or storyboard.getCurrentSceneName()
	local window = self.window[windowName]
	-- Write the description
	-- Note, width can be percent of background (g object) width, not screen width
	local textblock = ""
	params.text = params.text or ""
	if (params.text ~= "") then
		local p = {
			text = params.text,
			font = window.dialogDefinition.dialogDescFont or self.settings.dialog.dialogDescFont,
			size = window.dialogDefinition.dialogDescFontSize or self.settings.dialog.dialogDescFontSize,
			width = funx.applyPercent(window.dialogDefinition.fieldDescWidth or self.settings.dialog.fieldDescWidth, params.width),
			textstyles = self.textstyles,
			defaultStyle = params.style or "dialogDescription",
			cacheDir = "",
		}
		textblock = funx.autoWrappedText( p )
		textblock:setReferencePoint(display.TopLeftReferencePoint)
		return textblock
	end
end


--- Remake a textblock in the dialog
-- Assume the width stays the same!

function S:replaceTextBlock(windowName, id, params, subs)
	local windowName = windowName or storyboard.getCurrentSceneName()
	if (self.window[windowName] and self.window[windowName].elements) then
		local p = self.window[windowName].elements.textblocks[id].params
		p = funx.tableMerge(p, params)
		local obj = self.window[windowName].elements.textblocks[id].textblock
		if (obj) then
			-- Get the parent of the object
			local g = obj.parent
			local x = obj.x
			local y = obj.y

			-- remove existing object
			obj:removeSelf()
			obj = nil
			-- Create new object
			subs = subs or {}
			p.text = funx.substitutions (p.text, subs)
			self.window[windowName].elements.textblocks[id].params = p
			self.window[windowName].elements.textblocks[id].textblock = S:makeTextBlock(windowName, p)
			g:insert(self.window[windowName].elements.textblocks[id].textblock)
			self.window[windowName].elements.textblocks[id].textblock.x = x
			self.window[windowName].elements.textblocks[id].textblock.y = y
		end
	end
end



--- Make a button in the dialog
function S:makeButton(windowName, params)

	local windowName = windowName or storyboard.getCurrentSceneName()
	local window = self.window[windowName]

	-- innermargins: L,T,R,B

	-- Call the button's function, but pass it the contents
	-- of the dialog!
	local function callExternalFunction(event)
		-- Disable button, it has been clicked! (don't want double clicks!)
		if (event.target.inProgress) then
			return false
		else
			event.target.inProgress = true
			-- Disable button for a 1/2 second to avoid a double-tap
			timer.performWithDelay(500, function() event.target.inProgress=false; end)
		end

		-- Get button action from the params
		-- Default success is close window,
		-- default failure is do nothing.
		local action, onSuccess, onFailure

		local dialogParams = window.params

		if (dialogParams.functions) then
			if (type(dialogParams.functions[params.functionName]) == "table") then
				action = dialogParams.functions[params.functionName].action
				onSuccess = dialogParams.functions[params.functionName].success
				onFailure = dialogParams.functions[params.functionName].failure
			else
				action = dialogParams.functions[params.functionName]
				onSuccess = false
				onFailure = false
			end
		else
			action = false
		end

		local r = S:getFieldValues(windowName)
		if (action and type(action) == "function") then
			if (action(r)) then
				if (onSuccess) then
					print ("dialog button: onSuccess function called: ")
					onSuccess(windowName)
				end
			else
				if (onFailure) then
					print ("dialog button: onFailure function called")
					onFailure(windowName)
				end
			end
			return true
		end
	end

	local button = widget.newButton{
		id = params.id,
		width = params.width,
		height = params.height,
		label = params.label,
		onRelease = callExternalFunction,
	}
	button:setReferencePoint(display.TopLeftReferencePoint)
	if (params.xAlign == "right") then
		button:setReferencePoint(display.TopRightReferencePoint)
	elseif (params.xAlign == "center") then
		button:setReferencePoint(display.TopCenterReferencePoint)
	end

	return button
end


function S:replaceButton(windowName, id, params, subs)
	local windowName = windowName or storyboard.getCurrentSceneName()
	if (self.window[windowName] and self.window[windowName].elements) then
		local p = self.window[windowName].elements.buttons[id].params
		p = funx.tableMerge(p, params)
		local obj = self.window[windowName].elements.buttons[id].button
		if (obj) then
			-- Get the parent of the object
			local g = obj.parent
			local x = obj.x
			local y = obj.y

			-- remove existing object
			obj:removeSelf()
			obj = nil
			-- Create new object
			subs = subs or {}
			p.text = funx.substitutions (p.label, subs)
			self.window[windowName].elements.buttons[id].params = p
			local button = S:makeButton(windowName, p)
			self.window[windowName].elements.buttons[id].button = button
			g:insert(button)
			button:setReferencePoint(display.TopLeftReferencePoint)
			if (p.xAlign == "right") then
				button:setReferencePoint(display.TopRightReferencePoint)
			elseif (p.xAlign == "center") then
				button:setReferencePoint(display.TopCenterReferencePoint)
			end
			button.x = x
			button.y = y
		end
	end
end



---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- NEW()
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S.new(params)

	params.name = params.name or "dialog"
	params.name = funx.trim(params.name)
	local scene = storyboard.newScene(params.name)

	-- the name of this dialog
	local windowName = params.name

	-- table to store info about the dialog, attached to the dialog module object itself
	local window
	if (not S.window[windowName]) then
		window = {
			params = params,
			status = {},
			results = {},
			dialogDefinition = {},
		}
		S.window[windowName] = window
	else
		window = S.window[windowName]
	end

	-------------------------------------------------
	-- SETUP
	-------------------------------------------------

	local settings = S.settings
	local textstyles = S.textstyles

	-- Rebuild screenH/W stuff in case it changed
	rebuildDisplaySettings()

	--unused
	--local topStatusBarContentHeight = funx.getStatusBarHeight()




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

	local function makeTextInputField(g, f, label, desc, style, x,y, margins, innermargins, fieldX, w,h, value, isSecure, inputType, fieldType, confirms, sourceField, dialogDefinition)


				---------------------------------------------------------------
				-- TextField Listener
				local function fieldHandler( event )
					if ( "began" == event.phase ) then
							-- This is the "keyboard has appeared" event
							-- print ( "Event = began" )

					elseif ( "ended" == event.phase ) then
							-- This event is called when the user stops editing a field:
							-- for example, when they touch a different field or keyboard focus goes away
							-- print ( "Text entered = " .. tostring( event.target.text ) )

							-- If this is a confirmation field, e.g. for a password,
							-- check it against the main field to be sure it is the same.
							-- If not, tell user
							if (confirms) then
								if (event.target.text ~= sourceField.text) then
									funx.tellUser(settings.dialog.msgConfirmFieldDoesNotMatch)
									event.target.text = ""
								end
							end


					end

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

		-- Width might be in percent
		local maxWidth = g.width - fieldX - innermargins[3]
		local fieldWidth = funx.applyPercent(w, g.width - (innermargins[1] + innermargins[3]) )
		local fieldWidth = math.min(fieldWidth,maxWidth)

		-- Make a box to show where the textfield is.
		-- If the dialog slides in, this is good because the text field could be show AFTER
		-- the dialog is drawn, and it will appear as if the fields were there all along.
		local fieldFrame = display.newRect(g, 0,0, fieldWidth, h)
		fieldFrame:setReferencePoint(display.TopLeftReferencePoint)
		fieldFrame.x = fieldX
		fieldFrame.y = y

		-- Stroke Width — double it assuming the inner part is hidden by the text field
		fieldFrame.strokeWidth  = 2*(f.strokeWidth or (settings.dialog.fieldFrameStrokeWidth or 1))
		-- Stroke Color
		local color =  funx.stringToColorTable (f.strokeColor or (settings.dialog.fieldFrameStrokeColor or "0,0,0,100%"))
		fieldFrame:setStrokeColor(color[1], color[2], color[3], color[4])
		-- Background color
		local color =  funx.stringToColorTable (f.background or (settings.dialog.fieldFrameBackground or "0,0,0,100%"))
		fieldFrame:setFillColor(color[1], color[2], color[3], color[4])


		-- convert y to screen y, but to center of object, not Top Left
		-- If the 'g' is OFF THE SCREEN, because it hasn't been move on yet,
		-- you'll find this won't work! If we position the fields BEFORE moving the
		-- dialog on screen, say because we are sliding in from the side, then positioning
		-- won't work!

		local xScreen, yScreen = fieldX + margins[1], y + margins[2]

		if (fieldType == "textbox") then
			-- Create the native textbox
			textField = native.newTextBox( 0, 0, fieldWidth, h )
			textField:setReturnKey('default')
			textField.isEditable = true
			textField:setReferencePoint(display.TopLeftReferencePoint)
			textField.x = xScreen
			textField.y = yScreen
			textField.font = native.newFont( font, fontsize )

			local color =  funx.stringToColorTable (f.textColor or (settings.dialog.fieldTextColor or "0,0,0,100%"))
			textField:setTextColor(color[1], color[2], color[3], color[4])
			value = value or ""
			textField.text = value
			textField.isConfirmation = confirms	-- ID of the field it confirms or nil

			textField:addEventListener( "userInput", fieldHandler )

			return textField, y
		else
			-- Text Field
			-- Create the native textfield
			textField = native.newTextField( 0, 0, fieldWidth, fontsize * 2 )
			textField:setReturnKey('next')
			textField:setReferencePoint(display.TopLeftReferencePoint)
			textField.x = xScreen
			textField.y = yScreen
			textField.inputType = inputType or "default"
			textField.font = native.newFont( font, fontsize )
			local color =  funx.stringToColorTable (f.textColor or (settings.dialog.fieldTextColor or "0,0,0,100%"))
			textField:setTextColor(color[1], color[2], color[3], color[4])
			value = value or ""
			textField.text = value
			textField.isSecure = isSecure
			textField.isConfirmation = confirms	-- ID of the field it confirms or nil

			textField:addEventListener( "userInput", fieldHandler )

			return textField, y
		end

	end


	-- Be sure to positiong 'g' BEFORE calling, since the native fields will be positioned in relation to it,
	-- and they won't move!

	local function makeDialogElements(g, windowName, dialogDefinition, backgroundWidth,backgroundHeight, x,y, conditions )

		local elements = { buttons = {}, textblocks = {}, fields = {}, objects = {}, all = {} }
		conditions = conditions or {}
		-- margins are percent of WIDTH of enclosing object (g): L,T,R,B
		local margins = {}
		for i,v in pairs(funx.split(dialogDefinition.dialogWindowMargins or settings.dialog.dialogWindowMargins)) do
			margins[#margins+1] = funx.applyPercent(v, screenW)
		end
		local innermargins = {}
		for i,v in pairs(funx.split(dialogDefinition.dialogInnerMargins or settings.dialog.dialogInnerMargins)) do
			innermargins[#innermargins+1] = funx.applyPercent(v, backgroundWidth)
		end

		-- Positioning Rect
		local r = display.newRect(g, 0, 0, 0,0 )
		r:setReferencePoint(display.TopLeftReferencePoint)
		r.x = 0
		r.y = 0
		r:setFillColor(0,0,0,100)

		local linespace = funx.applyPercent(dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight, screenH)
		local spaceafter = funx.applyPercent(dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter, screenH)
		local buttonSpaceAfter = funx.applyPercent(dialogDefinition.buttonSpaceAfter or settings.dialog.buttonSpaceAfter, screenH)

		-- X to left margin
		x = innermargins[1]

		-- fieldX is the x position of a text field from the left inner margin.
		-- Note, can be percent of background width, not screen width
		local fieldX = innermargins[1] + funx.applyPercent(dialogDefinition.dialogTextInputFieldXOffset or settings.dialog.dialogTextInputFieldXOffset, backgroundWidth - (innermargins[1]+innermargins[3]) )

		local k = 1
		local prevY = y
		for i,f in pairs(dialogDefinition.elements) do

			if (f.y == "same") then
				y = prevY
			end

			prevY = y

			-- show/hide element based on condition
			local showElement = true
			if (f.condition and not conditions[f.condition]) then
				showElement = false
			end
			local thisElement

			f.id = f.id or i
			if (f.isButton) then
				--y = makeButton(g, windowName, x,y, innermargins, f)
				--y = y + buttonSpaceAfter

				-- get the width
				f.width = funx.applyPercent(f.width, backgroundWidth - (innermargins[1] + innermargins[3]) )
				elements.buttons[f.id] = {}
				elements.buttons[f.id].params = f
				local button = S:makeButton(windowName, f)
				elements.buttons[f.id].button = button
				g:insert(button)
				-- Position the block
				button:setReferencePoint(display.TopLeftReferencePoint)
				if (f.xAlign == "right") then
					button:setReferencePoint(display.TopRightReferencePoint)
					x = backgroundWidth - innermargins[3]
				elseif (f.xAlign == "center") then
					button:setReferencePoint(display.TopCenterReferencePoint)
					x = backgroundWidth/2
				end
				button.x = x
				button.y = y
				y = y + button.height + buttonSpaceAfter
				button:toFront()

				thisElement = button


			elseif (f.isText) then
				-- Make a text block
				-- Save the params in case we need to rebuild it
				f.width = backgroundWidth
				elements.textblocks[f.id] = {}
				elements.textblocks[f.id].params = f
				elements.textblocks[f.id].textblock = S:makeTextBlock(windowName, f)
				g:insert(elements.textblocks[f.id].textblock)
				-- Position the block
				x = innermargins[1]
				elements.textblocks[f.id].textblock.x = x
				elements.textblocks[f.id].textblock.y = y + elements.textblocks[f.id].textblock.yAdjustment
				y = y + elements.textblocks[f.id].textblock.height + spaceafter
				thisElement = elements.textblocks[f.id].textblock

			elseif (f.isObject) then
				x = innermargins[1]

				local hh = (funx.applyPercent(f.height, screenH) or 0)/2
				y = y + hh
				local x2 = backgroundWidth - innermargins[3]
				local color =  funx.stringToColorTable (f.color or "0,0,0,100%")
				if (f.isLine) then
					thisElement = display.newLine( g, x,y, x2,y )
					thisElement:setColor(color[1], color[2], color[3], color[4])
					thisElement.width = f.width or 1
				end
				elements.objects[f.id] = thisElement
				y = y + hh
			else
				-- Make a text input field
				local style = f.style or "dialogDescription"
				x = innermargins[1]

				thisElement, y = makeTextInputField(g, f, f.label, f.desc, f.style, x,y, margins, innermargins, fieldX, f.width, f.height, f.value, f.isSecure, f.inputType, f.fieldType, f.confirms, elements.fields[f.confirms], dialogDefinition)
				k = k + 1
				y = y + linespace + spaceafter
				elements.fields[f.id] = thisElement

			end

			-- If the element is hidden, then either the element is being swapped
			-- for another, and the y position should not change, OR
			-- the structure should indicate the y-position????

			thisElement.isVisible = showElement

			thisElement.showElement = showElement
			thisElement.condition = f.condition

			if (f.y == "same") then
				thisElement.y = prevY
			elseif (f.y) then
				y = funx.applyPercent(f.y, backgroundHeight)
			end

			elements.all[f.id] = thisElement

		end -- for

		return elements
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



	--- Create the settings elements including background
	-- This includes the title, background, but not text blocks or fields or buttons.

	local function buildBackgroundElements(w,h, dialogDefinition)
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
			innermargins[#innermargins+1] = funx.applyPercent(v, g.width)
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

		-- Add a transparent layer to dim what is behind the dialog
		local dimmer = display.newRect(group, 0,0,screenW,screenH)
		local color = funx.stringToColorTable (settings.dialog.dimmerColor or "0,0,0,50%" )
		dimmer:setFillColor(color[1], color[2], color[3], color[4])


		local bkgd = display.newGroup()
		group:insert(bkgd)
		group.bkgd = bkgd

		-- The structure of the dialog is a JSON file in the system folder
		local filename
		if (windowName) then
			filename = "dialog.structure." .. funx.trim(windowName) .. ".json"
		else
			filename = "dialog.structure.default.json"
		end

		-- Get and store the dialog definition
		local dialogDefinition = funx.loadTable(filename, system.ResourceDirectory)
		if (dialogDefinition) then
			S.window[windowName].dialogDefinition = dialogDefinition

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

			local xOffset = 0
			local padding = 20

			bkgd.rect = r

			-- Submit button - same as "OK"
			if (settings.dialog.showSubmitButton) then
				local submitButton = widget.newButton{
					id = windowName,
					defaultFile = settings.dialog.dialogCloseButton,
					overFile = settings.dialog.dialogCloseButtonOver,
					width = settings.dialog.dialogCloseButtonWidth,
					height = settings.dialog.dialogCloseButtonHeight,
					onRelease = closeDialogButtonRelease,
				}
				bkgd:insert(submitButton)
				submitButton:setReferencePoint(display.TopRightReferencePoint)
				-- allow 10 px for the shadow of the popup background
				r:setReferencePoint(display.TopRightReferencePoint)

				-- top right corner
				--submitButton.x = midscreenX + (bkgdWidth/2) + (submitButton.width/2)
				--submitButton.y = midscreenY - (bkgdHeight)/2 - (submitButton.width/2)
				--submitButton.y = r.y - (submitButton.height/2)

				-- Inside top right
				submitButton.x = midscreenX + (bkgdWidth/2) - padding
				submitButton.y = r.y + padding

				xOffset = submitButton.width + padding
			end


			-- Cancel button
			if (settings.dialog.showCancelButton) then
				local cancelButton = widget.newButton{
					id = windowName,
					defaultFile = settings.dialog.dialogCancelButton,
					overFile = settings.dialog.dialogCancelButtonOver,
					width = settings.dialog.dialogCancelButtonWidth,
					height = settings.dialog.dialogCancelButtonHeight,
					onRelease = cancelDialogButtonRelease,
				}
				bkgd:insert(cancelButton)

				--[[
				-- top right on edge
				cancelButton:setReferencePoint(display.TopRightReferencePoint)
				-- allow 10 px for the shadow of the popup background
				cancelButton.x = midscreenX + (bkgdWidth/2) + (cancelButton.width/2) - cancelButton.width - padding
				--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
				cancelButton.y = r.y - (cancelButton.height/2)
				--]]

				-- top right inside
				cancelButton:setReferencePoint(display.TopRightReferencePoint)
				-- allow 10 px for the shadow of the popup background
				cancelButton.x = midscreenX + (bkgdWidth/2)  - xOffset - padding
				--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
				r:setReferencePoint(display.TopRightReferencePoint)
				cancelButton.y = r.y + padding
			end

		else
			print ("ERROR: Missing dialog structure for " .. filename)
		end -- if dialogstructure
	end



	-- Called BEFORE scene has moved onscreen:
	function scene:willEnterScene( event )
		local group = self.view
		local dialogDefinition = S.window[windowName].dialogDefinition

		-- Structure of dialog was read into 'dialogDefinition' in 'create'
		if (dialogDefinition) then

			local x = 0
			local y = 0
			local t = ""
			local tblock = {}

			local bkgd = group.bkgd
			bkgd:setReferencePoint( display.CenterReferencePoint )

			-- Background elements, such as backgrounds, title, fixed buttons
			local dialogBackgroundElements = buildBackgroundElements(bkgd.width, bkgd.height, dialogDefinition)
			group:insert(dialogBackgroundElements)
			group.dialogBackgroundElements = dialogBackgroundElements
			dialogBackgroundElements:setReferencePoint( display.CenterReferencePoint )

			dialogBackgroundElements.x = bkgd.x
			dialogBackgroundElements.y = bkgd.y

			-- a string in the form, L,T,R,B
			local margins = {}
			for i,v in pairs(funx.split(dialogDefinition.dialogWindowMargins or settings.dialog.dialogWindowMargins)) do
				margins[#margins+1] = funx.applyPercent(v, screenW)
			end
			local innermargins = {}
			for i,v in pairs(funx.split(dialogDefinition.dialogInnerMargins or settings.dialog.dialogInnerMargins)) do
				innermargins[#innermargins+1] = funx.applyPercent(v, bkgd.width)
			end

			local linespace = funx.applyPercent(dialogDefinition.dialogTextLineHeight or dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight, screenH)
			local blockspace = funx.applyPercent(dialogDefinition.dialogBlockSpacing or dialogDefinition.dialogBlockSpacing or settings.dialog.dialogBlockSpacing, screenH)
			local spaceafter = funx.applyPercent(dialogDefinition.dialogTextSpaceAfter or dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter, screenH)
			local blockwidth =  bkgd.width - innermargins[2] - innermargins[4]
			local contentY = funx.applyPercent(dialogDefinition.dialogContentY or dialogDefinition.dialogContentY or settings.dialog.dialogContentY, dialogBackgroundElements.height)

			-- INFO TEXT
			-- Info, e.g. connected to which website...
			y =  contentY

			--[[
			Conditionals in the params. These are true/false values
			 that determine what is shown and hidden.
			 Trick is to use the keys of the table for fast lookup,
			 e.g. to check for an 'isValid' flag, look for conditions['isValid'] = true
			 A conditions table might be:
			 conditions = { isValid = true, signin = false, }
			 And an element in the definition might have condition = "isValid". This would
			 show the element only if conditions.isValid == true.
			--]]

			local conditions = dialogDefinition.conditions
			-- Add in the params conditions
			--conditions = funx.tableMerge(conditions, params.conditions)
			-- Add in the dialog.window[mywindow].conditions
			local wc = S.window[windowName].conditions
			conditions = funx.tableMerge(conditions, wc)
			S.window[windowName].conditions = conditions

			-- Enter the values from params into the table

			-- If params.fields is set, use those values
			-- Otherwise, if restoreValues is set, try to get the values from a saved
			-- table in the documents folder
			local fields = {}
			if (params.fields and type(params.fields) == "table" ) then
				fields = params.fields
			elseif (params.restoreValues) then
				all_results = funx.loadTable(DIALOG_VALUES_FILE, system.DocumentsDirectory) or {}
				fields = all_results[windowName]
			end

			fields = fields or {}

			-- Add in values from params and existing data
			local subs = funx.tableMerge(params.substitutions, fields)
			for i, f in pairs(dialogDefinition.elements) do
				-- Substitutions in the label/desc fields
				f.label = funx.substitutions (f.label, subs)
				f.desc = funx.substitutions (f.desc, subs)
				f.text = funx.substitutions (f.text, subs)
				if (fields[f.id] and fields[f.id] ~= "") then
					f.value = funx.substitutions(fields[f.id], subs)
				else
					f.value = funx.substitutions(f.value, subs)
				end
			end



			x = 0
			-- Create the fields, buttons, etc.
			-- Make as a group, and assign to S.window[windowName].elements
			local dialogElementsGroup = display.newGroup()

			group:insert(dialogElementsGroup)
			group.elements = dialogElementsGroup
			dialogElementsGroup:setReferencePoint(display.TopLeftReferencePoint)
			--dialogElementsGroup.x = margins[1]
			--dialogElementsGroup.y = margins[2]

			S.window[windowName].elements = makeDialogElements(dialogElementsGroup, windowName, dialogDefinition, bkgd.width, bkgd.height, x,y, conditions )

			dialogElementsGroup:setReferencePoint(display.TopLeftReferencePoint)
			dialogElementsGroup.x = margins[1]
			dialogElementsGroup.y = margins[2]

			-- Clear flags created when the dialog is close
			S.window[windowName].didExitScene = false
			S.window[windowName].destroyScene = false
			S.window[windowName].exists = true

		end	-- end if dialog definition

	end



	-- Called immediately after scene has moved onscreen:
	function scene:enterScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		-- Save the params into the scene itself b/c params
		-- is not available after this point.
		group.params = params
		-----------------------------------------------------------------------------

		-- FOLLOWING DOES NOT WORK: NATIVE OBJECTS CAN'T BE HIDDEN.
		-- WE WILL HAVE TO BUILD THEM HERE, AND THAT CAN WAIT.

		--[[
		-- Show/Hide text fields and text boxes.
		-- Do AFTER everything else has loaded, or a transition (like a slideLeft) will
		-- look weird since the native text box won't move with the screen
		local dialogDefinition = S.window[windowName].dialogDefinition
		for i,f in pairs(dialogDefinition.elements) do
			local element = S.window[windowName].elements.all[f.id]
			f.id = f.id or i
			if (f.isTextField or f.isTextBox) then
				element.isVisible = element.showElement
				print ("Show ",f.id)
			end

		end -- for


		-- THIS IS NOT YET MODIFIED FOR THIS SECTION, JUST COPIED FROM ABOVE
		-- Add in values from params and existing data
			local subs = funx.tableMerge(params.substitutions, fields)
			for i, f in pairs(dialogDefinition.elements) do
				-- Substitutions in the label/desc fields
				f.label = funx.substitutions (f.label, subs)
				f.desc = funx.substitutions (f.desc, subs)
				f.text = funx.substitutions (f.text, subs)
				if (fields[f.id] and fields[f.id] ~= "") then
					f.value = funx.substitutions(fields[f.id], subs)
				else
					f.value = funx.substitutions(f.value, subs)
				end
			end

		--]]


	end


	-- Called when scene is about to move offscreen:
	function scene:exitScene( event )
		local group = self.view
		local results = {}
		-- Get the params, saved for us by enterScene
		local params = group.params

		-- Get values of all fields
		results = S:getFieldValues(windowName)
		-- Save results to the dialog.window tables
		--S.window[windowName].results = results

		-- Save results to the module's window table, e.g. dialog.window['mydialog'].results
		-- Not saved to disk, but available if needed for error reporting, etc.
		--S.window[windowName].results = results

		-- Remove any native text fields
		if (S.window[windowName].elements.fields) then
			-- Get text field values
			for id,f in pairs(S.window[windowName].elements.fields) do
				f:removeSelf()
			end
			S.window[windowName].elements.fields = nil
		end

		-- Submit hit (i.e. "OK" button)
		if ( S.window[windowName].status.submit ) then
			-- save?
			if (params.writeValues) then
				saveValuesToDocuments(windowName, results, params.showSavedFeedback)
			end
			-- execute the success function passed in params
			if (params.onSubmitButton) then
				results.status = "ok"
				params.onSubmitButton(results)
			end
		elseif (S.window[windowName].status.cancel) then
			if (params.onCancelButton) then
				results.status = "cancelled"
				params.onCancelButton(results)
			end
		end

		-- Clear the flags
		S.window[windowName].status.submit = false
		S.window[windowName].status.cancel = false
	end


	-- Called AFTER scene has finished moving offscreen:
	function scene:didExitScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		-- Remove the fixed settings elements, since these might change and are rebuilt each time.
		group.dialogBackgroundElements:removeSelf()
		group.dialogBackgroundElements = nil

		group.elements:removeSelf()
		group.elements = nil

		S.window[windowName].didExitScene = true
		--storyboard.purgeScene(windowName)

		-----------------------------------------------------------------------------


	end


	-- Called prior to the removal of scene's "view" (display group)
	function scene:destroyScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		S.window[windowName].destroyScene = true
		S.window[windowName].exists = false

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

	if (params.isModal) then
		-- "overlayBegan" event is dispatched when an overlay scene is shown
		scene:addEventListener( "overlayBegan", scene )

		-- "overlayEnded" event is dispatched when an overlay scene is hidden/removed
		scene:addEventListener( "overlayEnded", scene )
	end

end -- new()



---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S:showWindow(windowName, values, conditions)
	local window = self.window[windowName]

	-- Must call a 'new' before calling showWindow!
	if (not window) then
		return false
	end

	-- update the params.values
	if (values) then
		S.window[windowName].params.substitutions = funx.tableMerge(S.window[windowName].params.substitutions, values)
	end

	-- update the conditions
	if (conditions) then
		S.window[windowName].params.conditions = conditions
	end

	-- If the storyboard scene doesn't exist, we need to create it.
	-- This could happen if the scene were 'destroyed', esp. if the
	-- dialog is modal.
	if (not storyboard.scenes[windowName]) then
		S.new(window.params)
	end


	if (window.params.isModal) then
		storyboard.showOverlay( windowName, window.params.options )
	else
		storyboard.gotoScene( windowName, window.params.options )
	end
end -- show()


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
function S:removeWindow(name)
	if (name) then
		--storyboard:removeScene( name )
		self.window[name] = nil
	else
		print ("ERROR: dialog:removeWindow(name), missing name.")
	end
end -- show()


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

return S