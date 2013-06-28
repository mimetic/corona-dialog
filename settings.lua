-- settings.lua
--
-- Version 0.1
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
-- Load the settings file (settings.xml) and return a table.
-- Sample XML file:
--[[


REQUIRES: require ("XmlParser")

<?xml version="1.0" encoding="UTF-8" ?>
<settings>
	<class value="navbar">
		<color>1</color>
		<height value="1" />
	</class>
</settings>

returns a table where

1) navbar.color = 1
2) navbar.height = 1

]]


local S = {}

require ("XmlParser")

------------------
function S.new(filename, sourceDirectory)
	local settings = {}

	if (filename == nil) then
		filename = "_user/settings.xml"
	end

	sourceDirectory = sourceDirectory or system.ResourceDirectory


	local filePath = system.pathForFile( filename, sourceDirectory )
	if (filePath) then
		local xmlTree = XmlParser:ParseXmlFile(filePath)

		if (not xmlTree) then
			print ("WARNING: Tried to load empty or damaged XML file from " .. filePath)
			return {}
		end
		
		for i,xmlNode in pairs(xmlTree.ChildNodes) do
			if (xmlNode.Name == "class") then
				local c = xmlNode.Attributes.value
				--print ("* Add class "..c.." to settings")
				settings[c] = {}
				for i,s in pairs(xmlNode.ChildNodes) do
					if (s.value ~= nil) then
						settings[c][s.Name] = s.value
						--print (i..") "..c.."."..s.Name.." = "..s.value )
					elseif (s.Attributes.value ~= nil) then
						settings[c][s.Name] = s.Attributes.value
						--print (i..") "..c.."."..s.Name.." = "..s.Attributes.value )
					end
				end
			end
		end
	else
		print ("WARNING: missing settings file", filename)
		settings = {}
	end

	return settings
end


return S