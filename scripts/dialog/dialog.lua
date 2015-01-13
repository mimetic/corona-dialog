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

WRONG: OUT OF DATE, FIX THIS:

	local name = "MyDialog"
	dialog.new(name) 	: creates a new storyboard scene which is a dialog
	dialog:show(name)	: show the dialog
	dialog:remove(name)	: remove the dialog scene and clear it from memory

	The dialog table structure:
	dialog.window = {
		params = {},	-- save the setup params including storyboard options
		windowStatus = {},	-- the windowStatus includes flags, such as writeValues
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

	Can use:
	"y" = "same"
	"buttonType" = "close" or "cancel"


--]]

require( 'scripts.dmc.dmc_kolor' )
--require ( 'scripts.patches.refPointConversions' )



local S = { window = {} };

local pathToModule = "scripts/dialog/"

local widget = require "widget"
local settingsLib = require("settings")
--local onTouch = require("onTouch")
local funx = require ("funx")

local OPAQUE = 255

local storyboard = require "storyboard"

local DIALOG_VALUES_FILE = "dialog.values.json"

-- Get dialog module default settings
S.settings = settingsLib.new(pathToModule.."dialog.settings.default.xml", system.ResourceDirectory)

local headerRectBackgroundColor = "1,1,1,1"

-------------------------------------------------
-- Load text formatting styles used by funx.lua text formatting
-- Load system and user text formatting styles used by funx.lua text formatting
-- Merge User and System styles, where user replace system
-------------------------------------------------

local systemTextStyles = funx.loadTextStyles(pathToModule.."dialog.textstyles.txt", system.ResourceDirectory) or {}
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
	S.window[windowname].windowStatus =  {
		cancel = false,
		submit = true,
	}
	if (S.window[windowname].params.isModal) then
		storyboard.hideOverlay("fade", 500)
	else
		local previous_scene_name = S.window[windowname].params.cancelToSceneName or storyboard.getPrevious()
		if (previous_scene_name) then
			storyboard.gotoScene(previous_scene_name, S.window[windowname].params.options)
		else
			-- If there is no previous, go to the blank scene!
			storyboard.gotoScene("blank", S.window[windowname].params.options)
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
	S.window[windowname].windowStatus.cancel = true
	S.window[windowname].windowStatus.submit = false
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
		if (res and showSavedFeedback) then
			funx.tellUser("Saved")
		elseif (not res) then
			funx.tellUser("SYSTEM ERROR: Could not save the results to "..DIALOG_VALUES_FILE)
		end
	end
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
		if (res and showSavedFeedback) then
			funx.tellUser("Saved")
		elseif (not res) then
			funx.tellUser("SYSTEM ERROR: Could not save the results to "..DIALOG_VALUES_FILE)
		end
	end
end


