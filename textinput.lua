-- textinput.lua
--
-- Version 0.2
--
-- Copyright (C) 2011 David I. Gross. All Rights Reserved.
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
-- ===================
-- TEXT INPUT FUNCTIONS
-- ===================

--[[

Popup a dialog box with a text input box, with buttons for OK and Cancel.

tlib = require ("textinput")

local params = {
	entryType = "textbox", -- textbox or textfield
	text = "my message", 	-- ???
	onComplete = myCallbackFunction, 
	onCancel = myCallbackFunction, 
	x = "50%", -- can be percent of screen
	y = "50%", -- can be percent of screen
	width = 300, -- can be percent of screen
	height = "30%", -- can be percent of screen
	margin = { top=10, bottom=10, right=20, left=20 },
	default = myButtonImage, -- an background image for the a button
	over = myButtonOverImage, -- an background image for the a button over state
	entryHeight = "25%", -- can be percent of screen
	entryWidth = 280, -- can be percent of screen
	dim = "80%", -- can be 0.0 - 1.0, or a percentage
	title = "My Title", -- title of dialog box
	backgroundimage = myBackgroundImage, -- background image for the dialog box
	background = "200,200,200,50%", -- OR a color background for the dialog box
	rounded = true, -- set to true if no background image and you want a rounded rect
	cornerRadius = 10, -- corner radius for a rounded rect background
}
mytextinput = tlib.new(params)


]]

local TLIB = {}

