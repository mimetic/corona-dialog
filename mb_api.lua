-- WORDPRESS
-- Remote access to a Wordpress installation



--[[

	Requires installation of the "JSON API" plugin in Wordpress, AND the
	installation of the "auth" controller into the "controller" folder inside it.

	The JSON API plugin is here:
	http://wordpress.org/extend/plugins/json-api/other_notes/

	The "auth.php" file is here:
	https://github.com/mattberg/wp-json-api-auth

	Here's the how-to use the "auth", but hard to figure out!
	https://github.com/mattberg/wp-json-api-auth/issues/2



	USAGE:

	local wordpress = require ("wordpress")

	wordpress.url = "http://example.com/wordpress/"  (note the ending slash!)
	-- Get the 'nonce' for a given controller and method, required to do
	-- anything. It's a form of authentication.
	-- Default is get a nonce for controller=auth, method=generate_auth_cookie
	wordpress.access(url, username, password, callbackUponSuccess)

	-- When it is done, the following will be set:
		wordpress.user.wp_user	: a table of user info
		wordpress.wp_cookie		: the authentication cookie (a string)

]]

require ("funx")

local json = require( "json" )

---------------------------


local app = { user = {} }
app.wp_nonce = {}
app.wp_cookie = {}

app.url = ""



----------------
-- Get nonce ID in the way the WordPress JSON API wants it
--[[
local function get_nonce_id(controller, method)
	controller = lower(controller);
	method = lower(method);
	return "mb_api-" .. controller .. "-" .. method
end
--]]


----------------
-- Get current user information
function app.getCurrentUserInfo()

			local function networkListener( event )
				if ( event.isError ) then
					--print( "Network error!")
					app.status = { status = "error", error = "Network error!", }
					app.onError(app.status)
				else
					local data = json.decode(event.response)
					app.result = data
					app.callback(app.result)
				end
			end

	local url = app.url
	local postdata = "cookie="..app.wp_cookie

	local params = { body = {}, }
	params.body = postdata
	network.request( url.."mb/book/get_currentuser_info", "POST", networkListener,  params)
end



----------------
-- Get an authentication cookie so we can do more
-- Requires signing in with a username/password, set elsewhere
function app.generateAuthCookie()
	--local mime = require("mime")

			local function networkListener( event )
				if ( event.isError ) then
					app.status = { status = "error", error = "Network error!", }
					app.onError(app.status)
					print( "app.generateAuthCookie: Network error!")
				else
					--print ( "generateAuthCookie RESPONSE: " .. event.response )
					local data = json.decode(event.response)
					app.status = data
					--funx.dump(data)
					if (data.status ~= "error") then
						app.wp_cookie = data.cookie
						app.nextFunctionWithCookie()
					else
						app.onError(data)
					end
				end
			end

	local url = app.url

	local username = app.username
	local password = app.password

	local postdata = "nonce="..app.wp_nonce.nonce
	local postdata = postdata.."&username="..username
	local postdata = postdata.."&password="..password
	local params = { body = {}, }

	params.body = postdata
	network.request( url.."mb/auth/generate_auth_cookie", "POST", networkListener,  params)
end




--[[

----------------
-- Get a post
-- Use either id or slug to identify the post
function app.getPost(id_method, id, callback)

			local function networkListener( event )
				if ( event.isError ) then
					print( "getPost: Network error!")
					if (callback) then
						callback( { status = "network error", err = "getPost: Network error!"} )
					end
				else
					--print ( "getPost: " .. event.response )
					local data = json.decode(event.response)
					app.result = data;
				end
				if (callback) then
					callback()
				end
			end

	local url = app.url
	--local postdata = "controller=auth&method=generate_auth_cookie"

	controller = "core_auth"
	method = "get_post"

	local postdata = "" --"controller="..controller.."&method="..method
	if (id_method == "slug") then
		postdata = postdata .. "post_slug="..id
	else
		postdata = postdata .. "post_id="..id
	end

	local params = {}
	params.body = postdata

	network.request( url.."mb/"..controller.."/"..method, "POST", networkListener,  params)
end



----------------
-- Submit a comment
-- Use either id or slug to identify the post
function app.submitComment(event)

			local function networkListener( event )
				if ( event.isError ) then
					print( "getPost: Network error!")
					callback( { status = "network error", err = "submitComment: Network error!"} )
				else
					print ( "submitComment: " .. event.response )
					local data = json.decode(event.response)
					app.result = data;
					if (callback) then
						callback(app.result)
					end
				end

			end

	local url = app.url
	--local postdata = "controller=auth&method=generate_auth_cookie"

	local controller = "respond"
	local method = "submit_comment"

	local postdata = ""
	postdata = postdata .. "&post_id=".. app.params.post_id
	postdata = postdata .. "&name=".. app.params.name
	postdata = postdata .. "&email=".. app.params.email
	postdata = postdata .. "&content=".. app.params.content
	postdata = postdata .. "&cookie="..app.wp_cookie

	postdata = postdata .. "&controller="..controller
	postdata = postdata .. "&method="..method

	local params = {}
	params.body = postdata

	network.request( url.."mb/"..controller.."/"..method, "POST", networkListener,  params)
end


--]]


