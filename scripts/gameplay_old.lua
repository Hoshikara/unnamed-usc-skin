hitAnimation = require('gameplay/hitanimation');
hitError = require('gameplay/hiterror');
laserAnimation = require('gameplay/laseranimation');

if (not hitAnimation['initialized']) then
	hitAnimation:initializeAll();
end

if (not hitError['initialized']) then
	hitError:initializeAll();
end

if (not laserAnimation['initialized']) then
	laserAnimation:initializeAll();
end

function clamp(x, min, max) 
    if x < min then
        x = min
    end
    if x > max then
        x = max
    end

    return x
end

function smootherstep(edge0, edge1, x) 
    -- Scale, and clamp x to 0..1 range
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    -- Evaluate polynomial
    return x * x * x * (x * (x * 6 - 15) + 10)
end
  
function to_range(val, start, stop)
    return start + (stop - start) * val
end

Animation = {
    start = 0,
    stop = 0,
    progress = 0,
    duration = 1,
    smoothStart = false
}

function Animation:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Animation:restart(start, stop, duration)
    self.progress = 0
    self.start = start
    self.stop = stop
    self.duration = duration
end

function Animation:tick(deltaTime)
    self.progress = math.min(1, self.progress + deltaTime / self.duration)
    if self.progress == 1 then return self.stop end
    if self.smoothStart then
        return to_range(smootherstep(0, 1, self.progress), self.start, self.stop)
    else
        return to_range(smootherstep(-1, 1, self.progress) * 2 - 1, self.start, self.stop)
    end
end

local RECT_FILL = "fill"
local RECT_STROKE = "stroke"
local RECT_FILL_STROKE = RECT_FILL .. RECT_STROKE

gfx._ImageAlpha = 1
if gfx._FillColor == nil then
	gfx._FillColor = gfx.FillColor
	gfx._StrokeColor = gfx.StrokeColor
	gfx._SetImageTint = gfx.SetImageTint
end

gfx.SetImageTint = nil

function gfx.FillColor(r, g, b, a)
    r = math.floor(r or 255)
    g = math.floor(g or 255)
    b = math.floor(b or 255)
    a = math.floor(a or 255)

    gfx._ImageAlpha = a / 255
    gfx._FillColor(r, g, b, a)
    gfx._SetImageTint(r, g, b)
end

function gfx.StrokeColor(r, g, b)
    r = math.floor(r or 255)
    g = math.floor(g or 255)
    b = math.floor(b or 255)

    gfx._StrokeColor(r, g, b)
end

function gfx.DrawRect(kind, x, y, w, h)
    local doFill = kind == RECT_FILL or kind == RECT_FILL_STROKE
    local doStroke = kind == RECT_STROKE or kind == RECT_FILL_STROKE

    local doImage = not (doFill or doStroke)

    gfx.BeginPath()

    if doImage then
        gfx.ImageRect(x, y, w, h, kind, gfx._ImageAlpha, 0)
    else
        gfx.Rect(x, y, w, h)
        if doFill then gfx.Fill() end
        if doStroke then gfx.Stroke() end
    end
end

local buttonStates = { }
local buttonsInOrder = {
    game.BUTTON_BTA,
    game.BUTTON_BTB,
    game.BUTTON_BTC,
    game.BUTTON_BTD,

    game.BUTTON_FXL,
    game.BUTTON_FXR,

    game.BUTTON_STA,
}

function UpdateButtonStatesAfterProcessed()
    for i = 1, 6 do
        local button = buttonsInOrder[i]
        buttonStates[button] = game.GetButton(button)
    end
end

function game.GetButtonPressed(button)
    return game.GetButton(button) and not buttonStates[button]
end

function game.IsUserInputActive(lane)
    if lane < 7 then
        return game.GetButton(buttonsInOrder[lane])
    end
    return gameplay.IsLaserHeld(lane - 7)
end

function gfx.FillLaserColor(index, alpha)
    alpha = math.floor(alpha or 255)
    local r, g, b = game.GetLaserColor(index - 1)
    gfx.FillColor(r, g, b, alpha)
end