---------------
-- Popup a query for a one-line text entry, such as a name or code
-- It can show a message.
function TLIB.new(params)


	----------------------------------------------------------------------
	-- screen values, e.g. mid-screen
	local screenW, screenH = display.contentWidth, display.contentHeight
	local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
	local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
		-- Useful constant:
	local midscreenX = screenW*(0.5)
	local midscreenY = screenH*(0.5)



	local T = {}

	local funx = require "funx"
	--local ui = require "ui"
	local widget = require "widget-v1"
	--local widget = require "widget"

	local defaultSystemFontSize = 16

	local msg = params.text
	local entryType = params.entryType or "textbox"

	local padding = 20	-- default padding between elements

	local x = funx.percentOfScreenWidth(params.x) or padding
	local y = funx.percentOfScreenHeight(params.y) or padding
	local w = funx.percentOfScreenWidth(params.width) or 300
	local h = funx.percentOfScreenHeight(params.height) or 200
			
	local buttonDefault = params.default or "_ui/button-ios-70.png"
	local buttonOver = params.over or "_ui/button-ios-70-over.png"

	params.entryHeight = funx.percentOfScreenHeight(params.entryHeight) or defaultSystemFontSize

	params.margin = params.margin or {
										top=padding,
										left=padding,
										bottom=padding,
										right=padding,
									}
									
	params.margin.top = funx.percentOfScreenHeight(params.margin.top)
	params.margin.left = funx.percentOfScreenWidth(params.margin.left)
	params.margin.bottom = funx.percentOfScreenHeight(params.margin.bottom)
	params.margin.right = funx.percentOfScreenHeight(params.margin.right)

	T.onComplete = params.onComplete or nil
	T.onCancel = params.onCancel or nil

	local c = "0,0,0," .. (params.dim or 0.75)
	-- true means lock the background against touches
	T.dim = funx.dimScreen(nil, c, nil, true)



	-- forward declaration for the text field
	local field

	-- forward reference (needed for Lua closure) for the input textfield (or textbox)
	local field, numberField

	----------
	-- Remove the dialog box
	local function removeBox()
		-- Hide the keyboard
		native.setKeyboardFocus( nil )
		T.bkgd:removeSelf()
		T.bkgd = nil
		T.field:removeSelf()
		T.field = nil
		funx.undimScreen(T.dim)
		T.dim = nil
	end

	-----------
	-- submit
	local function submit()
		--funx.tellUser("SUBMIT")
		--print ("Text is", field.text)
		--if (field.text) then
		--	funx.tellUser(field.text)
		--end

		if (T.onComplete) then
			T.onComplete(T.field.text)
		end
		T.text = T.field.text
		removeBox()
	end

	local function cancel()
		--funx.tellUser ("CANCEL")
		T.field.text = ""
		if (T.onCancel) then
			T.onCancel()
		end
		removeBox()
	end


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
							--funx.tellUser ( "Text entered = " .. tostring( getObj().text ) )

					elseif ( "submitted" == event.phase ) then
							-- This event occurs when the user presses the "return" key
							-- (if available) on the onscreen keyboard
							--T.field.text = tostring( getObj().text )

							-- Hide keyboard
							native.setKeyboardFocus( nil )
							submit()
					end
			end

	end


	---------------------------------------------------------------
	-- TextBox Listener
	local function textBoxListener(event)
		if (event.phase == "ended") then
			native.setKeyboardFocus( nil )
		elseif (event.phase == "editing" or event.phase == "began") then
			native.setKeyboardFocus( event.target )
		end
		--funx.tellUser("Event" .. event.phase)
	end


	---------------------------------------------------------------
	-- Display a background for the dialog box
	local function dialogBackground(params)
		local bkgd = display.newGroup()

		params.title = params.title or ""
		-- Show dialog title
		title = display.newText(funx.trim(params.title), 0, 0, native.systemFontBold, defaultSystemFontSize )
		local c = funx.stringToColorTable(params.fontcolor or {0,0,0,255} )
		title:setFillColor( c[1],c[2],c[3],c[4] )

		-- submit and cancel buttons
		local submit = widget.newButton{
			label = "OK",
			labelColor = { default={255}, over={255} },
			font = native.systemFontBold,
			fontsize = defaultSystemFontSize,
			xOffset=2, yOffset=-1,
			width=70, height=30,
			left=10, top=28,
			default = buttonDefault,
			over = buttonOver,
			onRelease = submit,
		}

		local cancel = widget.newButton{
			label = "Cancel",
			labelColor = { default={255}, over={255} },
			font = native.systemFontBold,
			fontsize = defaultSystemFontSize,
			xOffset=2, yOffset=-1,
			width=70, height=30,
			left=10, top=28,
			default = buttonDefault,
			over = buttonOver,
			onRelease = cancel,
		}

		-- background
		if (params.backgroundimage) then
			local img = display.newImage(bkgd, params.backgroundimage)
			bkgd.background = r
		else
			local minHeight = (title.height + math.max(submit.contentHeight, cancel.contentHeight) + params.margin.top + params.margin.bottom + (2*padding) )
			
			if (h < minHeight) then
				h = minHeight
			end

			local r
			if (params.rounded) then
				r = display.newRoundedRect(bkgd, 0,0,w,h, params.cornerRadius or 6)
			else
				r = display.newRect(bkgd, 0,0,w,h)
			end
			local c = funx.stringToColorTable(params.background or {255,255,255,255} )
			r:setFillColor( c[1],c[2],c[3],c[4] )
			bkgd.background = r
		end

		if (params.title ~= "" ) then
			bkgd:insert(title)
			title.x = bkgd.width/2
			title.y = params.margin.top
			bkgd.title = title
		end

		-- Place buttons
		bkgd:insert(submit)
		bkgd.submit = submit

		bkgd:insert(cancel)
		bkgd.cancel = cancel

		submit.x = bkgd.contentWidth/4
		submit.y = bkgd.contentHeight - params.margin.bottom - (cancel.contentHeight/2)

		cancel.x = 3*(bkgd.contentWidth/4)
		cancel.y = bkgd.contentHeight - params.margin.bottom - (cancel.contentHeight/2)

		bkgd.x = x
		bkgd.y = y

		return bkgd
	end


	---------------------------------------------------------------
	-- Create the text dialog box
	function dialogTextField(params)

		local fieldTop =  params.margin.top + T.bkgd.title.contentHeight

		local field = native.newTextField( x+params.margin.left, y+fieldTop, params.entryWidth, params.entryHeight )
		--field:addEventListener('userInput', textFieldHandler( function() return field end ) )
		--field = native.newTextField( x+params.margin.left, y+fieldTop, params.entryWidth, params.entryHeight, textFieldHandler( function() return field end ) )


		return field
	end


	---------------------------------------------------------------
	-- Create the text dialog box
	function dialogTextBox(params)
		local margin = params.margin

		local fieldTop =  params.margin.top + T.bkgd.title.contentHeight

		local field = native.newTextBox( x+params.margin.left, y+fieldTop, params.entryWidth, params.entryHeight )
		field.isEditable = true
		field:addEventListener( 'userInput', textBoxListener )
		return field
	end


	---------------------------------------------------------------
	-- Create a background rect
	--local bkgd = dialogBackground(params)

	---------------------------------------------------------------
	-- Create our Text Field or Text Box
	if (entryType == "textfield") then
		-- passes the text field object

		T.bkgd = dialogBackground(params)
		
		params.entryWidth = funx.percentOfScreenWidth(params.entryWidth) or (T.bkgd.width - (params.margin.left + params.margin.right ))
		params.entryHeight = funx.percentOfScreenHeight(params.entryHeight) or defaultSystemFontSize
		T.field = dialogTextField(params)
	else
		-- TEXT BOX
		T.bkgd = dialogBackground(params)
		params.entryWidth = funx.percentOfScreenWidth(params.entryWidth) or (T.bkgd.width - (params.margin.left + params.margin.right ))
		params.entryHeight = funx.percentOfScreenHeight(params.entryHeight) or defaultSystemFontSize*3

		T.field = dialogTextBox(params)
	end
	T.field.text = ""

	return T
end -- new

return TLIB