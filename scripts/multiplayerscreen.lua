local CONSTANTS_SONGWHEEL = require('constants/songwheel')
local CONSTANTS_MULTI = require('constants/multiplayerscreen');

local Controller = require('common/controller');
local Cursor = require('common/cursor');
local DialogWindow = require('common/dialogwindow');
local List = require('common/list');local ScoreNumber = require('common/scorenumber');
local Scrollbar = require('common/scrollbar');

local JSON = require('lib/JSON');

game.LoadSkinSample('click-01');
game.LoadSkinSample('click-02');
game.LoadSkinSample('menu_click');

local allowClick = false;

local allReady;
local allRooms = {};
local allUsers = {};

local background = New.Image({ path = 'bg.png' });

local allowHardToggle = getSetting('toggleHard', false);
local allowMirrorToggle = getSetting('toggleMirror', false);

local didExit = false;

local hardGauge = false;
local host = nil;

local isLoading = true;
local isMissingSong = false;
local isStartingGame = false;

local hoveredButton = nil;

local mirrorMode = false;

local jacket = nil;
local jacketFallback = gfx.CreateSkinImage('common/loading.png', 0);

local mousePosX = 0;
local mousePosY = 0;

local owner = nil;

local previousAllReady = nil;
local previousWindow = '';
local previousSong = nil;

local selectedRoom = nil;
local selectedRoomIndex = 1;

local userId = nil;
local userName = nil;
local userReady;

do
	local usernameKey = getSetting('multi.user_name_key');

	if (not userNameKey) then
		userNameKey = 'displayName';
	end

	local userName = getSetting(userNameKey, '');

	if ((not userName) or (userName == '')) then
		userName = 'GUEST';
	end
end

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

mouseClipped = function(x, y, w, h)
	local scaledX = x * scalingFactor;
	local scaledY = y * scalingFactor;
	local scaledW = scaledX + (w * scalingFactor);
	local scaledH = scaledY + (h * scalingFactor);

	return (mousePosX > scaledX)
		and (mousePosY > scaledY)
		and (mousePosX < scaledW)
		and (mousePosY < scaledH);
end

getGrade = function(score)
	for _, breakpoint in ipairs(CONSTANTS_SONGWHEEL.grades) do
		if (score >= breakpoint.minimum) then
			return breakpoint.grade;
		end
	end
end

local roomCreation = DialogWindow.New(CONSTANTS_MULTI.dialog.roomCreation);
local passwordCreation = DialogWindow.New(CONSTANTS_MULTI.dialog.passwordCreation);
local passwordRequired = DialogWindow.New(CONSTANTS_MULTI.dialog.passwordRequired);
local usernameCreation = DialogWindow.New(CONSTANTS_MULTI.dialog.usernameCreation);