local resx, resy -- The resolution of the window
local resx_old = 0
local resy_old = 0
local portrait -- whether the window is in portrait orientation
local desw, desh -- The resolution of the deisign
local scale -- the scale to get from design to actual units
local jacketFallback = gfx.CreateSkinImage("song_select/loading.png", 0)
local bottomFill = gfx.CreateSkinImage("console/console.png", 0)
local topFill = gfx.CreateSkinImage("fill_top.png", 0)
local critAnimImg = gfx.CreateSkinImage("crit_anim.png", gfx.IMAGE_REPEATX)
local critAnim = gfx.ImagePattern(0,-50,100,100,0,critAnimImg,1)
local critCap = gfx.CreateSkinImage("crit_cap.png", 0)
local critCapBack = gfx.CreateSkinImage("crit_cap_back.png", 0)
local laserCursor = gfx.CreateSkinImage("pointer.png", 0)
local laserCursorOverlay = gfx.CreateSkinImage("pointer_overlay.png", 0)
local earlatePos = game.GetSkinSetting("earlate_position")

local ioConsoleDetails = {
    gfx.CreateSkinImage("console/detail_left.png", 0),
    gfx.CreateSkinImage("console/detail_right.png", 0),
}

local consoleAnimImages = {
    gfx.CreateSkinImage("console/glow_bta.png", 0),
    gfx.CreateSkinImage("console/glow_btb.png", 0),
    gfx.CreateSkinImage("console/glow_btc.png", 0),
    gfx.CreateSkinImage("console/glow_btd.png", 0),
    
    gfx.CreateSkinImage("console/glow_fxl.png", 0),
    gfx.CreateSkinImage("console/glow_fxr.png", 0),

    gfx.CreateSkinImage("console/glow_voll.png", 0),
    gfx.CreateSkinImage("console/glow_volr.png", 0),
}

if introTimer == nil then
	introTimer = 2
	outroTimer = 0
end
local alertTimers = {-2,-2}

local earlateTimer = 0
local critAnimTimer = 0

local consoleAnimSpeed = 10
local consoleAnimTimers = { 0, 0, 0, 0, 0, 0, 0, 0 }

local score = 0
local combo = 0
local jacket = nil
local critLinePos = { 0.95, 0.75 };
local comboScale = 1.0
local late = false
local diffNames = {"NOV", "ADV", "EXH", "INF"}
local clearTexts = {"TRACK FAILED", "TRACK COMPLETE", "TRACK COMPLETE", "FULL COMBO", "PERFECT" }
-- -------------------------------------------------------------------------- --
-- Cached calculations                                                        --
local song_info = {}
local gauge_info = {}
local crit_base_info = {}
local combo_info = {}

function ResetLayoutInformation()
    portrait = resy > resx
    desw = portrait and 720 or 1280 
    desh = desw * (resy / resx)
    scale = resx / desw

    do --update song_info
        local songInfoWidth = 400
        local jacketWidth = 100
        song_info.songInfoWidth = songInfoWidth
        song_info.jacketWidth = jacketWidth

        gfx.LoadSkinFont("NotoSans-Regular.ttf")
        gfx.FontSize(30)

        song_info.textX = jacketWidth + 10
        local titleWidth = songInfoWidth - jacketWidth - 20
        local x1, y1, x2, y2 = gfx.TextBounds(0, 0, gameplay.title)
        song_info.title_textscale = math.min(titleWidth / x2, 1)
        x1,y1,x2,y2 = gfx.TextBounds(0,0,gameplay.artist)
        song_info.artist_textscale = math.min(titleWidth / x2, 1)
    end

    do --update gauge_info
        gauge_info.height = 1024 * scale * 0.35
        gauge_info.width = 512 * scale * 0.35
        gauge_info.posy = resy / 2 - gauge_info.height / 2
        gauge_info.posx = resx - gauge_info.width
        if portrait then
            gauge_info.width = gauge_info.width * 0.8
            gauge_info.height = gauge_info.height * 0.8
            gauge_info.posy = gauge_info.posy - 30
            gauge_info.posx = resx - gauge_info.width
        end

        gauge_info.label_posx = gauge_info.posx / scale + (100 * 0.35) 
        gauge_info.label_height = 880 * 0.35
        if portrait then
            gauge_info.label_height = gauge_info.label_height * 0.8;
        end
        gauge_info.label_posy = gauge_info.posy / scale + (70 * 0.35) + gauge_info.label_height
    end

    do --update crit_base_info
        -- The absolute width of the crit line itself
        -- we check to see if we're playing in portrait mode and
        --  change the width accordingly
        crit_base_info.critWidth = resx * (portrait and 1 or 0.8)
        crit_base_info.half_critWidth = crit_base_info.critWidth / 2

        -- get the scaled dimensions of the crit line pieces
        local clw, clh = gfx.ImageSize(critAnimImg)
        crit_base_info.critAnimHeight = 15 * scale
        crit_base_info.critAnimWidth = crit_base_info.critAnimHeight * (clw / clh)

        local ccw, cch = gfx.ImageSize(critCap)
        crit_base_info.critCapHeight = crit_base_info.critAnimHeight * (cch / clh)
        crit_base_info.critCapWidth = crit_base_info.critCapHeight * (ccw / cch)

        crit_base_info.half_critAnimHeight = crit_base_info.critAnimHeight / 2
        crit_base_info.half_critAnimWidth = crit_base_info.critAnimWidth / 2
        crit_base_info.half_critCapHeight = crit_base_info.critCapHeight / 2
        crit_base_info.half_critCapWidth = crit_base_info.critCapWidth / 2
    end

    do --update combo_info
        combo_info.posx = desw / 2
        combo_info.posy = desh * critLinePos[1] - 100
        if portrait then combo_info.posy = desh * critLinePos[2] - 150 end
    end

