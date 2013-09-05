-- settings_gui.lua
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

	Allow user to manage settings using dialog screens.

--]]

--module table
local M = {}

local pathToModule = "scripts/dialog/"

-- Local settings for an app, e.g. current user, etc.
M.values = {}

local storyboard = require "storyboard"
storyboard.isDebug = true

-- This creates a dialog generator function
local dialog = require ("scripts.dialog.dialog")

-- Be CAREFUL not to use names of existing lua files, e.g. settings.lua unless you mean it!!!
local settingsDialogName = "settingsDialog"
local signInDialogName = "signinDialog"
local newAccountDialogName = "createAccountDialog"



-- Should we use Modal dialogs or let them stick around?
-- Probably not if we want dialogs to be able to jump around. If we allow modal,
-- then dialogs can lose their storyboard.scenes, not a good thing.
local isModal = false
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--[[
Wordpress connection

Verify the user with WordPress

--]]

local mb_api = require ("mb_api")


--------------------------------------------
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight
local midscreenX = screenW*(0.5)
local midscreenY = screenH*(0.5)



local error_messages = {
	email_invalid = "Invalid email",
	email_exists = "Email already in use",
	username_invalid = "Username not acceptable",
	api_key_invalid = "My Mistake: Invalid API key!",
	user_creation_failed = "Account creation failed, I don't know why.",
	username_exists = "Username already in use.",
}




--- Get user information from WordPress
-- @param url			The URL of the website to contact
-- @param username		The username
-- @param password
-- @param onSuccess		Function to run on success
-- @param onFailure		Function to run on failure
-- @return

local function getUserInfo(url, username, password, onSuccess, onFailure)

		function onError(result)
			print ("getUserInfo: ERROR:")
			funx.dump(result)
		end

		function onSuccess(result)
			print ("getUserInfo: onSuccess:")
			funx.dump(result)

		end

	--------------------------------------------
	local username = results.username
	local password = results.password
	local url = "http://localhost/photobook/wordpress/"

	mb_api.getUserInfo(url, username, password, onSuccess, onError)
	return true
end


--- Update the settings window with the values
-- This is useful after signing in and update the values.
-- @return
local function updateSettingsDialog()

	if (dialog.window[settingsDialogName].exists) then
		local dialogName = "settings"
		local id = "username"
		local newText = "You are signed in as <span font='Avenir-Black'>{username}</span> (<span font='Avenir-Black'>{displayname}</span>)"
		local f = { text = newText }
		dialog:replaceTextBlock(settingsDialogName, id, f, M.values.user)

		-- Update the sign in/out button
		local f = {
			label = "Sign Out",
			functionName = "signOutUser",
		}
		local id = "signOut"
		dialog:replaceButton(settingsDialogName, id, f, M.values.user)
	end
end

--- Set the conditions table based on the current M.values table
-- @return conditions
local function setConditions(windowName)
	local conditions = {}
	conditions = {
		signout = M.values.user.authorized or false,	-- make sure it is boolean (could be nil!)
		signin = not M.values.user.authorized,
	}
	if (windowName) then
		dialog.window[windowName].conditions = conditions
	end
	--funx.tellUser("setConditions:Authorized:".. tostring(M.values.user.authorized))
	return conditions
end

--- Set the conditions table based on the current M.values table
-- @return conditions
local function updateConditions(windowName)
	local conditions = {}
	conditions = {
		signout = M.values.user.authorized or false,	-- make sure it is boolean (could be nil!)
		signin = not M.values.user.authorized,
	}
	if (windowName) then
		dialog.window[windowName].conditions = conditions
	end
	--funx.tellUser("setConditions:Authorized:".. tostring(M.values.user.authorized))
	return conditions
end


--- Update a dialog.window table to use the current 'values'
local function updateDialogParams(windowName)
	dialog.window[windowName].params.substitutions = M.values.user
end


------------------------------------------------------------------------
--- Show a dialog
-- @param windowname
-- @param values	(optional) updated key/value set used for substitutions in fields + texts
-- @param conditions	(optional) updated conditions table
-- @return

local function showDialog(windowName)
	local conditions = updateConditions(windowName)
	dialog:showWindow(windowName, M.values.user, conditions)
end





------------------------------------------------------------------------
--- SIGN IN dialog
-- @return

local function showSettingsDialog()
	showDialog(settingsDialogName)
end


--- If the user exists, update new info about the user taken from the WP website.
-- @param results
-- @return

