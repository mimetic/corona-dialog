 --
-- created with TexturePacker (http://www.codeandweb.com/texturepacker)
--
-- $TexturePacker:SmartUpdate:d414a62fc42c50e9bd5dfe5c14771234$
--
-- local sheetInfo = require("mysheet")
-- local myImageSheet = graphics.newImageSheet( "mysheet.png", sheetInfo:getSheet() )
-- local sprite = display.newSprite( myImageSheet , {frames={sheetInfo:getFrameIndex("sprite")}} )
--

local SheetInfo = {}

SheetInfo.sheet =
{
    frames = {
    
        {
            -- buttonDefault_bottom
            x=16,
            y=114,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_bottomleft
            x=16,
            y=100,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_bottomright
            x=2,
            y=114,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_left
            x=2,
            y=100,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_mid
            x=16,
            y=86,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_right
            x=2,
            y=86,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_top
            x=16,
            y=72,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_topleft
            x=2,
            y=72,
            width=12,
            height=12,

        },
        {
            -- buttonDefault_topright
            x=16,
            y=58,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_bottom
            x=2,
            y=58,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_bottomleft
            x=16,
            y=44,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_bottomright
            x=2,
            y=44,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_left
            x=16,
            y=30,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_mid
            x=2,
            y=30,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_right
            x=16,
            y=16,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_top
            x=2,
            y=16,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_topleft
            x=16,
            y=2,
            width=12,
            height=12,

        },
        {
            -- buttonSelected_topright
            x=2,
            y=2,
            width=12,
            height=12,

        },
    },
    
    sheetContentWidth = 32,
    sheetContentHeight = 128
}

SheetInfo.frameIndex =
{

    ["buttonDefault_bottom"] = 1,
    ["buttonDefault_bottomleft"] = 2,
    ["buttonDefault_bottomright"] = 3,
    ["buttonDefault_left"] = 4,
    ["buttonDefault_mid"] = 5,
    ["buttonDefault_right"] = 6,
    ["buttonDefault_top"] = 7,
    ["buttonDefault_topleft"] = 8,
    ["buttonDefault_topright"] = 9,
    ["buttonSelected_bottom"] = 10,
    ["buttonSelected_bottomleft"] = 11,
    ["buttonSelected_bottomright"] = 12,
    ["buttonSelected_left"] = 13,
    ["buttonSelected_mid"] = 14,
    ["buttonSelected_right"] = 15,
    ["buttonSelected_top"] = 16,
    ["buttonSelected_topleft"] = 17,
    ["buttonSelected_topright"] = 18,
}

function SheetInfo:getSheet()
    return self.sheet;
end

function SheetInfo:getFrameIndex(name)
    return self.frameIndex[name];
end

return SheetInfo