end

function render(deltaTime)
    gfx.ResetTransform()
    
    gfx.Scale(scale, scale)
    local yshift = 0

    if portrait then yshift = draw_banner(deltaTime) end

    gfx.Translate(0, yshift - 150 * math.max(introTimer - 1, 0))
    --draw_song_info(deltaTime)
    draw_score(deltaTime)
    gfx.Translate(0, -yshift + 150 * math.max(introTimer - 1, 0))
    draw_gauge(deltaTime)
	if earlatePos ~= "off" then
		draw_earlate(deltaTime)
	end
    draw_combo(deltaTime)
    draw_alerts(deltaTime)

    drawHitError(deltaTime);
	
	if gameplay.autoplay then
		gfx.LoadSkinFont("NotoSans-Regular.ttf")
		gfx.FontSize(30)
		gfx.TextAlign(gfx.TEXT_ALIGN_TOP + gfx.TEXT_ALIGN_CENTER)
		gfx.FillColor(255,255,255)
		gfx.Text("Autoplay", desw/2, yshift)
	end
end

function SetUpCritTransform()
	gfx.ResetTransform();
	gfx.Translate(gameplay.critLine.x, gameplay.critLine.y);
	gfx.Rotate(-gameplay.critLine.rotation);
end

function GetCritLineCenteringOffset()
	return gameplay.critLine.xOffset * 10;
end

