local layout = require('layout/dialog');

menuOptions = {};
selectedIndex = 0;

local buttonScrollTimer = 0;

local cursor = {
	alpha = 0,
	offset = 0,
	timer = 0,
};

local artist = nil;
local title = nil;

local timer = 0;
local timers = {
	artist = 0,
	button = 0,
	cursor = 0,
	title = 0,
};

local cache = { resX = 0, resY = 0 };

local resX;
local resY;
local scaledW;
local scaledH;
local scalingFactor;

setupLayout = function()
  resX, resY = game.GetResolution();

  if ((cache.resX ~= resX) or (cache.resY ~= resY)) then
    scaledW = 1920;
    scaledH = scaledW * (resY / resX);
    scalingFactor = resX / scaledW;

    cache.resX = resX;
    cache.resY = resY;
  end

  gfx.Scale(scalingFactor, scalingFactor);
end

local setLabelText = function(text)
	return {
		font = 'medium',
		text = text,
		size = 18,
	};
end 

local labels = nil;

setLabels = function()
	if (not labels) then
		labels = {
			artist = New.Label(setLabelText('ARTIST')),
			collectionName = New.Label(setLabelText('COLLECTION NAME')),
			confirm = New.Label(setLabelText('CONFIRM')),
			enter = New.Label(setLabelText('ENTER')),
			title = New.Label(setLabelText('TITLE')),
		};

		labels.input = New.Label({
			font = 'jp',
			text = '',
			size = 28,
		});
	end
end

drawArrows = function()
	local noHigher = selectedIndex == 0;
	local noLower = (selectedIndex + 1) == #menuOptions;
	local x = layout.x.center - 36;
	local y1 = layout.y.center + 29;
	local y2 = layout.y.center + 45;

	gfx.BeginPath();
	setFill('white', timer * ((noHigher and 50) or 255));
	gfx.MoveTo(x, y1);
	gfx.LineTo(x - 12, y1);
	gfx.LineTo(x - 6, y1 - 10);
	gfx.LineTo(x, y1);
	gfx.Fill();

	gfx.BeginPath();
	setFill('white', timer * ((noLower and 50) or 255));
	gfx.MoveTo(x, y2);
	gfx.LineTo(x - 12, y2);
	gfx.LineTo(x - 6, y2 + 10);
	gfx.LineTo(x , y2);
	gfx.Fill();
end

drawButton = function(deltaTime, label, isSelected, y)
	if ((y < layout.y.center) or (y > layout.y.bottom)) then return end;

	local alpha = math.floor(((isSelected and 255) or 50) * timer);
	local w = layout.images.button.w;

	if (isSelected) then
		drawImage({
			x = layout.x.outerRight - w + 12,
			y = y,
			alpha = timer,
			image = layout.images.buttonHover,
		});
	else
		drawImage({
			x = layout.x.outerRight - w + 12,
			y = y,
			alpha = (0.45 * timer),
			image = layout.images.button,
		});
	end

	gfx.Save();

	gfx.Scale(1 / scalingFactor, 1 / scalingFactor);

	if (label.w > (w - 90)) then
		buttonScrollTimer = buttonScrollTimer + deltaTime;

		drawScrollingLabel({
			x = layout.x.outerRight - w + 55,
			y = y + label.h + 8,
			alpha = alpha,
			color = 'white',
			label = label,
			scale = scalingFactor,
			timer = buttonScrollTimer,
			width = w - 90,
		});
	else
		drawLabel({
			x = layout.x.outerRight - w + 55,
			y = y + label.h + 8,
			alpha = alpha,
			color = 'white',
			label = label,
		});
	end

	gfx.Restore();
end

drawInput = function()
	local x = layout.x.middleLeft;
	local y = layout.y.center + (layout.h.outer / 10);
	local labelY = layout.y.center + (layout.h.outer / 10);

	y = y + (labels.collectionName.h * 2);

	cursor.offset = math.min(labels.input.w + 2, layout.w.middle - 20);

	drawRectangle({
		x = x,
		y = y,
		w = layout.w.middle,
		h = layout.h.outer / 6,
		alpha = 255 * timer,
		color = 'dark',
		stroke = {
			alpha = 255 * timer,
			color = 'normal',
			size = 1,
		},
	});

	drawRectangle({
		x = x + 8 + cursor.offset,
		y = y + 10,
		w = 2,
		h = (layout.h.outer / 6) - 20,
		alpha = 255 * cursor.alpha,
		color = 'white',
	});

	gfx.Save();

	gfx.Scale(1 / scalingFactor, 1 / scalingFactor);

	labels.input:update({ new = string.upper(dialog.newName) });

	drawLabel({
		x = layout.x.middleLeft,
		y = labelY,
		alpha = 255 * timer,
		color = 'normal',
		label = labels.collectionName,
	});

	labelY = labelY + (labels.collectionName.h * 2);

	drawLabel({
		x = x + 8,
		y = labelY + 7,
		alpha = 255 * timer,
		color = 'white',
		label = labels.input,
		maxWidth = layout.w.middle - 22,
	});

	labelY = labelY + (layout.h.outer / 6);

	drawLabel({
		x = layout.x.middleRight + 2,
		y = labelY + labels.confirm.h,
		align = 'right',
		alpha = 255 * timer,
		color = 'white',
		label = labels.confirm,
	});

	drawLabel({
		x = layout.x.middleRight - labels.enter.w - 16,
		y = labelY + labels.enter.h,
		align = 'right',
		alpha = 255 * timer,
		color = 'normal',
		label = labels.enter,
	});

	gfx.Restore();