local function signin_user(results)

	local username = results.username
	local password = results.password
	local url = "http://localhost/photobook/wordpress/"

		function onError(mb_api_result)
			funx.tellUser(mb_api_result.error)
			print ("signin_user: ERROR")
			funx.dump(mb_api_result)
			-- Set the conditionals for this dialog
			dialog.window[signInDialogName].conditions.authorized = false
			showSettingsDialog()
			return false
		end

		-- I think that Success ONLY means the network transaction worked!
		function onSuccess(mb_api_result)
			if (mb_api_result.status == "ok") then
				funx.tellUser("Sign In for '"..results.username .. "' confirmed.")
				M.values.user = funx.tableMerge(M.values.user, mb_api_result.user)
				M.values.user.authorized = true
				showSettingsDialog()
				--updateSettingsDialog()
				return true
			else
				funx.tellUser("Sign In for '"..results.username .. "' failed!")
				return false
			end

		end

	--------------------------------------------

	mb_api.getUserInfo(url, username, password, onSuccess, onError)
	return true
end


--

--- If the user exists, update new info about the user taken from the WP website.
-- @param results
-- @return

local function verify_user(results)

		function onError(mb_api_result)
			funx.tellUser(mb_api_result.error)
			print ("verify_user: ERROR")
			funx.dump(mb_api_result)
			return false
		end

		-- I think that Success ONLY means the network transaction worked!
		function onSuccess(mb_api_result)
			funx.tellUser("Sign In for '"..results.username .. "' confirmed.")
			-- Update values
			--local newvalues = { firstname = result.user.firstname, lastname = result.user.lastname, displayname = result.user.displayname }
			--dialog:addValuesToDocuments(signInDialogName, newvalues, showSavedFeedback)
			return true
		end

	--------------------------------------------
	local username = results.username
	local password = results.password
	local url = "http://localhost/photobook/wordpress/"

	mb_api.getUserInfo(url, username, password, onSuccess, onError)
	return true
end


--------------------------------------------------------------------------------
-- Shortcut functions

--- Shortcut to show sign-in dialog
local function showSignInUserDialog()
	showDialog(signInDialogName)
end

--- Shortcut to show the create-new-account dialog
local function openCreateNewAccountDialog()
	showDialog(newAccountDialogName)
end



--- Show the create new account dialog
local function confirmAccount(results)
	return verify_user(results)
end

--------------------------------------------------------------------------------
-- If the user exists, update new info about the user taken from the WP website.
-- The username, etc., might come back altered, e.g. user --> user_001
-- So we must update the values.
-- Return true -> finished with dialog, do closing function
-- Return false -> failure, keep dialog open so use can try again
local function createNewAccount(results)

		function onError(mb_api_result)
			funx.tellUser(mb_api_result.error)
			print ("createNewAccount:", error_messages[mb_api_result.error])
			return false
		end

		-- Success ONLY means the network transaction worked!
		function onSuccess(mb_api_result)
			if (mb_api_result.status == "error") then
				funx.tellUser(error_messages[mb_api_result.error])
				print ("createNewAccount:", error_messages[mb_api_result.error])
				return false
			else
				funx.tellUser("Account created.")
				print ("createNewAccount:", "Account created")
				-- Get updated values
				local newvalues = {
					username = mb_api_result.username,
					password = mb_api_result.password,
					email = mb_api_result.email,
					firstname = mb_api_result.firstname,
					lastname = mb_api_result.lastname,
					displayname = mb_api_result.displayname,
				}
				dialog:addValuesToDocuments(newAccountDialogName, newvalues, showSavedFeedback)
				-- Update the settings dialog, too!
				dialog:addValuesToDocuments(signInDialogName, newvalues, showSavedFeedback)

				-- Add values to the main 'values' table
				M.values.user = funx.tableMerge(M.values.user, newvalues)

				showSignInUserDialog()
				return true
			end
		end

	--------------------------------------------
	-- In this case, username/pass have to be an admin user
	-- who can create new accounts!!!!
	local username = "admin"
	local password = "nookie"
	local url = "http://localhost/photobook/wordpress/"

	mb_api.register_user(url, username, password, results, onSuccess, onError)
	return false
end




local function cancelled(results)
	funx.tellUser ("Cancelled")
end


------------------------------------------------------------------------
-- SIGN IN dialog
-- Create a dialog window to sign in
-- @param	dialogName	Name of the dialog window
-- @return