render_crit_base = function(deltaTime)
    -- Kind of a hack, but here (since this is the first render function
    --  that gets called per frame) we update the layout information.
    -- This means that the player can resize their window and
    --  not break everything
    resx, resy = game.GetResolution()
    if resx ~= resx_old or resy ~= resy_old then
        ResetLayoutInformation()
        resx_old = resx
        resy_old = resy
    end

    critAnimTimer = critAnimTimer + deltaTime
    SetUpCritTransform()
    
    -- Figure out how to offset the center of the crit line to remain
    --  centered on the players screen
    local xOffset = GetCritLineCenteringOffset()
    gfx.Translate(xOffset, 0)
    
    -- Draw a transparent black overlay below the crit line
    -- This darkens the play area as it passes
    gfx.FillColor(0, 0, 0, 200)
    gfx.DrawRect(RECT_FILL, -resx, 0, resx * 2, resy)

    -- draw the back half of the caps at each end
    do
        gfx.FillColor(255, 255, 255)
        -- left side
        gfx.DrawRect(critCapBack,
            -crit_base_info.half_critWidth -crit_base_info.half_critCapWidth,
            -crit_base_info.half_critCapHeight,
            crit_base_info.critCapWidth,
            crit_base_info.critCapHeight)
        gfx.Scale(-1, 1) -- scale to flip horizontally
        -- right side
        gfx.DrawRect(critCapBack, 
            -crit_base_info.half_critWidth - crit_base_info.half_critCapWidth,
            -crit_base_info.half_critCapHeight,
            crit_base_info.critCapWidth,
            crit_base_info.critCapHeight)
        gfx.Scale(-1, 1) -- unflip horizontally
    end

    -- render the core of the crit line
    do
        -- The crit line is made up of two rects with a pattern that scrolls in opposite directions on each rect
        local startOffset = crit_base_info.critAnimWidth * ((critAnimTimer * 1.5) % 1)

        -- left side
        -- Use a scissor to limit the drawable area to only what should be visible
        gfx.UpdateImagePattern(critAnim, 
            -startOffset,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.critAnimWidth,
            crit_base_info.critAnimHeight,
            0, 1)
        
        gfx.Scissor(-crit_base_info.half_critWidth,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.half_critWidth,
            crit_base_info.critAnimHeight)

        gfx.BeginPath()
        gfx.Rect(-crit_base_info.half_critWidth,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.half_critWidth,
            crit_base_info.critAnimHeight)
        gfx.FillPaint(critAnim)
        gfx.Fill()
        gfx.ResetScissor()
        

        -- right side
        -- exactly the same, but in reverse
        gfx.UpdateImagePattern(critAnim,
            startOffset,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.critAnimWidth,
            crit_base_info.critAnimHeight,
            0, 1)
        
        gfx.Scissor(0,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.half_critWidth,
            crit_base_info.critAnimHeight)
        gfx.BeginPath()
        gfx.Rect(0,
            -crit_base_info.half_critAnimHeight,
            crit_base_info.half_critWidth,
            crit_base_info.critAnimHeight)
        gfx.FillPaint(critAnim)
        gfx.Fill()
        gfx.ResetScissor()
    end

    -- Draw the front half of the caps at each end
    do
        gfx.FillColor(255, 255, 255)
        -- left side
        gfx.DrawRect(critCap,
            -crit_base_info.half_critWidth - crit_base_info.half_critCapWidth,
            -crit_base_info.half_critCapHeight,
            crit_base_info.critCapWidth,
            crit_base_info.critCapHeight)
        gfx.Scale(-1, 1) -- scale to flip horizontally
        -- right side
        gfx.DrawRect(critCap,
            -crit_base_info.half_critWidth - crit_base_info.half_critCapWidth,
            -crit_base_info.half_critCapHeight,
            crit_base_info.critCapWidth,
            crit_base_info.critCapHeight)
        gfx.Scale(-1, 1) -- unflip horizontally
    end

    -- we're done, reset graphics stuffs
    gfx.FillColor(255, 255, 255)
    gfx.ResetTransform()
end

render_crit_overlay = function(deltaTime)
	hitAnimation:render(deltaTime, scale);

    SetUpCritTransform();
    
	local cw, ch = gfx.ImageSize(laserCursor)
	local cursorWidth = 40 * scale
	local cursorHeight = cursorWidth * (ch / cw)

	-- draw each laser cursor
	for i = 1, 2 do
		local cursor = gameplay.critLine.cursors[i - 1];
		local pos, skew = cursor.pos, cursor.skew;

        laserAnimation:render(deltaTime, i, pos, scale, skew);

		gfx.SkewX(skew);
		gfx.FillLaserColor(i, cursor.alpha * 255)
		gfx.DrawRect(laserCursor, pos - cursorWidth / 2, -cursorHeight / 2, cursorWidth, cursorHeight)
		gfx.FillColor(255, 255, 255, cursor.alpha * 255)
		gfx.DrawRect(laserCursorOverlay, pos - cursorWidth / 2, -cursorHeight / 2, cursorWidth, cursorHeight)
		gfx.SkewX(-skew)
	end

	gfx.FillColor(255, 255, 255)
	gfx.ResetTransform();
end

function draw_banner(deltaTime)
    local bannerWidth, bannerHeight = gfx.ImageSize(topFill)
    local actualHeight = desw * (bannerHeight / bannerWidth)

    gfx.FillColor(255, 255, 255)
    gfx.DrawRect(topFill, 0, 0, desw, actualHeight)

    return actualHeight
end

button_hit = function(button, rating, delta)
	hitAnimation:queueHit(button, rating);
	hitError:queueHit(button, rating, delta);
end

drawHitError = function(deltaTime)
	if (string.upper(game.GetSkinSetting('hitErrorPosition')) == 'OFF') then return end;
	
    hitError:render(deltaTime, desw, desh);
end