end

drawSongInfo = function(deltaTime)
	local alpha = math.floor(255 * timer);
	local maxWidth = layout.w.outer - (176 / 2);
	local x = layout.x.outerLeft;
	local y = layout.y.top - 12;

	gfx.Save();

	gfx.Scale(1 / scalingFactor, 1 / scalingFactor);

	drawLabel({
		x = x,
		y = y,
		alpha = alpha,
		color = 'normal',
		label = labels.title,
	});

	y = y + (labels.title.h * 1.25);

	if (title.w > maxWidth) then
		timers.title = timers.title + deltaTime;

		drawScrollingLabel({
			x = x + 2,
			y = y,
			alpha = alpha,
			color = 'white',
			label = title,
			scale = scalingFactor,
			timer = timers.title,
			width = maxWidth,
		});
	else
		drawLabel({
			x = x,
			y = y,
			alpha = alpha,
			color = 'white',
			label = title,
		});
	end

	y = y + (title.h * 1.5);

	drawLabel({
		x = x,
		y = y,
		alpha = alpha,
		color = 'normal',
		label = labels.artist,
	});

	y = y + (labels.artist.h * 1.5);
	
	if (artist.w > maxWidth) then
		timers.artist = timers.artist + deltaTime;

		drawScrollingLabel({
			x = x + 2,
			y = y,
			alpha = alpha,
			color = 'white',
			label = artist,
			scale = scalingFactor,
			timer = timers.artist,
			width = maxWidth,
		});
	else
		drawLabel({
			x = x,
			y = y,
			alpha = alpha,
			color = 'white',
			label = artist,
		});
	end

	gfx.Restore();
end

open = function()
	initialIndex = 1;
	menuOptions = {};
	selectedIndex = 0;

	if (#dialog.collections == 0) then
		menuOptions[initialIndex] = {
			action = createCollection('FAVOURITES'),
			label = New.Label(setLabelText('ADD TO FAVOURITES')),
		};
	end

	for i, collection in ipairs(dialog.collections) do
		local currentName =
			(collection.exists and string.format('REMOVE FROM %s', string.upper(collection.name)))
			or string.format('ADD TO %s', string.upper(collection.name));

		menuOptions[i] = {
			action = createCollection(collection.name),
			label = New.Label(setLabelText(currentName)),
		};
	end

	table.insert(menuOptions, {
		action = menu.ChangeState,
		label = New.Label(setLabelText('CREATE COLLECTION')),
	});
	table.insert(menuOptions, {
		action = menu.Cancel,
		label = New.Label(setLabelText('CLOSE')),
	});

	artist = New.Label({
		font = 'jp',
		text = string.upper(dialog.artist),
		size = 28,
	});
	title = New.Label({
		font = 'jp',
		text = string.upper(dialog.title),
		size = 36,
	});
end

render = function(deltaTime)
	gfx.Save();

	setupLayout();

	layout:setSizes(scaledW, scaledH);

	setLabels();

	if (dialog.closing) then
		timer = math.max(timer - (deltaTime * 6), 0);
	else
		timer = math.min(timer + (deltaTime * 8), 1);
	end

	cursor.timer = cursor.timer + deltaTime;
	cursor.alpha = timer * (math.abs(0.8 * math.cos(cursor.timer * 5)) + 0.2);

	drawImage({
		x = scaledW / 2,
		y = scaledH / 2,
		alpha = timer,
		centered = true,
		image = layout.images.dialogBox,
	});

	drawSongInfo(deltaTime);

	if (dialog.isTextEntry) then
		drawInput();
	else
		local y = layout.y.center;
		local nextY = layout.images.button.h * 1.25;
		
		for i, option in ipairs(menuOptions) do
			local buttonY = y + nextY * ((i - 1) - selectedIndex);
			local isSelected = (i - 1) == selectedIndex;

			drawButton(deltaTime, option.label, isSelected, buttonY);
		end

		drawCursor({
			x = layout.x.outerRight - layout.images.button.w + 20,
			y = layout.y.center + 10,
			w = layout.images.button.w - 20,
			h = layout.images.button.h - 20,
			alpha = cursor.alpha,
			size = 12,
			stroke = 1.5,
		});

		drawArrows();
	end

	gfx.Restore();

	if ((dialog.closing == true) and (timer <= 0)) then
		return false;
	else
		return true;
	end
end

advance_selection = function(value)
  selectedIndex = (selectedIndex + value) % #menuOptions;
end

button_pressed = function(button)
	if (button == game.BUTTON_BCK) then
		menu.Cancel();
	elseif button == game.BUTTON_STA then
		menuOptions[selectedIndex + 1].action();
	end
end

createCollection = function(name)
	return function()
		menu.Confirm(name);
	end
end