----------------
-- Submit a post: possible values from WordPress. We should NOT use all of these!
--[[
$post = array(
  'ID'             => [ <post id> ] //Are you updating an existing post?
  'menu_order'     => [ <order> ] //If new post is a page, it sets the order in which it should appear in the tabs.
  'comment_status' => [ 'closed' | 'open' ] // 'closed' means no comments.
  'ping_status'    => [ 'closed' | 'open' ] // 'closed' means pingbacks or trackbacks turned off
  'pinged'         => [ ? ] //?
  'post_author'    => [ <user ID> ] //The user ID number of the author.
  'post_category'  => [ array(<category id>, <...>) ] //post_category no longer exists, try wp_set_post_terms() for setting a post's categories
  'post_content'   => [ <the text of the post> ] //The full text of the post.
  'post_date'      => [ Y-m-d H:i:s ] //The time post was made.
  'post_date_gmt'  => [ Y-m-d H:i:s ] //The time post was made, in GMT.
  'post_excerpt'   => [ <an excerpt> ] //For all your post excerpt needs.
  'post_name'      => [ <the name> ] // The name (slug) for your post
  'post_parent'    => [ <post ID> ] //Sets the parent of the new post.
  'post_password'  => [ ? ] //password for post?
  'post_status'    => [ 'draft' | 'publish' | 'pending'| 'future' | 'private' | custom registered status ] //Set the status of the new post.
  'post_title'     => [ <the title> ] //The title of your post.
  'post_type'      => [ 'post' | 'page' | 'link' | 'nav_menu_item' | custom post type ] //You may want to insert a regular post, page, link, a menu item or some custom post type
  'tags_input'     => [ '<tag>, <tag>, <...>' ] //For tags.
  'to_ping'        => [ ? ] //?
  'tax_input'      => [ array( 'taxonomy_name' => array( 'term', 'term2', 'term3' ) ) ] // support for custom taxonomies.
);
--]]