function draw_stat(x, y, w, h, name, value, format, r, g, b)
    gfx.Save()

    -- Translate from the parent transform, wherever that may be
    gfx.Translate(x, y)

    -- Draw the `name` top-left aligned at `h` size
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP)
    gfx.FontSize(h)
    gfx.Text(name .. ":", 0, 0) -- 0, 0, is x, y after translation

    -- Realign the text and draw the value, formatted
    gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_TOP)
    gfx.Text(string.format(format, value), w, 0)
    -- This draws an underline beneath the text
    -- The line goes from 0, h to w, h
    gfx.BeginPath()
    gfx.MoveTo(0, h)
    gfx.LineTo(w, h) -- only defines the line, does NOT draw it yet

    -- If a color is provided, set it
    if r then gfx.StrokeColor(r, g, b) 
    -- otherwise, default to a light grey
    else gfx.StrokeColor(200, 200, 200) end

    -- Stroke out the line
    gfx.StrokeWidth(1)
    gfx.Stroke()
    -- Undo our transform changes
    gfx.Restore()

    -- Return the next `y` position, for easier vertical stacking
    return y + h + 5
end

function draw_song_info(deltaTime)
    -- Check to see if there's a jacket to draw, and attempt to load one if not
    if jacket == nil or jacket == jacketFallback then
        jacket = gfx.LoadImageJob(gameplay.jacketPath, jacketFallback)
    end

    gfx.Save()

    -- Add a small margin at the edge
    gfx.Translate(5,5)
    -- There's less screen space in portrait, the playable area is effectively a square
    -- We scale down to take up less space
    if portrait then gfx.Scale(0.7, 0.7) end

    -- Ensure the font has been loaded
    gfx.LoadSkinFont("NotoSans-Regular.ttf")

    -- Draw the background, a simple grey box
    gfx.FillColor(20, 20, 20, 200)
    gfx.DrawRect(RECT_FILL, 0, 0, song_info.songInfoWidth, 100)
    -- Draw the jacket
    gfx.FillColor(255, 255, 255)
    gfx.DrawRect(jacket, 0, 0, song_info.jacketWidth, song_info.jacketWidth)
    -- Draw a background for the following level stat
    gfx.FillColor(0, 0, 0, 200)
    gfx.DrawRect(RECT_FILL, 0, 85, 60, 15)
    -- Level Name : Level Number
    gfx.FillColor(255, 255, 255)
    draw_stat(0, 85, 55, 15, diffNames[gameplay.difficulty + 1], gameplay.level, "%02d")
    -- Reset some text related stuff that was changed in draw_state
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT)
    gfx.FontSize(30)
    
    gfx.FillColor(255, 255, 255)

    local textscale = song_info.title_textscale
    local textX = song_info.textX
    
    gfx.Save()
    do  -- Draw the song title, scaled to fit as best as possible
        gfx.Translate(textX, 30)
        gfx.Scale(textscale, textscale)
        gfx.Text(gameplay.title, 0, 0)
    end
    gfx.Restore()

    textscale = song_info.artist_textscale

    gfx.Save()
    do  -- Draw the song artist, scaled to fit as best as possible
        gfx.Translate(textX, 60)
        gfx.Scale(textscale, textscale)
        gfx.Text(gameplay.artist, 0, 0)
    end
    gfx.Restore()

    -- Draw the BPM
    gfx.FontSize(20)
    gfx.Text(string.format("BPM: %.1f", gameplay.bpm), textX, 85)

    -- Fill the progress bar
    gfx.FillColor(0, 150, 255)
    gfx.DrawRect(RECT_FILL, song_info.jacketWidth, song_info.jacketWidth - 10, (song_info.songInfoWidth - song_info.jacketWidth) * gameplay.progress, 10)

    -- When the player is holding Start, the hispeed can be changed
    -- Shows the current hispeed values
    if game.GetButton(game.BUTTON_STA) then
		gfx.FillColor(20, 20, 20, 200);
		gfx.DrawRect(RECT_FILL, 100, 100, song_info.songInfoWidth - 100, 20)
		gfx.FillColor(255, 255, 255)
		if game.GetButton(game.BUTTON_BTB) then
			gfx.Text(string.format("Hid/Sud Cutoff: %.1f%% / %.1f%%", 
					gameplay.hiddenCutoff * 100, gameplay.suddenCutoff * 100),
					textX, 115)
		
		elseif game.GetButton(game.BUTTON_BTC) then
			gfx.Text(string.format("Hid/Sud Fade: %.1f%% / %.1f%%", 
					gameplay.hiddenFade * 100, gameplay.suddenFade * 100),
					textX, 115)
		else
			gfx.Text(string.format("HiSpeed: %.0f x %.1f = %.0f",
					gameplay.bpm, gameplay.hispeed, gameplay.bpm * gameplay.hispeed),
					textX, 115)
		end
    end

    -- aaaand, scene!
    gfx.Restore()