local roomList = {
	alpha = 0,
	cache = { scaledW = 0, scaledH = 0 },
	currentPage = 1,
	cursor = Cursor.New(),
	images = {
		button = New.Image({ path = 'buttons/normal.png' }),
		buttonHover = New.Image({ path = 'buttons/normal_hover.png' }),
	},
	info = nil,
	labels = nil,
	order = {
		'name',
		'capacity',
		'password',
		'status',
	},
	list = {
		margin = 0,
		padding = 0,
		spacing = 0,
		timer = 0,
		w = 0,
		h = { base = 0, item = 0 },
		x = 0,
		y = {
			base = 0,
			current = 0,
			previous = 0,
		},
	},
	roomCount = 0,
	scrollbar = Scrollbar.New(),
	text = {},
	timer = 0,
	viewLimit = 5,
	x = 0,
	y = 0,

	setSizes = function(self)
		if ((self.cache.scaledW ~= scaledW) or (self.cache.scaledH ~= scaledH)) then
			self.x = scaledW / 20;
			self.y = scaledH / 20;

			self.list.w = scaledW / 1.75;
			self.list.h.base = scaledH - (scaledH / 3);

			self.list.h.item = self.list.h.base // 6.5;

			self.list.padding = self.list.h.item // 4;
			self.list.spacing = (self.list.w - (self.list.padding * 2)) / 8;
			self.list.margin = (self.list.h.base - (self.list.h.item * self.viewLimit))
				/ (self.viewLimit - 1);

			self.list.x = (scaledW / 2) - (self.list.w / 2);
			self.list.y.base = scaledH / 6;

			self.text[1] = 0;
			self.text[2] = self.list.spacing * 3.5;
			self.text[3] = self.list.spacing * 5;
			self.text[4] = self.list.spacing * 6.5;

			self.cursor:setSizes({
				x = self.list.x,
				y = self.list.y.base,
				w = self.list.w,
				h = self.list.h.item,
				margin = self.list.margin,
			});

			if (#allRooms > self.viewLimit) then
				self.scrollbar:setSizes({
					screenW = scaledW,
					y = self.list.y.base,
					h = self.list.h.base,
				});
			end

			self.cache.scaledW = scaledW;
			self.cache.scaledH = scaledH;
		end
	end,

	setLabels = function(self)
		if (not self.labels) then
			self.labels = {
				createRoom = New.Label({
					font = 'medium',
					text = 'CREATE ROOM',
					size = 18,
				}),
			};

			self.labels.heading = New.Label({
				font = 'normal',
				text = 'MULTIPLAYER ROOMS',
				size = 60,
			});
		end
	end,

	setInfo = function(self)
		if (#allRooms ~= self.roomCount) then
			self.info = {};

			for i, room in ipairs(allRooms) do
				self.info[i] = {
					capacity = string.format('%d  /  %d', room.current, room.max),
					name = string.upper(room.name),
					password = (room.password and 'YES') or 'NO',
					status = (room.ingame and 'IN GAME') or 'IN LOBBY',
				};
			end

			self.roomCount = #allRooms;
		end
	end,

	drawButton = function(self)
		local x = (scaledW / 2) - (self.images.button.w / 2);
		local y = scaledH - (scaledH / 20) - self.images.button.h;
		local allowAction = mouseClipped(
			x,
			y,
			self.images.button.w,
			self.images.button.h
		) and (screenState == 'roomList');

		gfx.Save();

		gfx.BeginPath();

		if (allowAction) then
			hoveredButton = createRoom;

			drawImage({
				x = x,
				y = y,
				image = self.images.buttonHover,
			});
		else
			drawImage({
				x = x,
				y = y,
				alpha = 0.45,
				image = self.images.button,
			});
		end

		drawLabel({
			x = x + 40,
			y = y + 25,
			alpha = (allowAction and 255) or 50,
			color = 'white',
			label = self.labels.createRoom,
		});

		gfx.Restore();
	end,

	drawRoomList = function(self, deltaTime)
		if (self.list.timer < 1) then
			self.list.timer = math.min(self.list.timer + (deltaTime * 4), 1);
		end

		local change = (self.list.y.current - self.list.y.previous)
			* smoothstep(self.list.timer);
		local offset = self.list.y.previous + change;
		local y = 0;

		self.list.y.previous = offset;

		gfx.Save();

		gfx.Translate(self.list.x, self.list.y.base + offset);

		for i = 1, #allRooms do
			y = y + self:drawRoom(i, y);
		end

		gfx.Restore();
	end,

	drawRoom = function(self, roomIndex, initialY)
		if (not allRooms[roomIndex]) then return end

		local isVisible = List.isVisible(
			roomIndex,
			self.viewLimit,
			self.currentPage
		);
		local x = self.list.padding;
		local y = initialY + self.list.padding;

		if (isVisible) then
			drawRectangle({
				x = 0,
				y = initialY,
				w = self.list.w,
				h = self.list.h.item,
				alpha = 120,
				color = 'dark',
			});

			gfx.BeginPath();
			alignText('left');

			for i, name in ipairs(self.order) do
				loadFont('medium');
				gfx.FontSize(18);

				setFill('dark', 255 * 0.5);
				gfx.Text(string.upper(name), x + self.text[i] + 1, y + 1);

				setFill('normal');
				gfx.Text(string.upper(name), x + self.text[i], y);

				local infoY = ((name == 'capacity') and (y + 24)) or (y + 28);

				if (name == 'capacity') then
					loadFont('number');
					gfx.FontSize(30);
				else
					loadFont('normal');
					gfx.FontSize(24);
				end

				setFill('dark', 255 * 0.5);
				gfx.Text(self.info[roomIndex][name], x + self.text[i] + 1, infoY + 1);

				setFill('white');
				gfx.Text(self.info[roomIndex][name], x + self.text[i], infoY);
			end
		end

		return self.list.h.item + self.list.margin;
	end,

	handleChange = function(self)
		if (selectedRoomIndex > #allRooms) then
			selectedRoomIndex = 1;
		elseif (selectedRoomIndex < 1) then
			selectedRoomIndex = #allRooms;
		end

		if (self.selectedRoomIndex ~= selectedRoomIndex) then
			self.selectedRoomIndex = selectedRoomIndex;

			self.currentPage = List.getCurrentPage({
				current = self.selectedRoomIndex,
				limit = self.viewLimit,
				total = #allRooms,
			});
	
			self.list.y.current = (self.list.h.base + self.list.margin)
				* (self.currentPage - 1);
			self.list.y.current = -self.list.y.current;
	
			self.list.timer = 0;

			self.cursor:setPosition({
				current = self.selectedRoomIndex,
				total = self.viewLimit,
				vertical = true,
			});

			self.cursor.timer.flicker = 0;
	
			self.scrollbar:setPosition({
				current = self.selectedRoomIndex,
				total = #allRooms,
			});
		end
	end,

	render = function(self, deltaTime)
		if (screenState ~= 'roomList') then
			self.timer = math.min(self.timer + (deltaTime * 8), 1);
		else
			if (self.timer > 0) then
				self.timer = math.max(self.timer - (deltaTime * 6), 0);
			end
		end

		self.alpha = 255 - (180 * self.timer);

		self:setLabels();

		self:setSizes();

		self:setInfo();

		gfx.Save();

		drawLabel({
			x = self.x,
			y = self.y,
			alpha = self.alpha,
			color = 'white',
			label = self.labels.heading,
		});

		if (#allRooms > 0) then
			self:drawRoomList(deltaTime);

			if (screenState == 'roomList') then
				self.cursor:render(deltaTime, {
					size = 16,
					stroke = 1.5,
					vertical = true,
				});

				if (#allRooms > self.viewLimit) then
					self.scrollbar:render(deltaTime);
				end
			end
		end

		if (not isLoading) then
			self:drawButton();
		end

		self:handleChange();

		drawRectangle({
			x = 0,
			y = 0,
			w = scaledW,
			h = scaledH,
			alpha = 170 * self.timer,
			color = 'black',
		});

		gfx.Restore();
	end,
};

local songInfo = {
	cache = { scaledW = 0, scaledH = 0 },
	cursor = {
    alpha = 0,
    flickerTimer = 0,
    selected = 0,
    timer = 0,
    x = 0,
    y = {},
  },
	difficulties = nil,
	images = {
    button = New.Image({ path = 'buttons/short.png' }),
    buttonHover = New.Image({ path = 'buttons/short_hover.png' }),
    panel = New.Image({ path = 'common/panel.png' }),
	},
	jacketSize = 0,
	labels = nil,
	levels = nil,
	order = {
		'title',
		'artist',
		'effector',
		'bpm',
	},
	padding = {
		x = {
			double = 0,
			full = 0,
			half = 0,
			quarter = 0,
		},
		y = {
			double = 0,
			full = 0,
			half = 0,
			quarter = 0,
		},
	},
  panel = {
		centerX = 0,
    w = 0,
    h = 0,
    x = 0,
    y = 0,
  },
	scrollTimers = {
    artist = 0,
    effector = 0,
    title = 0,
	},
	selectedDifficulty = nil,
	songInfo = nil,
	toggles = {
		spacing = 0,
	},

	setSizes = function(self)
    if ((self.cache.scaledW ~= scaledW) or (self.cache.scaledH ~= scaledH)) then
      self.jacketSize = scaledW / 5;

      self.panel.w = scaledW / (scaledW / self.images.panel.w);
      self.panel.h = scaledH - (scaledH / 10);
      self.panel.x = scaledW / 20;
      self.panel.y = scaledH / 20;
      self.panel.centerX = self.panel.w / 2;

      self.padding.x.full = self.panel.w / 20;
      self.padding.x.double = self.padding.x.full * 2;
      self.padding.x.half = self.padding.x.full / 2;
      self.padding.x.quarter = self.padding.x.full / 4;

      self.padding.y.full = self.panel.h / 20;
      self.padding.y.double = self.padding.y.full * 2;
      self.padding.y.half = self.padding.y.full / 2;
      self.padding.y.quarter = self.padding.y.full / 4;

			self.cursor.x = self.padding.x.double + self.jacketSize + self.padding.x.full - 6;
			self.cursor.y = {};

      self.panel.innerWidth = self.panel.w - (self.padding.x.double * 2);

      self.labels.x = self.padding.x.double;
			self.labels.y = self.padding.y.double + self.jacketSize;
			
			local maxWidth = scaledW - ((scaledW / 20) * 3) - self.panel.w;

			self.toggles.spacing = (maxWidth
				- (32 * 3)
				- self.labels.rotateHost.w
				- self.labels.hardGauge.w
				- self.labels.mirrorMode.w
			) / 2;

      self.cache.scaledW = scaledW;
      self.cache.scaledH = scaledH;
    end
	end,
	
	setLabels = function(self)
		if (not self.labels) then
			self.difficulties = {};
			self.levels = {};
			self.songInfo = {};

			for i = 1, 4 do
				self.levels[i] = New.Label({
					font = 'number',
					text = '0',
					size = 18,
				});
			end

			self.songInfo.bpm = New.Label({
				font = 'number',
				text = '000',
				size = 24,
			});

			self.labels = {
				hardGauge = New.Label({
					font = 'medium',
					text = 'HARD GAUGE',
					size = 20,
				}),
				mirrorMode = New.Label({
					font = 'medium',
					text = 'MIRROR MODE',
					size = 20,
				}),
				rotateHost = New.Label({
					font = 'medium',
					text = 'ROTATE HOST',
					size = 20,
				}),
			};

			for name, label in pairs(CONSTANTS_SONGWHEEL.labels.info) do
				self.labels[name] = New.Label({
					font = 'medium',
					text = label,
					size = 18,
				});
			end

			for i, difficulty in ipairs(CONSTANTS_SONGWHEEL.difficulties) do
				self.difficulties[i] = New.Label({
					font = 'medium',
					text = difficulty,
					size = 18,
				});
			end

			self.labels.disabled = New.Label({
				font = 'normal',
				text = 'DISABLED',
				size = 24,
			});
			self.labels.enabled = New.Label({
				font = 'normal',
				text = 'ENABLED',
				size = 24,
			});
			self.labels.hard = New.Label({
				font = 'normal',
				text = 'HARD',
				size = 24,
			});
			self.labels.normal = New.Label({
				font = 'normal',
				text = 'NORMAL',
				size = 24,
			});

			self.songInfo.artist = New.Label({
				font = 'jp',
				text = 'ARTIST',
				size = 36,
			});
			self.songInfo.title = New.Label({
				font = 'jp',
				text = 'TITLE',
				size = 36,
			});
			self.songInfo.effector = New.Label({
				font = 'jp',
				text = 'EFFECTOR',
				size = 24,
			});
		end
	end,

	setDifficulty = function(self, newDifficulty)
		if (self.selectedDifficulty ~= newDifficulty) then
			self.cursor.flickerTimer = 0;

			self.selectedDifficulty = newDifficulty;
		end
	end,

	getDifficulty = function(self, difficulties, index)
		local difficultyIndex = nil;
	
		for i, v in pairs(difficulties) do
			if ((v.difficulty + 1) == index) then
				difficultyIndex = i;
			end
		end
	
		local difficulty = nil;
	
		if (difficultyIndex) then
			difficulty = difficulties[difficultyIndex];
		end
	
		return difficulty;
	end,

	drawLabels = function(self)
		local baseHeight = self.labels.title.h;
		local y = self.labels.y - 4;

		gfx.Save();

		drawLabel({
			x = self.padding.x.double + self.jacketSize + self.padding.x.full + 6,
			y = self.padding.y.full - 4,
			color = 'normal',
			label = self.labels.difficulty,
		});

		for _, name in ipairs(self.order) do
			drawLabel({
				x = self.labels.x,
				y = y,
				color = 'normal',
				label = self.labels[name],
			});

			y = y
				+ baseHeight
				+ self.padding.y.quarter
				+ self.songInfo[name].h
				+ self.padding.y.half
				- 4;
		end

		gfx.Restore();
	end,

	drawButton = function(self, x, y, a, enabled, action, clickAllowed)
		drawRectangle({
			x = x,
			y = y,
			w = 24,
			h = 24,
			alpha = 255 * a,
			color = (enabled and { 255, 205, 0 }) or 'dark',
			stroke = {
				alpha = 255 * a,
				color = 'normal',
				size = (enabled and 2) or 1,
			},
		});

		if (clickAllowed and mouseClipped(x, y, 24, 24)) then
			hoveredButton = action;
		end
	end,

	drawCursor = function(self, deltaTime, y)
    gfx.Save();

    self.cursor.timer = self.cursor.timer + deltaTime;
    self.cursor.flickerTimer = self.cursor.flickerTimer + deltaTime;

    self.cursor.alpha = math.floor(self.cursor.flickerTimer * 30) % 2;
    self.cursor.alpha = (self.cursor.alpha * 255) / 255;

    if (self.cursor.flickerTimer >= 0.3) then
      self.cursor.alpha = math.abs(0.8 * math.cos(self.cursor.timer * 5)) + 0.2;
    end

    gfx.BeginPath();

		drawCursor({
			x = self.cursor.x + 10,
			y = y + 10,
			w = self.images.button.w - 20,
			h = self.images.button.h - 20,
			alpha = self.cursor.alpha,
			size = 12,
			stroke = 1.5,
		});

    gfx.Restore();
  end,

	drawDifficulty = function(self, currentDifficulty, isSelected, y, i)
		local x = self.cursor.x;
		local alpha = math.floor(255 * ((isSelected and 1) or 0.2));

		gfx.Save();

		if (isSelected) then
			drawImage({
				x = x,
				y = y,
				image = self.images.buttonHover,
			});
		else
			drawImage({
				x = x,
				y = y,
				alpha = 0.45,
				image = self.images.button,
			});
		end

		if (currentDifficulty) then
			local difficultyIndex = getDifficultyIndex(
				currentDifficulty.jacketPath,
				currentDifficulty.difficulty
			);
			
      self.levels[i]:update({
        new = string.format('%02d', currentDifficulty.level)
      });

			drawLabel({
				x = x + 36,
				y = y + (self.images.button.h / 2.85),
				alpha = alpha,
				color = 'white',
				label = self.difficulties[difficultyIndex],
			});

			drawLabel({
				x = x + self.images.button.w - 36,
				y = y + (self.images.button.h / 2.85),
				align = 'right',
				alpha = alpha,
				color = 'white',
				label = self.levels[i],
			});
		end

		gfx.Restore();

		return (y + self.images.button.h + 6);
	end,

	drawJacket = function(self)
		if (not jacket) then
			jacket = jacketFallback;
		end

		if ((not selected_song.jacket) or (selected_song.jacket == jacketFallback)) then
			jacket = gfx.LoadImageJob(
				selected_song.jacketPath,
				jacketFallback,
				self.jacketSize,
				self.jacketSize
			);
		end

		gfx.Save();

		drawRectangle({
			x = self.padding.x.double,
			y = self.padding.y.full,
			w = self.jacketSize,
			h = self.jacketSize,
			image = jacket,
			stroke = { color = 'normal', size = 2 },
		});

		gfx.Restore();
	end,

	drawSongInfo = function(self, deltaTime)
		local baseHeight = self.labels.title.h;
		local y = self.labels.y + baseHeight + self.padding.y.quarter - 8;

		self.songInfo.artist:update({ new = string.upper(selected_song.artist) });
		self.songInfo.effector:update({ new = string.upper(selected_song.effector)} );
		self.songInfo.title:update({ new = string.upper(selected_song.title) });

		self.songInfo.bpm:update({ new = selected_song.bpm });

		gfx.Save();

		for _, name in pairs(self.order) do
			local doesOverflow = self.songInfo[name].w > self.panel.innerWidth;

			if (doesOverflow and self.scrollTimers[name]) then
				self.scrollTimers[name] = self.scrollTimers[name] + deltaTime;

				drawScrollingLabel({
					x = self.labels.x,
					y = y,
					alpha = 255,
					color = 'white',
					label = self.songInfo[name],
					scale = scalingFactor,
					timer = self.scrollTimers[name],
					width = self.panel.innerWidth,
				});
			else
				drawLabel({
					x = self.labels.x,
					y = y - 1,
					color = 'white',
					label = self.songInfo[name],
				});
			end

			y = y
				+ self.songInfo[name].h
				+ self.padding.y.half
				+ baseHeight
				+ self.padding.y.quarter
				- 4;
		end

		gfx.Restore();
	end,

	drawSongInfoPanel = function(self, deltaTime)
		gfx.Save();

		gfx.Translate(self.panel.x, self.panel.y);

		drawImage({
			x = 0,
			y = 0,
			alpha = 0.5,
			image = self.images.panel,
		});

		self:drawLabels();

		if (selected_song) then
			self:drawJacket();

			self:drawSongInfo(deltaTime);

			self:setDifficulty(selected_song.difficulty);

			local y = self.padding.y.double + self.labels.difficulty.h - 24;

			for i = 1, 4 do
				local currentDifficulty = self:getDifficulty(
					selected_song.all_difficulties,
					i
				);
				local isSelected = (i - 1) == selected_song.difficulty;

				if (isSelected) then
					self.cursor.selected = i;
				end

				if (not self.cursor.y[i]) then
					self.cursor.y[i] = y;
				end

				y = self:drawDifficulty(currentDifficulty, isSelected, y, i);
			end

			self:drawCursor(deltaTime, self.cursor.y[self.cursor.selected]);
		end

		gfx.Restore();
	end,

	drawToggles = function(self)
		local x = (scaledW / 10) + self.panel.w;
		local y = scaledH - (scaledH / 20) + (self.labels.hardGauge.h - 4);

		gfx.Save();

		self:drawButton(x, y + 1, 1, hardGauge, toggleHard, not isStartingGame);

		drawLabel({
			x = x + 32,
			y = y,
			color = 'white',
			label = self.labels.hardGauge,
		});

		x = x + 32 + self.labels.hardGauge.w + self.toggles.spacing;

		self:drawButton(x, y + 1, 1, mirrorMode, toggleMirror, not isStartingGame);

		drawLabel({
			x = x + 32,
			y = y,
			color = 'white',
			label = self.labels.mirrorMode,
		});

		x = x + 32 + self.labels.rotateHost.w + self.toggles.spacing;

		self:drawButton(
			x,
			y + 1,
			((host == userId) and 1) or 0.2,
			rotateHost,
			toggleRotate,
			(host == userId) and (not isStartingGame)
		);

		drawLabel({
			x = x + 32,
			y = y,
			alpha = ((host == userId) and 255) or 50,
			color = 'white',
			label = self.labels.rotateHost,
		});

		gfx.Restore();
	end,

	render = function(self, deltaTime)
		self:setLabels();

		self:setSizes();

		gfx.Save();

		self:drawSongInfoPanel(deltaTime);

		self:drawToggles();

		gfx.Restore();
	end
};

local lobby = {
	cache = { scaledW = 0, scaledH = 0 },
	images = {
		buttonM = New.Image({ path = 'buttons/medium.png' }),
		buttonMHover = New.Image({ path = 'buttons/medium_hover.png' }),
		buttonN = New.Image({ path = 'buttons/normal.png' }),
		buttonNHover = New.Image({ path = 'buttons/normal_hover.png' }),
	},
	button = {
		spacing = 0,
		x = 0,
		y = {},
	},
	order = {
		'player',
		'level',
		'grade',
		'clear',
		'score',
	},
	timer = 0,
	user = {
		spacing = {
			inner = 0,
			outer = 0,
		},
		w = 0,
		h = 0,
		x = {},
	},
	userCount = 0,
	userInfo = {},
	x = 0,
	y = 0,

	setSizes = function(self)
		if ((self.cache.scaledW ~= scaledW) or (self.cache.scaledH ~= scaledH)) then
			self.x = (scaledW / 10) + songInfo.panel.w;
			self.y = scaledH / 20;

			local maxWidth = scaledW - ((scaledW / 20) * 3) - songInfo.panel.w;
			local maxHeight = scaledH - (scaledH / 10);

			self.user.w = maxWidth;
			self.user.h = scaledH / 10;
			self.user.spacing.inner = maxWidth / 20;
			self.user.spacing.outer = (maxHeight - (self.user.h * 8)) / 7;

			local spacing = maxWidth / 12;

			self.user.x[1] = self.x + 24;
			self.user.x[2] = self.x + spacing * 4;
			self.user.x[3] = self.x + spacing * 5.25
			self.user.x[4] = self.x + spacing * 7;
			self.user.x[5] = self.x + spacing * 9.375;
			

			self.button.x = (scaledW / 20) + songInfo.padding.x.double - 10;
			self.button.y[1] = scaledH
				- (scaledH / 20)
				- (songInfo.padding.y.double * 1.75)
				- 10;
			self.button.y[2] = self.button.y[1] + self.images.buttonM.h;
			
      self.cache.scaledW = scaledW;
      self.cache.scaledH = scaledH;
    end
	end,

	setLabels = function(self)
		if (not self.labels) then
			self.labels = {};

			for name, label in pairs(CONSTANTS_MULTI.buttons) do
				self.labels[name] = New.Label({
					font = 'medium',
					text = label,
					size = 18,
				});
			end

			for name, label in pairs(CONSTANTS_MULTI.user) do
				self.labels[name] = New.Label({
					font = 'medium',
					text = label,
					size = 18,
				});
			end
		end
	end,

	setUserInfo = function(self)
		if (#allUsers ~= self.userCount) then
			for i = 1, #allUsers do
				self.userInfo[i] = {
					clear = New.Label({
						font = 'normal',
						text = '',
						size = 30,
					}),
					grade = New.Label({
						font = 'normal',
						text = '',
						size = 30,
					}),
					player = New.Label({
						font = 'normal',
						text = '',
						size = 30,
					}),
				};

				self.userInfo[i].level = New.Label({
					font = 'number',
					text = '0',
					size = 30,
				});
				self.userInfo[i].score = ScoreNumber.New({
					isScore = true,
					sizes = { 30, 26 },
				});
			end

			self.userCount = #allUsers;
		end
	end,

	updateLabels = function(self, i, currentUser)
		self.userInfo[i].player:update({ new = string.upper(currentUser.name) });
		
		if (currentUser.level ~= 0) then
			self.userInfo[i].level:update({ new = currentUser.level });
		end

		if (currentUser.score) then
			self.userInfo[i].clear:update({
				new = CONSTANTS_SONGWHEEL.clears[currentUser.clear]
			});

			self.userInfo[i].grade:update({ new = getGrade(currentUser.score) });

			self.userInfo[i].score:setInfo({ value = currentUser.score });
		end
	end,

	drawButtons = function(self)
		local action;
		local allowAction = true;
		local isHoveringMain = mouseClipped(
			self.button.x,
			self.button.y[1],
			self.images.buttonM.w,
			self.images.buttonM.h
		);
		local isHoveringSettings = mouseClipped(
			self.button.x,
			self.button.y[2],
			self.images.buttonM.w,
			self.images.buttonM.h
		);
		local label;

		if (isStartingGame) then
			label = 'startingGame';

			return;
		else
			if (host == userId) then
				if ((not selected_song) or (not selected_song.self_picked)) then
					action = function()
						isMissingSong = false;

						mpScreen.SelectSong();
					end

					label = 'selectSong';
				elseif (userReady and allReady) then
					action = startGame;
					label = 'startGame';
				elseif (userReady and (not allReady)) then
					action = function()
						isMissingSong = false;

						mpScreen.SelectSong();
					end

					label = 'playersNotReady';
				else
					action = readyUp;
					label = 'readyUp';
				end
			elseif (host == nil) then
				action = function() end
				allowAction = false;
				label = 'gameInProgress';
			elseif (isMissingSong) then
				action = function() end
				allowAction = false;
				label = 'songMissing';
			elseif (selected_song) then
				if (userReady) then
					action = readyUp;
					label = 'cancel';
				else
					action = readyUp;
					label = 'readyUp';
				end
			else
				action = function() end
				allowAction = false;
				label = 'hostSelecting';
			end
		end

		gfx.Save();

		if (allowAction and isHoveringMain) then
			hoveredButton = action;

			drawImage({
				x = self.button.x,
				y = self.button.y[1],
				image = self.images.buttonMHover,
			});
		else
			drawImage({
				x = self.button.x,
				y = self.button.y[1],
				alpha = 0.75,
				image = self.images.buttonM,
			});
		end

		drawLabel({
			x = self.button.x + 44,
			y = self.button.y[1] + 25,
			alpha = ((allowAction and isHoveringMain) and 255) or 150,
			color = 'white',
			label = self.labels[label],
		});

		if (isHoveringSettings) then
			hoveredButton = mpScreen.OpenSettings;

			drawImage({
				x = self.button.x,
				y = self.button.y[2],
				image = self.images.buttonMHover,
			});
		else
			drawImage({
				x = self.button.x,
				y = self.button.y[2],
				alpha = 0.75,
				image = self.images.buttonM,
			});
		end

		drawLabel({
			x = self.button.x + 44,
			y = self.button.y[2] + 25,
			alpha = (isHoveringSettings and 255) or 150,
			color = 'white',
			label = self.labels.settings,
		});

		gfx.Restore();
	end,

	drawHostControls = function(self, initialY, currentUser)
		local x1 = self.x + (self.user.w / 2) - (self.images.buttonN.w) - 32;
		local x2 = self.x + (self.user.w / 2) + 32;
		local y = initialY + (self.user.h / 2) - (self.images.buttonN.h / 2);
		local isHoveringHost = mouseClipped(
			x1,
			y,
			self.images.buttonN.w,
			self.images.buttonN.h
		);
		local isHoveringKick = mouseClipped(
			x2,
			y,
			self.images.buttonN.w,
			self.images.buttonN.h
		);

		drawRectangle({
			x = self.x,
			y = initialY,
			w = self.user.w,
			h = self.user.h,
			alpha = 120,
			color = 'dark',
		});

		if (isHoveringHost) then
			hoveredButton = function()
				changeHost(currentUser);
			end
		
			drawImage({
				x = x1,
				y = y,
				image = self.images.buttonNHover,
			});
		else
			drawImage({
				x = x1,
				y = y,
				alpha = 0.75,
				image = self.images.buttonN,
			});
		end

		drawLabel({
			x = x1 + 40,
			y = y + 25,
			alpha = (isHoveringHost and 255) or 150,
			color = 'white',
			label = self.labels.makeHost,
		});

		if (isHoveringKick) then
			hoveredButton = function()
				kickUser(currentUser);
			end
		
			drawImage({
				x = x2,
				y = y,
				image = self.images.buttonNHover,
			});
		else
			drawImage({
				x = x2,
				y = y,
				alpha = 0.75,
				image = self.images.buttonN,
			});
		end

		drawLabel({
			x = x2 + 40,
			y = y + 25,
			alpha = (isHoveringKick and 255) or 150,
			color = 'white',
			label = self.labels.kickUser,
		});
	end,

	drawUser = function(self, initialY, userIndex, currentUser)
		local isHost = (host == userId) and (currentUser.id ~= userId);
		local isHoveringUser = mouseClipped(self.x, initialY, self.user.w, self.user.h);

		if (isHost and isHoveringUser) then
			self:drawHostControls(initialY, currentUser);
		else
			local y = initialY + (self.user.h / 5);
			local infoY = y + (self.labels.notReady.h * 1.25);
			local nameLabel = 'notReady';

			if (host == currentUser.id) then
				nameLabel = 'host';
			elseif (currentUser.missing_map) then
				nameLabel = 'missingSong';
			elseif (currentUser.ready) then
				nameLabel = 'ready';
			else
				nameLabel = 'notReady';
			end

			self:updateLabels(userIndex, currentUser);

			gfx.Save();

			drawRectangle({
				x = self.x,
				y = initialY,
				w = self.user.w,
				h = self.user.h,
				alpha = 120,
				color = (currentUser.missing_map and { 48, 8, 8 })
					or (currentUser.ready and { 16, 48, 24 })
					or 'dark',
			});

			drawLabel({
				x = self.user.x[1],
				y = y,
				color = 'normal',
				label = self.labels[nameLabel],
			});

			drawLabel({
				x = self.user.x[1],
				y = infoY,
				color = 'white',
				label = self.userInfo[userIndex].player,
			});

			if (get(currentUser, 'level') ~= 0) then
				drawLabel({
					x = self.user.x[2],
					y = y,
					color = 'normal',
					label = self.labels.level,
				});

				drawLabel({
					x = self.user.x[2],
					y = infoY,
					color = 'white',
					label = self.userInfo[userIndex].level,
				});
			end

			if (currentUser.score) then
				for i = 3, 5 do
					local label = self.order[i];

					drawLabel({
						x = self.user.x[i],
						y = y,
						color = 'normal',
						label = self.labels[label],
					});

					if (i == 5) then
						self.userInfo[userIndex].score:draw({
							x = self.user.x[i],
							y1 = infoY,
							y2 = infoY + 4,
							offset = 2,
						});
					else
						drawLabel({
							x = self.user.x[i],
							y = infoY,
							color = 'white',
							label = self.userInfo[userIndex][label],
						});
					end
				end
			end

			gfx.Restore();
		end

		return self.user.h + self.user.spacing.outer;
	end,

	render = function(self, deltaTime)
		self:setLabels();

		local y = self.y;

		gfx.Save();

		songInfo:render(deltaTime, self.timer);

		self:setSizes();

		if (#allUsers > 0) then
			self:setUserInfo();

			for i, user in ipairs(allUsers) do
				y = y + self:drawUser(y, i, user);
			end
		end

		self:drawButtons();

		gfx.Restore();
	end,
};

handleTimers = function(deltaTime)
	if (screenState == 'setUsername') then
		usernameCreation.timer = math.min(usernameCreation.timer + (deltaTime * 8), 1);
	else
		usernameCreation.timer = 0;
	end

	if (screenState == 'newRoomName') then
		roomCreation.timer = math.min(roomCreation.timer + (deltaTime * 8), 1);
	elseif ((screenState ~= 'newRoomName') and (roomCreation.timer > 0)) then
		roomCreation.timer = math.max(roomCreation.timer - (deltaTime * 6), 0);
	end

	if ((screenState == 'newRoomPassword') and (roomCreation.timer == 0)) then
		passwordCreation.timer = math.min(passwordCreation.timer + (deltaTime * 8), 1);

		previousWindow = 'newRoomPassword'
	elseif ((screenState ~= 'newRoomPassword') and (passwordCreation.timer > 0)) then
		passwordCreation.timer = math.max(passwordCreation.timer - (deltaTime * 6), 0);
	end

	if (screenState == 'passwordScreen') then
		passwordRequired.timer = math.min(passwordRequired.timer + (deltaTime * 8), 1);

		previousWindow = 'passwordScreen';
	elseif ((screenState ~= 'passwordScreen') and (passwordRequired.timer > 0)) then
		passwordRequired.timer = math.max(passwordRequired.timer - (deltaTime * 6), 0);
	end
end

render = function(deltaTime)
	gfx.Save();

	setupLayout();

	mousePosX, mousePosY = game.GetMousePos();

	hoveredButton = nil;

	playSounds(deltaTime);

	drawImage({
		x = 0,
		y = 0,
		w = scaledW,
		h = scaledH,
		image = background,
	});

	if (screenState == 'setUsername') then
		isLoading = false;

		usernameCreation:render(deltaTime, scaledW, scaledH);
	elseif (screenState ~= 'inRoom') then
		roomList:render(deltaTime);
	elseif (screenState == 'inRoom') then
		lobby:render(deltaTime);
	end

	roomCreation:render(deltaTime, scaledW, scaledH);
	passwordCreation:render(deltaTime, scaledW, scaledH);
	passwordRequired:render(deltaTime, scaledW, scaledH);

	if ((screenState == 'roomList') and (#allRooms > 1)) then
		selectedRoomIndex = Controller:handleInput({
			current = selectedRoomIndex,
			total = #allRooms,
		});
	end

	handleTimers(deltaTime);

	gfx.Restore();
end

local soundDuration = 0;
local soundClip = nil;
local soundsRemaining = 0;
local soundInterval = 0;

function repeatSound(clip, times, interval)
	soundClip = clip;
	soundDuration = 0;
	soundsRemaining = times - 1;
	soundInterval = interval;

	game.PlaySample(clip);
end

function playSounds(deltaTime)
	if (not soundClip) then return end

	soundDuration = soundDuration + deltaTime;

	if soundDuration > soundInterval then
		soundDuration = soundDuration - soundInterval;

		game.PlaySample(soundClip);

		soundsRemaining = soundsRemaining - 1;
		
		if (soundsRemaining <= 0) then
			soundClip = nil;
		end
	end
end

changeHost = function(user)
  Tcp.SendLine(JSON.encode({ topic = 'room.host.set', host = user.id }));
end

createRoom = function()
	host = userId;
	owner = userId;

	mpScreen.NewRoomStep();
end

joinRoom = function(room)
	host = userId;
	selectedRoom = room;

	if (room.password) then
		mpScreen.JoinWithPassword(room.id);
	else
		mpScreen.JoinWithoutPassword(room.id);
	end
end

kickUser = function(user)
  Tcp.SendLine(JSON.encode({topic = 'room.kick', id = user.id }));
end

readyUp = function()
  Tcp.SendLine(JSON.encode({ topic = 'user.ready.toggle' }));
end

startGame = function()
	selected_song.self_picked = false;

	if (not selected_song) then return end

	if (isStartingGame) then return end
	
	Tcp.SendLine(JSON.encode({ topic = 'room.game.start' }));
end

toggleHard = function()
  Tcp.SendLine(JSON.encode({ topic = 'user.hard.toggle' }));
end

toggleMirror = function()
  Tcp.SendLine(JSON.encode({ topic = 'user.mirror.toggle' }));
end

toggleRotate = function()
  Tcp.SendLine(JSON.encode({ topic = 'room.option.rotation.toggle' }));
end

button_pressed = function(button)
	if (button == game.BUTTON_STA) then
		if (isStartingGame) then return end

		if (screenState == 'setUsername') then
			isLoading = true;

			mpScreen.SaveUsername();
		elseif (screenState == 'roomList') then
			if (allRooms[selectedRoomIndex]) then
				joinRoom(allRooms[selectedRoomIndex]);
			else
				createRoom();
			end
		elseif (screenState == 'inRoom') then
			if (host == userId) then
				if (selected_song and selected_song.self_picked) then
					if (allReady) then
						startGame();
					else
						isMissingSong = false;
						
						mpScreen.SelectSong();
					end
				else
					isMissingSong = false;
					
					mpScreen.SelectSong();
				end
			else
				readyUp();
			end
		end
	end
	
	if ((button == game.BUTTON_FXL) and allowHardToggle) then
		toggleHard();
	end

	if ((button == game.BUTTON_FXR) and allowMirrorToggle) then
		toggleMirror();
	end
end

key_pressed = function(key)
	if (key == CONSTANTS_MULTI.keys.esc) then
		if (screenState == 'roomList') then
			didExit = true;

			mpScreen.Exit();

			return;
		end

		allRooms = {};
		screenState = 'roomList';
		selectedRoom = nil;
		jacket = nil;
	end

	if (screenState == 'roomList') then
		if (key == CONSTANTS_MULTI.keys.down) then
			selectedRoomIndex = selectedRoomIndex + 1;
		elseif (key == CONSTANTS_MULTI.keys.up) then
			selectedRoomIndex = selectedRoomIndex - 1;
		elseif (key == CONSTANTS_MULTI.keys.enter) then
			if (allRooms[selectedRoomIndex]) then
				joinRoom(allRooms[selectedRoomIndex]);
			else
				createRoom();
			end
		end
	end
end

mouse_pressed = function(button)
	if (hoveredButton) then
		hoveredButton();
	end

	return 0;
end

init_tcp = function()
	Tcp.SetTopicHandler('server.info',
		function(data)
			isLoading = false;
			userId = data.userid;
		end
	);

	Tcp.SetTopicHandler('server.rooms',
		function(data)
			allRooms = {};

			if (#get(data, 'rooms', {}) > 0) then
				for i, room in ipairs(data.rooms) do
					allRooms[i] = room;
				end
			end
		end
	);

	Tcp.SetTopicHandler('server.room.joined',
		function(data)
			selectedRoom = data.room;
		end
	);

	Tcp.SetTopicHandler('room.update',
		function(data)
			allUsers = {};

			local previousAllReady = allReady;

			allReady = true;
			
			if (#get(data, 'users', {}) >= 0) then
				for i, user in ipairs(data.users) do
					allUsers[i] = user;

					if (user.id == userId) then
						userReady = user.ready;
					end

					if (not user.ready) then
						allReady = false;
					end
				end
			end

			if ((userId == host)
				and (#data.users > 1)
				and allReady
				and (not previousAllReady)
			) then
				repeatSound('click-02', 3, .1);
			end

			if ((data.host == userId) and (host ~= userId)) then
				repeatSound('click-02', 3, .1);
			end

			if ((data.song ~= nil) and (previousSong ~= data.song)) then
				game.PlaySample('menu_click');
				previousSong = data.song;
			end

			host = data.host;

			if (data.owner) then
				owner = data.owner;
			else
				owner = host;
			end

			rotateHost = data.do_rotate;
			hardGauge = data.hard_mode;
			mirrorMode = data.mirror_mode;
			
			if ((data.start_soon) and (not isStartingGame)) then
				repeatSound('click-01', 5, 1);
			end

			isStartingGame = data.start_soon;
		end
	);
end
