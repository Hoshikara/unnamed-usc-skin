local CONTROL_LIST = require('constants/controls');

local _ = {
  ['buttons'] = nil,
  ['controls'] = nil,
  ['headings'] = nil,
  ['headingY'] = 0,
  ['pages'] = {
    [1] = 'general',
    [2] = 'songSelect',
    [3] = 'gameplaySettings',
    [4] = 'gameplay',
    [5] = 'results'
  },
  ['pressedBTD'] = false,
  ['scaledW'] = 0,
  ['scaledH'] = 0,
  ['selectedPage'] = 1,
  ['timer'] = 0,

  setAllSizes = function(self, scaledW, scaledH)
    self['scaledW'] = scaledW;
    self['scaledH'] = scaledH;
    self['x'] = scaledW / 20;
    self['y'] = scaledH / 20;
  end,

  setControls = function(self)
    if (not self['controls']) then
      self['controls'] = {
        ['general'] = {},
        ['songSelect'] = {},
        ['gameplaySettings'] = {},
        ['gameplay'] = {},
        ['results'] = {}
      };
    
      for category, list in pairs(self['controls']) do
        for i = 1, #CONTROL_LIST[category] do
          list[i] = {};
    
          gfx.LoadSkinFont('GothamBook.ttf');
          list[i]['action'] = cacheLabel(CONTROL_LIST[category][i]['action'], 24);
    
          gfx.LoadSkinFont('GothamMedium.ttf');
          list[i]['controller'] = cacheLabel(CONTROL_LIST[category][i]['controller'], 24);
          list[i]['keyboard'] = cacheLabel(CONTROL_LIST[category][i]['keyboard'], 24);
    
          if (CONTROL_LIST[category][i]['lineBreak']) then
            list[i]['lineBreak'] = true;
          end
        end
      end
    end
  end,

  setHeadings = function(self)
    if (not self['headings']) then
      gfx.LoadSkinFont('GothamMedium.ttf');

      self['headings'] = {
        ['main'] = cacheLabel('CONTROLS', 60),
        ['general'] = cacheLabel('GENERAL', 36),
        ['songSelect'] = cacheLabel('SONG SELECT', 36),
        ['gameplaySettings'] = cacheLabel('GAMEPLAY SETTINGS', 36),
        ['gameplay'] = cacheLabel('GAMEPLAY', 36),
        ['results'] = cacheLabel('RESULTS', 36),
        ['controller'] = cacheLabel('CONTROLLER', 30),
        ['keyboard'] = cacheLabel('KEYBOARD', 30),
        ['btd'] = cacheLabel('[BT-D]', 24),
        ['next'] = cacheLabel('NEXT PAGE', 24),
        ['maxWidth'] = 0
      };
    end
  end,

  drawControls = function(self, list, initialX, initialY)
    local alpha = math.floor(255 * self['timer']);
    local x = initialX;
    local y = initialY;

    gfx.BeginPath();
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP);
    gfx.FillColor(255, 255, 255, alpha);

    self['headings']['controller']:draw({
      ['x'] = x,
      ['y'] = y
    });
    self['headings']['keyboard']:draw({
      ['x'] = x + 350,
      ['y'] = y
    });

    y = y + 60;

    for i = 1, #list do
      gfx.FillColor(60, 110, 160, alpha);
      list[i]['controller']:draw({
        ['x'] = x,
        ['y'] = y
      });

      list[i]['keyboard']:draw({
        ['x'] = x + 350, 
        ['y'] = y
      });

      gfx.FillColor(255, 255, 255, alpha);
      list[i]['action']:draw({
        ['x'] = x + 700,
        ['y'] = y
      });

      if ((i ~= #list) and (not list[i]['lineBreak'])) then
        gfx.BeginPath();
        gfx.FillColor(60, 110, 160, math.floor(100 * self['timer']));
        gfx.FastRect(x + 1, y + 38, self['scaledW'] / 1.65, 2);
        gfx.Fill();
      end

      if (list[i]['lineBreak']) then
        y = y + 90;
      else
        y = y + 45;
      end
    end
  end,

  drawHeading = function(self, x, y, page, isActive)
    local heading = self['headings'][page];
    local r = (isActive and 60) or 255;
    local g = (isActive and 110) or 255;
    local b = (isActive and 160) or 255;
    local a = (isActive and math.floor(255 * self['timer'])) or math.floor(80 * self['timer']);

    gfx.BeginPath();
    gfx.FillColor(r, g, b, a);
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP);
    heading:draw({
      ['x'] = x,
      ['y'] = y
    });

    if (heading['w'] > self['headings']['maxWidth']) then
      self['headings']['maxWidth'] = heading['w'];
    end

    return (heading['h'] * 2);
  end,

  drawScreen = function(self)
    local alpha = math.floor(255 * self['timer']);

    gfx.BeginPath()
    gfx.FillColor(0, 0, 0, math.floor(235 * self['timer']));
    gfx.FastRect(0, 0, self['scaledW'], self['scaledH']);
    gfx.Fill();

    gfx.Save();

    gfx.Translate(self['x'], self['y']);

    gfx.BeginPath();
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP);
    gfx.FillColor(255, 255, 255, alpha);
    self['headings']['main']:draw({
      ['x'] = -3,
      ['y'] = 0
    });

    self['headingY'] = self['headings']['main']['h'] * 2;

    for category = 1, #self['pages'] do
      self['headingY'] = self['headingY'] + self:drawHeading(
        0,
        self['headingY'],
        self['pages'][category],
        category == self['selectedPage']
      );
    end

    gfx.BeginPath();
    gfx.FillColor(255, 255, 255, alpha);
    gfx.FastRect(
      self['headings']['maxWidth'] + 75,
      (self['headings']['main']['h'] * 2) + 10,
      4,
      self['scaledH'] / 3
    );
    gfx.Fill();

    self:drawControls(
      self['controls'][self['pages'][self['selectedPage']]],
      self['headings']['maxWidth'] + 150,
      self['headings']['main']['h'] * 2
    );

    gfx.BeginPath();
    gfx.TextAlign(gfx.TEXT_ALIGN_LEFT + gfx.TEXT_ALIGN_TOP);
    gfx.FillColor(60, 110, 160, alpha);
    self['headings']['btd']:draw({
      ['x'] = 0,
      ['y'] = self['scaledH'] - (self['scaledH'] / 7)
    });

    gfx.FillColor(255, 255, 255, alpha);
    self['headings']['next']:draw({
      ['x'] = self['headings']['btd']['w'] + 8,
      ['y'] = self['scaledH'] - (self['scaledH'] / 7)
    });

    gfx.Restore();
  end,

  render = function(self, deltaTime, displaying, scaledW, scaledH)
    self:setControls();
    self:setHeadings();

    self:setAllSizes(scaledW, scaledH);

    if (not displaying) then
      if (game.GetButton(game.BUTTON_BTA)) then
        self['timer'] = math.min(self['timer'] + (deltaTime * 8), 1);
      elseif (self['timer'] > 0) then
        self['timer'] = math.max(self['timer'] - (deltaTime * 6), 0);
      end

      if ((not self['pressedBTD']) and game.GetButton(game.BUTTON_BTD)) then
        self['selectedPage'] = (((self['selectedPage'] + 1) > 5) and 1)
          or (self['selectedPage'] + 1);
      end
    end

    self['pressedBTD'] = game.GetButton(game.BUTTON_BTD);

    gfx.Save();

    self:drawScreen();

    gfx.Restore();
  end
};

return _;