end

function draw_best_diff(deltaTime, x, y)
    -- Don't do anything if there's nothing to do
    if not gameplay.scoreReplays[1] then return end

    -- Calculate the difference between current and best play
    local difference = score - gameplay.scoreReplays[1].currentScore
    local prefix = "" -- used to properly display negative values

    gfx.BeginPath()
    gfx.FontSize(40)

    gfx.FillColor(255, 255, 255)
    if difference < 0 then
        -- If we're behind the best score, separate the minus sign and change the color
        gfx.FillColor(255, 50, 50)
        difference = math.abs(difference)
        prefix = "-"
    end

    -- %08d formats a number to 8 characters
    -- This includes the minus sign, so we do that separately
    gfx.Text(string.format("%s%08d", prefix, difference), x, y)
end

local score_animation = Animation:new()

function draw_score(deltaTime)
    gfx.BeginPath()
    gfx.LoadSkinFont("NovaMono.ttf")
    gfx.BeginPath()
    gfx.RoundedRectVarying(desw - 210, 5, 220, 62, 0, 0, 0, 20)
    gfx.FillColor(20, 20, 20)
    gfx.StrokeColor(0, 128, 255)
    gfx.StrokeWidth(2)
    gfx.Fill()
    gfx.Stroke()
    gfx.Translate(-5, 5) -- upper right margin
    gfx.FillColor(255, 255, 255)
    gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_TOP)
    gfx.FontSize(60)
    gfx.Text(string.format("%08d", math.floor(score_animation:tick(deltaTime))), desw, 0)
    draw_best_diff(deltaTime, desw, 66)
    gfx.Translate(5, -5) -- undo margin
end

function draw_gauge(deltaTime)

    gfx.DrawGauge(gameplay.gauge, 
        gauge_info.posx, 
        gauge_info.posy, 
        gauge_info.width, 
        gauge_info.height, 
        deltaTime)

	--draw gauge % label
	local posy = gauge_info.label_posy - gauge_info.label_height * gameplay.gauge
	gfx.BeginPath()
	gfx.Rect(gauge_info.label_posx-35, posy-10, 40, 20)
	gfx.FillColor(0,0,0,200)
	gfx.Fill()
	gfx.FillColor(255,255,255)
	gfx.TextAlign(gfx.TEXT_ALIGN_RIGHT + gfx.TEXT_ALIGN_MIDDLE)
	gfx.FontSize(20)
	gfx.Text(string.format("%d%%", math.floor(gameplay.gauge * 100)), gauge_info.label_posx, posy )
end

function draw_combo(deltaTime)
    if combo == 0 then return end
    gfx.BeginPath()
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
    if gameplay.comboState == 2 then
        gfx.FillColor(100,255,0) --puc
    elseif gameplay.comboState == 1 then
        gfx.FillColor(255,200,0) --uc
    else
        gfx.FillColor(255,255,255) --regular
    end
    gfx.LoadSkinFont("NovaMono.ttf")
    gfx.FontSize(70 * math.max(comboScale, 1))
    comboScale = comboScale - deltaTime * 3
    gfx.Text(tostring(combo), combo_info.posx, combo_info.posy)
end

function draw_earlate(deltaTime)
    earlateTimer = math.max(earlateTimer - deltaTime,0)
    if earlateTimer == 0 then return nil end
    local alpha = math.floor(earlateTimer * 20) % 2
    alpha = alpha * 200 + 55
    gfx.BeginPath()
    gfx.FontSize(35)
    gfx.TextAlign(gfx.TEXT_ALIGN_CENTER, gfx.TEXT_ALIGN_MIDDLE)
    local ypos = desh * critLinePos[1] - 150
    if portrait then ypos = desh * critLinePos[2] - 200 end
	if earlatePos == "middle" then
		ypos = ypos - 200
	elseif earlatePos == "top" then
		ypos = ypos - 400
	end

    if late then
        gfx.FillColor(0,255,255, alpha)
        gfx.Text("LATE", desw / 2, ypos)
    else
        gfx.FillColor(255,0,255, alpha)
        gfx.Text("EARLY", desw / 2, ypos)
    end