--- Get native field values
-- If no scene name is provided, the current scene is used
-- (Confirmation fields, e.g. write the password twice to be sure.)
-- If a confirmation field doesn't match, don't return the value of the source field
-- Also, don't return the confirmation field as a value
-- Pass through the "pass-through" values set when the dialog was called (not created!), in the
-- 'vars' sub-table.
-- e.g. an id value.

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
		
		-- Add in the pass-through variables
		r.vars = self.window[windowName].params.vars
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
	local margins = S.window[windowName].margins
	local innermargins = S.window[windowName].innermargins

	-- Write the description
	local width
	if (window.dialogDefinition.fieldDescWidth or self.settings.dialog.fieldDescWidth) then
		-- Note, width can be percent of background (g object) width, not screen width
		width = funx.applyPercent(window.dialogDefinition.fieldDescWidth or self.settings.dialog.fieldDescWidth, params.width)
	else
		width = params.width - innermargins.left - innermargins.right
	end

	local textblock = ""
	local text = params.text or ""
	text = "<p class=\"" .. (params.style or "dialogDescription") .. "\">"..text.."</p>"
	if (text ~= "") then
		local p = {
			text = text,
			font = window.dialogDefinition.dialogDescFont or self.settings.dialog.dialogDescFont,
			size = window.dialogDefinition.dialogDescFontSize or self.settings.dialog.dialogDescFontSize,
			width = width,
			textstyles = self.textstyles,
			defaultStyle = params.style or "dialogDescription",
			cacheDir = "",
			isHTML = false,
		}
		textblock = funx.autoWrappedText( p )
		funx.anchor(textblock, "TopLeft")
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

	-- innermargins: T,L,B,R

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

	local onRelease = callExternalFunction
	local id = params.id

	if (params.buttonType == "cancel") then
		onRelease = cancelDialogButtonRelease
		id = windowName
	elseif (params.buttonType == "close") then
		onRelease = closeDialogButtonRelease
		id = windowName
	end

	--print ("params.label", params.label)
	local defaultColor = funx.split(params.labelDefaultColor) or funx.stringToColorTable(self.settings.dialog.dialogButtonLabelFontColor)
	local defaultOverColor = funx.split(params.labelOverColor) or funx.stringToColorTable(self.settings.dialog.dialogButtonLabelFontOverColor)
	
	local button
	
	if (params.isSliceButton) then

		local sheetInfo = require("scripts.dialog.images.buttonDefault9Slice")
		local buttonSheet = graphics.newImageSheet( "scripts/dialog/images/buttonDefault9Slice.png", sheetInfo:getSheet() )

		button = widget.newButton{
			id = id,
			width = params.width,
			height = params.height,
			label = params.label,
			onRelease = onRelease,
			labelColor = { default=defaultColor, over=defaultOverColor },
			labelYOffset = params.labelYOffset or -5,
		
			sheet = buttonSheet,
			topLeftFrame = sheetInfo.frameIndex.buttonDefault_topleft,
			topMiddleFrame = sheetInfo.frameIndex.buttonDefault_top,
			topRightFrame = sheetInfo.frameIndex.buttonDefault_topright,
			middleLeftFrame = sheetInfo.frameIndex.buttonDefault_left,
			middleFrame = sheetInfo.frameIndex.buttonDefault_mid,
			middleRightFrame = sheetInfo.frameIndex.buttonDefault_right,
			bottomLeftFrame = sheetInfo.frameIndex.buttonDefault_bottomleft,
			bottomMiddleFrame = sheetInfo.frameIndex.buttonDefault_bottom,
			bottomRightFrame = sheetInfo.frameIndex.buttonDefault_bottomright,
		
			topLeftOverFrame = sheetInfo.frameIndex.buttonSelected_topleft,
			topMiddleOverFrame = sheetInfo.frameIndex.buttonSelected_top,
			topRightOverFrame = sheetInfo.frameIndex.buttonSelected_topright,
			middleLeftOverFrame = sheetInfo.frameIndex.buttonSelected_left,
			middleOverFrame = sheetInfo.frameIndex.buttonSelected_mid,
			middleRightOverFrame = sheetInfo.frameIndex.buttonSelected_right,
			bottomLeftOverFrame = sheetInfo.frameIndex.buttonSelected_bottomleft,
			bottomMiddleOverFrame = sheetInfo.frameIndex.buttonSelected_bottom,
			bottomRightOverFrame = sheetInfo.frameIndex.buttonSelected_bottomright,		
		}
			
	else
		button = widget.newButton{
			id = id,
			width = params.width,
			height = params.height,
			label = params.label,
			onRelease = onRelease,
			labelColor = { default=defaultColor, over=defaultOverColor },
		}
	
	end
	
	
	funx.anchor(button, "TopLeft")
	if (params.xAlign == "right") then
		funx.anchorZero(button, "TopRight")
	elseif (params.xAlign == "center") then
		funx.anchor(button, "TopCenter")
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
			funx.anchor(button, "TopLeft")
			if (p.xAlign == "right") then
				funx.anchor(button, "TopRight")
			elseif (p.xAlign == "center") then
				funx.anchor(button, "TopCenter")
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
	-- Blank scene is a blank scene we can use to leave a dialog when there
	-- is no scene to go back to, i.e. when dialog is not called from another scene.
	local blankscene = storyboard.newScene("blank")
	
	-- Does a scene with this name exist? If so, DUMP IT!
	-- It is likely we'll build scenes (e.g. "reset") with the same name.
	if storyboard.getScene(params.name) then
		print ("WARNING: dialog.new: A dialog named ".. params.name .. " exists. I'm deleting it before creating a new one.")
		storyboard.removeScene(params.name)
	end
	
	local scene = storyboard.newScene(params.name)

	-- the name of this dialog
	local windowName = params.name

	-- table to store info about the dialog, attached to the dialog module object itself
	local window
	if (not S.window[windowName]) then
		window = {
			params = params,
			windowStatus = {},
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

	local function makeTextInputField(g, f, label, desc, style, backgroundWidth, backgroundHeight, x,y, margins, innermargins, fieldX, w,h, value, isSecure, inputType, fieldType, confirms, sourceField, dialogDefinition)


				---------------------------------------------------------------
				-- TextField Listener
				local function fieldHandler( event )

					-- function for ending a field edit
					local function doEndPhase()
						-- This event is called when the user stops editing a field:
						-- for example, when they touch a different field or keyboard focus goes away
						
						if (event.target.doneButton) then
							event.target.doneButton:removeSelf()
							event.target.doneButton = nil
						end
						
						if (display.currentStage.y ~= 0) then 
							transition.to (display.currentStage, { time = 250, y = 0 })
						end


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
					
					
					if ( "began" == event.phase ) then
							-- This is the "keyboard has appeared" event
							-- print ( "Event = began" )
							
							-- No way to get this just right, so we wing it.
							-- iOS 8 now has suggestions and stuff above keyboard.
							-- Let's assume 3/5 of screen height, so open area is 2/5
							local keyboardTopY = 2 * display.contentHeight/5
							
							-- Show a "Done" button for text boxes.
							if (event.target.fieldType == "textbox") then

								local doneButton

									local function donePress(e)
										e.target:removeSelf()
										-- Hide keyboard
										native.setKeyboardFocus(nil)
										doEndPhase()
									end

								local defaultColor = {0,250,0}
								local defaultOverColor = {0,180,250,250}

								doneButton = widget.newButton{
									onRelease = donePress,

									shape="roundedRect",
									label = settings.dialog.textboxDoneLabel,
									fontSize = settings.dialog.textboxDoneFontSize,
									font = settings.dialog.textboxDoneLabelFont,
									emboss = settings.dialog.textboxDoneEmboss,
									width = settings.dialog.textboxDoneWidth,
									height = settings.dialog.textboxDoneHeight,
									x = event.target.x + event.target.width - (settings.dialog.textboxDoneWidth/2),
									y = event.target.y - settings.dialog.textboxDoneHeight,
									cornerRadius = settings.dialog.textboxDoneCornerRadius,
									labelColor = { default=funx.stringToColorTable(settings.dialog.textboxDoneLabelColor), over=funx.stringToColorTable(settings.dialog.textboxDoneLabelOverColor), },
									fillColor = { default=funx.stringToColorTable(settings.dialog.textboxDoneFillColor), over=funx.stringToColorTable(settings.dialog.textboxDoneFillColor) },
									strokeColor = { default=funx.stringToColorTable(settings.dialog.textboxDoneStrokeColor), over=funx.stringToColorTable(settings.dialog.textboxDoneStrokeColor) },
									strokeWidth = settings.dialog.textboxDoneStroke,
								}
								event.target.doneButton = doneButton
							end


							-- Note, the x,y of the text field is its top left
							if ((event.target.y + event.target.height) > keyboardTopY) then
								local screenShiftY =  ( event.target.y + event.target.height - keyboardTopY) + 10
								transition.to (display.currentStage, { time = 250, y = -screenShiftY })
							end

					elseif ( event.phase == "ended" or event.phase == "submitted" ) then
						doEndPhase()
					end

				end



		local linespace = funx.percentOfScreenHeight(dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight)
		local spaceafter = funx.percentOfScreenHeight(dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter)

		local textwidth
		if (window.dialogDefinition.fieldDescWidth or settings.dialog.fieldDescWidth) then
			-- Note, width can be percent of background (g object) width, not screen width
			textwidth = funx.applyPercent(window.dialogDefinition.fieldDescWidth or S.settings.dialog.fieldDescWidth, backgroundWidth)
		else
			textwidth = backgroundWidth - innermargins.left - innermargins.right
		end

		-- Write the description
		local descText = ""
		desc = desc or ""
		if (desc ~= "") then
			local p = {
				text = desc,
				font = dialogDefinition.dialogDescFont or settings.dialog.dialogDescFont,
				size = dialogDefinition.dialogDescFontSize or settings.dialog.dialogDescFontSize,
				width = textwidth,
				textstyles = textstyles,
				defaultStyle = style or "dialogDescription",
				cacheDir = "",
			}
			descText = funx.autoWrappedText( p )
			g:insert(descText)
			funx.anchor(descText, "TopLeft")
			descText.x = x
			descText.y = y + descText.yAdjustment
			y = y + descText.height + funx.percentOfScreenHeight(dialogDefinition.spaceAfterDesc or settings.dialog.spaceAfterDesc)
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
			funx.anchor(labelText, "TopLeft")
			labelText.x = x
			labelText.y = y + labelText.yAdjustment
		end

		-- Width might be in percent
		local maxWidth = g.width - fieldX - innermargins.right
		local fieldWidth = funx.applyPercent(w, g.width - (innermargins.left + innermargins.right) )
		local fieldWidth = math.min(fieldWidth,maxWidth)
		
		h = funx.applyPercent(h, screenH - (innermargins.top + innermargins.bottom) )
		-- Make a box to show where the textfield is.
		-- If the dialog slides in, this is good because the text field could be show AFTER
		-- the dialog is drawn, and it will appear as if the fields were there all along.
		local fieldFrame = display.newRect(g, 0,0, fieldWidth, h)
		funx.anchor(fieldFrame, "TopLeft")
		fieldFrame.x = fieldX
		fieldFrame.y = y

		-- Stroke Width — double it assuming the inner part is hidden by the text field
		fieldFrame.strokeWidth  = 2*(f.strokeWidth or (settings.dialog.fieldFrameStrokeWidth or 1))
		-- Stroke Color
		local color =  funx.stringToColorTable (f.strokeColor or (settings.dialog.fieldFrameStrokeColor or "0,0,0,100%"))
		fieldFrame:setStrokeColor(unpack(color))
		-- Background color
		local color =  funx.stringToColorTable (f.background or (settings.dialog.fieldFrameBackground or "0,0,0,100%"))
		fieldFrame:setFillColor(unpack(color))


		-- convert y to screen y, but to center of object, not Top Left
		-- If the 'g' is OFF THE SCREEN, because it hasn't been move on yet,
		-- you'll find this won't work! If we position the fields BEFORE moving the
		-- dialog on screen, say because we are sliding in from the side, then positioning
		-- won't work!

		local xScreen, yScreen = fieldX + margins.left, y + margins.top + innermargins.top

		if (fieldType == "textbox") then
			-- Create the native textbox
			local textField = native.newTextBox( 0, 0, fieldWidth, h )
			textField:setReturnKey('default')
			textField.isEditable = true
			funx.anchor(textField, "TopLeft")
			textField.x = xScreen
			textField.y = yScreen
			textField.font = native.newFont( font, fontsize )
			
			local color =  funx.stringToColorTable (f.textColor or (settings.dialog.fieldTextColor or "0,0,0,100%"))
			textField:setTextColor(unpack(color))
			value = value or ""
			textField.text = value
			textField.isConfirmation = confirms	-- ID of the field it confirms or nil

			textField:addEventListener( "userInput", fieldHandler )
			textField.fieldType = fieldType

			return textField, y
		else
			-- Text Field
			-- Create the native textfield
			local textField = native.newTextField( 0, 0, fieldWidth, fontsize * 2 )
			textField:setReturnKey('next')
			funx.anchor(textField, "TopLeft")
			textField.x = xScreen
			textField.y = yScreen
			textField.inputType = inputType or "default"
			textField.font = native.newFont( font, fontsize )
			local color =  funx.stringToColorTable (f.textColor or (settings.dialog.fieldTextColor or "0,0,0,100%"))
			textField:setTextColor(unpack(color))
			value = value or ""
			textField.text = value
			textField.isSecure = isSecure
			textField.isConfirmation = confirms	-- ID of the field it confirms or nil

			textField:addEventListener( "userInput", fieldHandler )
			textField.fieldType = fieldType

			return textField, y
		end

	end


	-- Be sure to position 'g' BEFORE calling, since the native fields will be positioned in relation to it,
	-- and they won't move!

	local function makeDialogElements(g, windowName, dialogDefinition, backgroundWidth,backgroundHeight, x,y, conditions )

		local elements = { buttons = {}, textblocks = {}, fields = {}, objects = {}, all = {} }
		conditions = conditions or {}

		local margins = S.window[windowName].margins
		local innermargins = S.window[windowName].innermargins

		-- A positioning obj for this group, to maintain the top.
		local headerRect = display.newRect(g, 0, 0, 0, 0)
		funx.anchor(headerRect, "TopLeft")
		headerRect.x = 0
		headerRect.y = 0
		local color = funx.stringToColorTable (settings.dialog.headerBackground or "255,255,255,100%" )
		headerRect:setFillColor(unpack(color))

		local linespace = funx.percentOfScreenHeight(dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight)
		local spaceafter = funx.percentOfScreenHeight(dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter)
		local buttonSpaceAfter = funx.percentOfScreenHeight(dialogDefinition.buttonSpaceAfter or settings.dialog.buttonSpaceAfter)

		-- X to left margin
		x = innermargins.left

		-- fieldX is the x position of a text field from the left inner margin.
		-- Note, can be percent of background width, not screen width
		local fieldX = innermargins.left + funx.applyPercent(dialogDefinition.dialogTextInputFieldXOffset or settings.dialog.dialogTextInputFieldXOffset, backgroundWidth - (innermargins.left+innermargins.right) )

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
				f.width = funx.applyPercent(f.width, backgroundWidth - (innermargins.left + innermargins.right) )
				elements.buttons[f.id] = {}
				elements.buttons[f.id].params = f
				local button = S:makeButton(windowName, f)
				elements.buttons[f.id].button = button
				g:insert(button)
				-- Position the block
				funx.anchor(button, "TopLeft")
				if (f.xAlign == "right") then
					funx.anchorZero(button, "TopRight")
					x = backgroundWidth - innermargins.right
				elseif (f.xAlign == "center") then
					funx.anchor(button, "TopCenter")
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
				x = innermargins.left
				elements.textblocks[f.id].textblock.x = x
				elements.textblocks[f.id].textblock.y = y + elements.textblocks[f.id].textblock.yAdjustment
				y = y + elements.textblocks[f.id].textblock.height + spaceafter
				thisElement = elements.textblocks[f.id].textblock

			elseif (f.isObject) then
				x = innermargins.left

				local hh = (funx.percentOfScreenHeight(f.height) or 0)/2
				y = y + hh
				local x2 = backgroundWidth - innermargins.right
				local color =  funx.stringToColorTable (f.color or "0,0,0,100%")
				if (f.isLine) then
					thisElement = display.newLine( g, x,y, x2,y )
					thisElement:setStrokeColor(unpack(color))
					thisElement.strokeWidth = f.strokeWidth or 1
				end
				elements.objects[f.id] = thisElement
				y = y + hh
			elseif (f.isSpace) then
				x = innermargins.left

				local hh = (funx.percentOfScreenHeight(f.height) or 0)/2
				thisElement = display.newGroup()
				y = y + hh
				elements.objects[f.id] = thisElement
			else
				-- Make a text input field
				local style = f.style or "dialogDescription"
				x = innermargins.left

				thisElement, y = makeTextInputField(g, f, f.label, f.desc, f.style, backgroundWidth, backgroundHeight, x,y, margins, innermargins, fieldX, f.width, f.height, f.value, f.isSecure, f.inputType, f.fieldType, f.confirms, elements.fields[f.confirms], dialogDefinition)
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
		funx.anchor(text, "TopLeft")
		text.x = x
		text.y = y + text.yAdjustment

		return text
	end



	--- Create the settings elements including background
	-- This includes the title, background, but not text blocks or fields or buttons.

	local function buildBackgroundElements(w,h, dialogDefinition)
		local g = display.newGroup()

		-- full-screen positioning rect
		funx.addPosRect(g)

		-- Header background, also serves as a positioning obj for this group, to maintain
		-- the top.
		local headerRect = display.newRoundedRect(g, 0, 0, w,settings.dialog.headerHeight, settings.dialog.cornerRadius )
		funx.anchor(headerRect, "TopLeft")
		headerRect.x = 0
		headerRect.y = 0
		local color = funx.stringToColorTable (settings.dialog.headerBackground or "255,255,255,100%" )
		headerRect:setFillColor(unpack(color))
		headerRect:toBack()
		-- A normal rect to unround the bottom corners
		local fixCornersRect = display.newRect(g, 0, 0, w, settings.dialog.cornerRadius )
		funx.anchor(fixCornersRect, "TopLeft")
		fixCornersRect.x = 0
		fixCornersRect.y = headerRect.height - settings.dialog.cornerRadius
		fixCornersRect:setFillColor(unpack(color))
		fixCornersRect:toBack()


		-- a string in the form, L,T,R,B
		local margins = S.window[windowName].margins
		local innermargins = S.window[windowName].innermargins


		local p = {
			text = dialogDefinition.dialogTitle or settings.dialog.dialogTitle,
			width = g.width - innermargins.left - innermargins.bottom,
			textstyles = textstyles,
			defaultStyle = "dialogTitle",
			align = "center",
			cacheDir = "",
		}
		local titleText = funx.autoWrappedText( p )
		g:insert(titleText)

		-- title
		funx.anchor(titleText, "TopLeft")
		local color =  funx.stringToColorTable (settings.dialog.dialogTitleFontColor)
		titleText.x = innermargins.left
		titleText.y = innermargins.top

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

		local bkgd = display.newGroup()
		group:insert(bkgd)
		group.bkgd = bkgd

		-- Add a transparent layer to dim what is behind the dialog
		local dimmer = display.newRect(bkgd, 0,0,screenW,screenH)
		
		local color = funx.stringToColorTable (settings.dialog.dimmerColor or "0,0,0,50%" )
		dimmer:setFillColor(unpack(color))
		funx.anchorZero(dimmer, "TopLeft")
		group._dimmer = dimmer
		
		dimmer.isHitTestable = true -- Only needed if alpha is 0
		dimmer:addEventListener("touch", function() return true end)
		dimmer:addEventListener("tap", function() return true end)
	
		-- DIMMER gives us positioning on the screen at top/left, now we can lock down
		-- bkgd location

		-- The structure of the dialog is a JSON file in the system folder
		local filename
		local path = params.path or pathToModule.."dialogs/"
		local systemDirectory = params.systemDirectory or system.ResourceDirectory

		if (windowName) then
			filename = path .. "dialog.structure." .. funx.trim(windowName) .. ".json"
		else
			filename = pathToModule.."dialog.structure.default.json"
			systemDirectory = system.ResourceDirectory
		end

		-- Get and store the dialog definition
		local dialogDefinition
		if (not funx.fileExists(filename, systemDirectory) ) then
			print ("ERROR: missing dialog structure file: ", filename)
		else
			dialogDefinition = funx.loadTable(filename, systemDirectory)
		end

		if (dialogDefinition) then
			S.window[windowName].dialogDefinition = dialogDefinition

			local margins = funx.stringToMarginsTable(dialogDefinition.dialogWindowMargins or settings.dialog.dialogWindowMargins, "10%,10%,10%,10%")
			local innermargins = funx.stringToMarginsTable(dialogDefinition.dialogInnerMargins or settings.dialog.dialogInnerMargins, "10%,10%,10%,10%")
			S.window[windowName].margins = margins
			S.window[windowName].innermargins = innermargins


			local x,y

			local bkgdWidth = screenW - margins.left - margins.right
			local bkgdHeight = screenH - margins.top - margins.bottom

			-- Background elements, such as backgrounds, title, fixed buttons
			local dialogBackgroundElements = buildBackgroundElements(bkgdWidth, bkgdHeight, dialogDefinition)
			bkgd:insert(dialogBackgroundElements)
			bkgd.dialogBackgroundElements = dialogBackgroundElements
			funx.anchor(dialogBackgroundElements, "TopLeft")

			dialogBackgroundElements.x = margins.left
			dialogBackgroundElements.y = margins.top

			local xOffset = 0
			local padding = 20


			-- CLOSE BUTTON + CANCEL BUTTON
			-- Submit button - same as "OK"
			local showButton
			if (dialogDefinition.showSubmitButton ~= nil) then
				showButton = dialogDefinition.showSubmitButton
			else
				showButton = settings.dialog.showSubmitButton
			end
			if (showButton == true ) then
				local submitButton = widget.newButton{
					id = windowName,
					defaultFile = settings.dialog.dialogCloseButton,
					overFile = settings.dialog.dialogCloseButtonOver,
					width = settings.dialog.dialogCloseButtonWidth,
					height = settings.dialog.dialogCloseButtonHeight,
					onRelease = closeDialogButtonRelease,
				}
				bkgd:insert(submitButton)
				funx.anchorZero(submitButton, "TopRight")
				-- allow 10 px for the shadow of the popup background
				--funx.anchorZero(r, "TopRight")

				-- top right corner
				--submitButton.x = midscreenX + (bkgdWidth/2) + (submitButton.width/2)
				--submitButton.y = midscreenY - (bkgdHeight)/2 - (submitButton.width/2)
				--submitButton.y = r.y - (submitButton.height/2)

				-- Inside top right
				submitButton.x = margins.left + bkgdWidth - padding
				submitButton.y = margins.top + padding

				xOffset = submitButton.width + padding
			end


			-- Cancel button
			if (dialogDefinition.showCancelButton ~= nil) then
				showButton = dialogDefinition.showCancelButton
			else
				showButton = settings.dialog.showCancelButton
			end
			if (showButton == true) then
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
				funx.anchorZero(cancelButton, "TopRight")
				-- allow 10 px for the shadow of the popup background
				cancelButton.x = midscreenX + (bkgdWidth/2) + (cancelButton.width/2) - cancelButton.width - padding
				--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
				cancelButton.y = r.y - (cancelButton.height/2)
				--]]

				-- top right inside
				funx.anchorZero(cancelButton, "TopRight")
				-- allow 10 px for the shadow of the popup background
				cancelButton.x = margins.left + bkgdWidth  - xOffset - padding
				--cancelButton.y = midscreenY - (bkgdHeight)/2 - (cancelButton.width/2)
				cancelButton.y = margins.top + padding
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

			local x,y

			local bkgd = group.bkgd

			-- a string in the form, L,T,R,B
			local margins = S.window[windowName].margins
			local innermargins = S.window[windowName].innermargins

			local bkgdWidth = screenW - margins.left - margins.right
			local bkgdHeight = screenH - margins.top - margins.bottom

			local linespace = funx.percentOfScreenHeight(dialogDefinition.dialogTextLineHeight or dialogDefinition.dialogTextLineHeight or settings.dialog.dialogTextLineHeight)
			local blockspace = funx.percentOfScreenHeight(dialogDefinition.dialogBlockSpacing or dialogDefinition.dialogBlockSpacing or settings.dialog.dialogBlockSpacing)
			local spaceafter = funx.percentOfScreenHeight(dialogDefinition.dialogTextSpaceAfter or dialogDefinition.dialogTextSpaceAfter or settings.dialog.dialogTextSpaceAfter)
			local blockwidth =  bkgdWidth - innermargins.left - innermargins.bottom

			-- Y of the first line of content below the title bar
			--local contentY = funx.percentOfScreenHeight(dialogDefinition.dialogContentY or dialogDefinition.dialogContentY or settings.dialog.dialogContentY)
			--y =  contentY
			y = settings.dialog.headerHeight

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
				local all_results = funx.loadTable(DIALOG_VALUES_FILE, system.DocumentsDirectory) or {}
				fields = all_results[windowName]
			end

			fields = fields or {}

			-- Add in values from params and existing data
			local subs = funx.tableMerge(params.substitutions, fields)
			if (dialogDefinition.elements) then
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
			else
				print ("ERROR: dialog: missing elements in the dialog definition. Perhaps the structure file is missing?")
			end

			x = 0
			-- Create the fields, buttons, etc.
			-- Make as a group, and assign to S.window[windowName].elements
			local dialogElementsGroup = display.newGroup()

			group:insert(dialogElementsGroup)
			group.elements = dialogElementsGroup
			funx.anchor(dialogElementsGroup, "TopLeft")
			--dialogElementsGroup.x = margins.left
			--dialogElementsGroup.y = margins.top

			S.window[windowName].elements = makeDialogElements(dialogElementsGroup, windowName, dialogDefinition, bkgdWidth, bkgdHeight, x,y, conditions )

			funx.anchor(dialogElementsGroup, "TopLeft")
			dialogElementsGroup.x = margins.left
			dialogElementsGroup.y = margins.top + innermargins.top

			-- Clear flags created when the dialog is close
			S.window[windowName].didExitScene = false
			S.window[windowName].destroyScene = false
			S.window[windowName].exists = true

			-- resize the background rect of the dialog to fit
			bkgdHeight = dialogElementsGroup.contentHeight + innermargins.top +  innermargins.bottom
			
			-- ------------------------
			-- BACKGROUND Rounded Rect for whole dialog
			local backgroundColor = dialogDefinition.dialogBackgroundColor or settings.dialog.dialogBackgroundColor
			local rrectCorners = settings.dialog.cornerRadius

			local r = display.newRoundedRect(bkgd, margins.left, margins.top, bkgdWidth, bkgdHeight, rrectCorners)
			local color = funx.stringToColorTable (backgroundColor)
			r:setFillColor(unpack(color))
			bkgd.background = r
			funx.anchor(r, "TopLeft")
			r:toBack()
			
			group._dimmer:toBack()



		end	-- end if dialog definition

	end


	-- Used for modal dialogs
	function scene:overlayBegan( event )

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
		if ( S.window[windowName].windowStatus.submit ) then
			-- save?
			if (params.writeValues) then
				saveValuesToDocuments(windowName, results, params.showSavedFeedback)
			end
			-- execute the success function passed in params
			if (params.onSubmitButton) then
				results.windowStatus = "ok"
				params.onSubmitButton(results)
			end
		elseif (S.window[windowName].windowStatus.cancel) then
			if (params.onCancelButton) then
				results.windowStatus = "cancelled"
				params.onCancelButton(results)
			end
		end

		-- Clear the flags
		S.window[windowName].windowStatus.submit = false
		S.window[windowName].windowStatus.cancel = false
	end


	-- Called AFTER scene has finished moving offscreen:
	function scene:didExitScene( event )
		local group = self.view

		-----------------------------------------------------------------------------

		-- Remove the fixed settings elements, since these might change and are rebuilt each time.
		--group.dialogBackgroundElements:removeSelf()
		--group.dialogBackgroundElements = nil
--print ("scene:didExitScene")
		group.elements:removeSelf()
		group.elements = nil

		S.window[windowName].didExitScene = true
		--storyboard.purgeScene(windowName)

		-----------------------------------------------------------------------------


	end



	-- Used for modal dialogs
	function scene:overlayEnded( event )

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
-- @vars 	table of pass-through vars, e.g ID of an item this dialog is about.
function S:showWindow(windowName, values, conditions, vars)
	local window = self.window[windowName]

	-- Must call a 'new' before calling showWindow!
	if (not window) then
		return false
	end

	-- update the params.values
	if (values) then
		window.params.substitutions = funx.tableMerge(window.params.substitutions, values)
	end

	-- update the conditions
	if (conditions) then
		window.params.conditions = conditions
	end

	-- update the conditions
	if (vars) then
		window.params.vars = vars
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
--print ("dialog:removeWindow(" .. name .. ")")
		storyboard.removeScene( name )
		self.window[name] = nil
	else
		print ("ERROR: dialog:removeWindow(name), missing name.")
	end
end -- show()


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------



return S