local function createSignInDialog(dialogName)
	local options = {
		effect = "fade",
		time = 250,
		isModal = isModal,
	}

	-- Options for the dialog builder
	local params = {
		name = dialogName,
		substitutions = M.values.user,
		restoreValues = false,	-- restore previous results from disk
		writeValues = false,	-- save the results to disk
		onSubmitButton = nil, -- set this function or have another scene check storyboard.dialogResults
		--onCancelButton = showSettingsDialog, -- set this function or have another scene check storyboard.dialogResults
		cancelToSceneName = settingsDialogName,
		showSavedFeedback = false,	-- show "saved" if save succeeds
		options = options,
		isModal = isModal,
		functions = {
			createNewAccountDialog = openCreateNewAccountDialog,
			confirmAccount = confirmAccount,
			signin = {
				action = signin_user,
				success = nil,
				failure = nil,
			},
		},
		cancelToSceneName = settingsDialogName,
	}


	-- Creates a new dialog scene
	dialog.new(params)
end







------------------------------------------------------------------------
--- Create New account dialog
-- Options for the storyboard
-- @param dialogName	Name of the dialog window
-- @return

local function createNewAccountDialog(dialogName)

	-- Success just means the network didn't fail!
	local function onSuccess(results)
		print ("createNewAccountDialog:onSuccess: ")
		funx.dump(results)
		showSignInUserDialog()
	end
	
	local function onFailure(results)
		funx.tellUser("Error: Probably a network connection error.")
	end

	local options = {
		effect = "fade",
		time = 250,
		isModal = isModal,
	}

	-- Options for the dialog builder
	local params = {
		name = dialogName,
		substitutions = M.values.user,
		restoreValues = true,	-- restore previous results from disk
		writeValues = true,	-- save the results to disk
		onSubmitButton = nil, -- set this function or have another scene check storyboard.dialogResults
		--onCancelButton = showSettingsDialog, -- set this function or have another scene check storyboard.dialogResults
		cancelToSceneName = settingsDialogName,
		showSavedFeedback = false,	-- show "saved" if save succeeds
		options = options,
		isModal = isModal,
		functions = {
			createAccount = {
				action = createNewAccount,
				success = nil,
				failure = nil,
			},
		},
	}

	------------------------------------------------------------------------
	-- Creates a new dialog scene
	dialog.new(params)
end





--- Sign Out in settings dialog
-- @return

local function signOutUserInSettings()

	currentUserName = ""
	currentUserFullName = ""

	-- Update the username text block
	local dialogName = "settings"
	M.values.user.authorized = false
	M.values.user.username = ""
	M.values.user.password= ""
	M.values.user.displayname = ""


	local conditions = {
		signout = M.values.user.authorized or false,	-- make sure it is boolean (could be nil!)
		signin = not M.values.user.authorized,
	}
	dialog:updateDialogByConditions(settingsDialogName, conditions)
end




------------------------------------------------------------------------
--- SETTINGS dialog
-- @param	callback	the function to call when user closes/cancels.
-- @return
local function createSettingsDialog(callback)

	-- Results are of the last closed dialog, not all results
	-- Merge these results into the final values that we return to the callback function.
	local function onCompletion(results)
		M.values = funx.tableMerge(M.values, results)
		--dialog:removeWindow(settingsDialogName)
		if (type(callback) == "function") then
			callback( M.values )
		end
	end


	-- Options for the storyboard
	local options = {
		effect = "fade",
		time = 250,
		isModal = isModal,
	}

	-- Set the INITIAL conditions which control what is displayed.
	-- Params should update these conditions if the window is recreated
	local conditions = {
		signout = M.values.user.authorized or false,	-- make sure it is boolean (could be nil!)
		signin = not M.values.user.authorized,
	}

	-- Options for the dialog builder
	local params = {
		name = settingsDialogName,
		substitutions = M.values.user,
		restoreValues = false,	-- restore previous results from disk
		writeValues = false,	-- save the results to disk
		onSubmitButton = onCompletion, -- set this function or have another scene check storyboard.dialogResults
		onCancelButton = onCompletion, -- set this function or have another scene check storyboard.dialogResults
		cancelToSceneName = storyboard.getCurrentSceneName(), -- cancel to the scene that called this dialog
		showSavedFeedback = false,	-- show "saved" if save succeeds
		options = options,
		isModal = isModal,
		functions = {
			createNewAccountDialog = openCreateNewAccountDialog,
			signOutUser = {
				action = signOutUserInSettings,
				success = createSettingsDialog,
				failure = nil,
			},
			signInUser = {
				action = showSignInUserDialog,
				success = nil,
				failure = nil,
			},
		},
		--conditions = conditions,
	}

	------------------------------------------------------------------------
	-- Creates a new dialog scene
	dialog.new(params)
end


local function init(values, onCompletion)
	M.values = values
	createSignInDialog(signInDialogName)
	createNewAccountDialog(newAccountDialogName)
	createSettingsDialog(onCompletion)
end


-- functions
M.init = init
M.showSettingsDialog = showSettingsDialog
M.showDialog = showDialog
return M