end

function draw_alerts(deltaTime)
    alertTimers[1] = math.max(alertTimers[1] - deltaTime,-2)
    alertTimers[2] = math.max(alertTimers[2] - deltaTime,-2)
    if alertTimers[1] > 0 then --draw left alert
        gfx.Save()
        local posx = desw / 2 - 350
        local posy = desh * critLinePos[1] - 135
        if portrait then 
            posy = desh * critLinePos[2] - 135 
            posx = 65
        end
        gfx.Translate(posx,posy)
        r,g,b = game.GetLaserColor(0)
        local alertScale = (-(alertTimers[1] ^ 2.0) + (1.5 * alertTimers[1])) * 5.0
        alertScale = math.min(alertScale, 1)
        gfx.Scale(1, alertScale)
        gfx.BeginPath()
        gfx.RoundedRectVarying(-50,-50,100,100,20,0,20,0)
        gfx.StrokeColor(r,g,b)
        gfx.FillColor(20,20,20)
        gfx.StrokeWidth(2)
        gfx.Fill()
        gfx.Stroke()
        gfx.BeginPath()
        gfx.FillColor(r,g,b)
        gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
        gfx.FontSize(90)
        gfx.Text("L",0,0)
        gfx.Restore()
    end
    if alertTimers[2] > 0 then --draw right alert
        gfx.Save()
        local posx = desw / 2 + 350
        local posy = desh * critLinePos[1] - 135
        if portrait then 
            posy = desh * critLinePos[2] - 135 
            posx = desw - 65
        end
        gfx.Translate(posx,posy)
        r,g,b = game.GetLaserColor(1)
        local alertScale = (-(alertTimers[2] ^ 2.0) + (1.5 * alertTimers[2])) * 5.0
        alertScale = math.min(alertScale, 1)
        gfx.Scale(1, alertScale)
        gfx.BeginPath()
        gfx.RoundedRectVarying(-50,-50,100,100,0,20,0,20)
        gfx.StrokeColor(r,g,b)
        gfx.FillColor(20,20,20)
        gfx.StrokeWidth(2)
        gfx.Fill()
        gfx.Stroke()
        gfx.BeginPath()
        gfx.FillColor(r,g,b)
        gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
        gfx.FontSize(90)
        gfx.Text("R",0,0)
        gfx.Restore()
    end
end

function change_earlatepos()
	if earlatePos == "top" then
		earlatePos = "off"
	elseif earlatePos == "off" then
		earlatePos = "bottom"
	elseif earlatePos == "bottom" then
		earlatePos = "middle"
	elseif earlatePos == "middle" then
		earlatePos = "top"
	end
	game.SetSkinSetting("earlate_position", earlatePos)
end

-- -------------------------------------------------------------------------- --
-- render_intro:                                                              --
local bta_last = false
function render_intro(deltaTime)
    if gameplay.demoMode then
        introTimer = 0
        return true
    end
    if not game.GetButton(game.BUTTON_STA) then
        introTimer = introTimer - deltaTime
		earlateTimer = 0
	else
		earlateTimer = 1
		if (not bta_last) and game.GetButton(game.BUTTON_BTA) then
			change_earlatepos()
		end
	end
	bta_last = game.GetButton(game.BUTTON_BTA)
    introTimer = math.max(introTimer, 0)
	
    return introTimer <= 0
end
-- -------------------------------------------------------------------------- --
-- render_outro:                                                              --
function render_outro(deltaTime, clearState)
    if clearState == 0 then return true end
    if not gameplay.demoMode then
        gfx.ResetTransform()
        gfx.BeginPath()
        gfx.Rect(0,0,resx,resy)
        gfx.FillColor(0,0,0, math.floor(127 * math.min(outroTimer, 1)))
        gfx.Fill()
        gfx.Scale(scale,scale)
        gfx.TextAlign(gfx.TEXT_ALIGN_CENTER + gfx.TEXT_ALIGN_MIDDLE)
        gfx.FillColor(255,255,255, math.floor(255 * math.min(outroTimer, 1)))
        gfx.LoadSkinFont("NovaMono.ttf")
        gfx.FontSize(70)
        gfx.Text(clearTexts[clearState], desw / 2, desh / 2)
        outroTimer = outroTimer + deltaTime
        return outroTimer > 2, 1 - outroTimer
    else
        outroTimer = outroTimer + deltaTime
        return outroTimer > 2, 1
    end