--[[
function app.submitPost(event)

	local url = app.url


		local function networkListener( event )
				if ( event.isError ) then
					print( "getPost: Network error!")
					callback( { status = "network error", err = "submitPost: Network error!"} )
				else
					print ( "submitPost: " .. event.response )
					local data = json.decode(event.response)
					app.result = data;
					if (callback) then
						callback(app.result)
					end
				end

			end


		local function submitPostWithNonce(event)

			if ( event.isError ) then
				print( "Network error!")
			else
				print ( "RESPONSE to getNonce: " .. event.response )
				local nonce = json.decode(event.response)

					--local postdata = "controller=auth&method=generate_auth_cookie"

				-- clean up params to be sure no missing values
				app.params.post_date = 	app.params.post_date or ""
				app.params.menu_order = app.params.menu_order or ""
				app.params.comment_status = app.params.comment_status or ""
				app.params.ping_status = app.params.ping_status or ""
				app.params.pinged = app.params.pinged or ""
				app.params.post_author = app.params.post_author or ""
				app.params.post_category = app.params.post_category or ""
				app.params.post_date_gmt = app.params.post_date_gmt or ""
				app.params.post_excerpt = app.params.post_excerpt or ""
				app.params.post_name = app.params.post_name or ""
				app.params.post_parent = app.params.post_parent or ""
				app.params.post_password = app.params.post_password or ""
				app.params.post_status = app.params.post_status or ""
				app.params.post_title = app.params.post_title or ""
				app.params.post_type = app.params.post_type or ""
				app.params.tags_input = app.params.tags_input or ""
				app.params.to_ping = app.params.to_ping or ""
				app.params.tax_input = app.params.tax_input or ""


				--------------------
				-- Set the POST data
				local postdata = ""
				postdata = postdata .. "&post_content=" .. funx.escape(app.params.post_content)

				postdata = postdata .. "&post_date=" .. funx.escape(app.params.post_date)
				postdata = postdata .. "&menu_order=" .. funx.escape(app.params.menu_order)
				postdata = postdata .. "&comment_status=" .. funx.escape(app.params.comment_status)
				postdata = postdata .. "&ping_status=" .. funx.escape(app.params.ping_status)
				postdata = postdata .. "&pinged=" .. funx.escape(app.params.pinged)
				postdata = postdata .. "&post_author=" .. funx.escape(app.params.post_author)
				postdata = postdata .. "&post_category=" .. funx.escape(app.params.post_category)
				postdata = postdata .. "&post_date_gmt=" .. funx.escape(app.params.post_date_gmt)
				postdata = postdata .. "&post_excerpt=" .. funx.escape(app.params.post_excerpt)
				postdata = postdata .. "&post_name=" .. funx.escape(app.params.post_name)
				postdata = postdata .. "&post_parent=" .. funx.escape(app.params.post_parent)
				postdata = postdata .. "&post_password=" .. funx.escape(app.params.post_password)
				postdata = postdata .. "&post_status=" .. funx.escape(app.params.post_status)
				postdata = postdata .. "&post_title=" .. funx.escape(app.params.post_title)
				postdata = postdata .. "&post_type=" .. funx.escape(app.params.post_type)
				postdata = postdata .. "&tags_input=" .. funx.escape(app.params.tags_input)
				postdata = postdata .. "&to_ping=" .. funx.escape(app.params.to_ping)
				postdata = postdata .. "&tax_input=" .. funx.escape(app.params.tax_input)

				local controller = "posts_auth"
				local method = "create_post"

				postdata = postdata .. "&controller="..controller
				postdata = postdata .. "&method="..method
				postdata = postdata .. "&cookie="..app.wp_cookie
				postdata = postdata .. "&nonce=".. nonce.nonce

	--funx.dump(app.params)

				local params = {}
				params.body = postdata
				--print ("URL: ",url.."mb/"..controller.."/"..method)
				network.request( url.."mb/"..controller.."/"..method, "POST", networkListener,  params)
			end
		end

	-- Get a nonce to submit the post
	controller = "posts_auth"
	method = "create_post"
	local postdata = "controller="..controller.."&method="..method

	local params = {}
	params.body = postdata

	network.request( url.."mb/core_auth/get_nonce", "POST", submitPostWithNonce,  params)

end

--]]



----------------
-- Get a nonce for future transactions
-- Default is get a nonce for controller=auth, method=generate_auth_cookie
function app.getNonce(controller, method, nextFunction)
	--local mime = require("mime")

			local function networkListener( event )
				if ( event.isError ) then
					app.status = { status = "error", error = "Network error!", }
					app.onError(app.status)
				else
					--print ( "RESPONSE to getNonce: " .. event.response )
					local data = json.decode(event.response)
					app.wp_nonce = data;
					app.generateAuthCookie()
				end
			end

	local url = app.url
	--local postdata = "controller=auth&method=generate_auth_cookie"

	-- Get a nonce to generate the cookie
	controller = "auth"
	method = "generate_auth_cookie"
	local postdata = "controller="..controller.."&method="..method

	local params = {}
	params.body = postdata

	network.request( url.."mb/book/get_nonce", "POST", networkListener,  params)
end

----------------------------------------
-- getUserInfo
-- A handy packaging of the getCurrentUserInfo.
-- It calls onSuccess or onFailure as appropropriate.
-- This is useful for "login".
function app.getUserInfo(url, username, password, onSuccess, onFailure)

	local params = {}
	local controller = "auth"
	local method = "generate_auth_cookie"
	local action = app.getCurrentUserInfo
	local callback = onSuccess
	local onerror = onError
	app.access(url, username, password, controller, method, params, action, onSuccess, onFailure)
end


----------------------------------------
-- nextFunction is function to call after getting the cookie
-- callback is function to call when everything is finished
function app.access(url, username, password, controller, method, params, nextFunction, callback, onError)
	app.url = url
	app.username = username
	app.password = password
	app.params = params
	app.nextFunctionWithCookie = nextFunction
	app.callback = callback
	app.onError = onError

	controller = controller or "auth"
	method = method or "generate_auth_cookie"
	app.getNonce(controller, method, app.generateAuthCookie)
end


return app