end
-- -------------------------------------------------------------------------- --
-- update_score:                                                              --
function update_score(newScore)
    if newScore ~= score then
        score_animation:restart(score_animation:tick(0), newScore, 0.33)
        score = newScore
    end
end
-- -------------------------------------------------------------------------- --
-- update_combo:                                                              --
function update_combo(newCombo)
    combo = newCombo
    comboScale = 1.5
end
-- -------------------------------------------------------------------------- --
-- near_hit:                                                                  --
function near_hit(wasLate) --for updating early/late display
    late = wasLate
    earlateTimer = 0.75
end
-- -------------------------------------------------------------------------- --
-- laser_alert:                                                               --
function laser_alert(isRight) --for starting laser alert animations
    if isRight and alertTimers[2] < -1.5 then
        alertTimers[2] = 1.5
    elseif alertTimers[1] < -1.5 then
        alertTimers[1] = 1.5
    end
end


-- ======================== Start mutliplayer ========================

json = require('lib/json');

local normal_font = game.GetSkinSetting('multi.normal_font')
if normal_font == nil then
    normal_font = 'NotoSans-Regular.ttf'
end
local mono_font = game.GetSkinSetting('multi.mono_font')
if mono_font == nil then
    mono_font = 'NovaMono.ttf'
end

local users = nil

function init_tcp()
    Tcp.SetTopicHandler("game.scoreboard", function(data)
        users = {}
        for i, u in ipairs(data.users) do
            table.insert(users, u)
        end
    end)
end


-- Hook the render function and draw the scoreboard
local real_render = render
render = function(deltaTime)
    real_render(deltaTime)
    draw_users(deltaTime)
end

-- Update the users in the scoreboard
function score_callback(response)
    if response.status ~= 200 then 
        error() 
        return 
    end
    local jsondata = json.decode(response.text)
    users = {}
    for i, u in ipairs(jsondata.users) do
        table.insert(users, u)
    end
end

-- Render scoreboard
function draw_users(detaTime)
    if (users == nil) then
        return
    end

    local yshift = 0

    -- In portrait, we draw a banner across the top
    -- The rest of the UI needs to be drawn below that banner
    if portrait then
        local bannerWidth, bannerHeight = gfx.ImageSize(topFill)
        yshift = desw * (bannerHeight / bannerWidth)
        gfx.Scale(0.7, 0.7)
    end

    gfx.Save()

    -- Add a small margin at the edge
    gfx.Translate(5,yshift+200)

    -- Reset some text related stuff that was changed in draw_state
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT)
    gfx.FontSize(35)
    gfx.FillColor(255, 255, 255)
    local yoff = 0
    if portrait then
        yoff = 75;
    end
    local rank = 0
    for i, u in ipairs(users) do
        gfx.FillColor(255, 255, 255)
        local score_big = string.format("%04d",math.floor(u.score/1000));
        local score_small = string.format("%03d",u.score%1000);
        local user_text = '('..u.name..')';

        local size_big = 40;
        local size_small = 28;
        local size_name = 30;

        if u.id == gameplay.user_id then
            size_big = 48
            size_small = 32
            size_name = 40
            rank = i;
        end

        gfx.LoadSkinFont(mono_font)
        gfx.FontSize(size_big)
        gfx.Text(score_big, 0, yoff);
        local xmin,ymin,xmax,ymax_big = gfx.TextBounds(0, yoff, score_big);
        xmax = xmax + 7

        gfx.FontSize(size_small)
        gfx.Text(score_small, xmax, yoff);
        xmin,ymin,xmax,ymax = gfx.TextBounds(xmax, yoff, score_small);
        xmax = xmax + 7

        if u.id == gameplay.user_id then
            gfx.FillColor(237, 240, 144)
        end
        
        gfx.LoadSkinFont(normal_font)
        gfx.FontSize(size_name)
        gfx.Text(user_text, xmax, yoff)

        yoff = ymax_big + 15
    end

    gfx.Restore()
end