###### March 6, 2021
- Added labels to indicate controls for the following:
  - `Song Select` and `Challenge Wheel`
    - Activating search input
    - Changing current song collection/difficulty filter
    - Changing current song sort
    - Opening gameplay settings
  - `Results`
    - Capturing a screenshot
- Moved practice mode controls and instructions to `Practice Mode`, both can be disabled by newly added skin settings

###### March 3, 2021
- Added current hit window display during gameplay; this can be disabled in skin settings
- Adjusted some scrolling animations
- Changed various scrolling labels to reset when not visisble
- Fixed a bug where some skin settings were not being consumed properly
- Fixed a memory leak caused by excessive jacket loading

###### February 24, 2021
- Added line highlighting for filter and sort wheels
- Added a skin option to only show high scores with harder hit windows for the results screen
- Fixed a crash that occurred when opening the collection dialog
- Moved some single use functions out of `common.lua`
- Reduced the opacity of hit error bar dividers

###### February 22, 2021
- `gamesettingsdialog` changes:
  - Added highlighting to the currently selected setting
  - Added an arrow indicator for tabs that have more than 7 settings
  - Changed text color for settings that can be enabled or disabled
  - Increased the opacity of non-selected settings
- `Song Select` changes:
  - Adjusted spacing and arrangement of song info labels
  - Increased size of grade and clear labels
- `Gameplay` changes:
  - Changed track time display format
  - Refactored script and modified design of hit error bar
- Added color indicators for hit stats on the results panel
- Added a skin setting to change early / late display type, options are the following:
  - DELTA: only displays the hit delta (difference (in ms) between the hit's timing and t he current critical hit window timing)
  - TEXT: only displays the 'EARLY' or 'LATE' text
  - TEXT + DELTA: displays both the text and the hit delta
- Added a skin setting to specify the folder that Nautica charts are saved to
- Previous changes from other commits:
  - Added a suggestion to the results screen on how to adjust current song offset
  - Score difference is now displayed in red if player is behind the top score
- Rewrote and replaced the usages of common functions

###### February 11, 2021
- `Gameplay` changes:
  - Added skin setting to change score difference position
  - Current and total track time is now displayed with the progress bar
  - Modified BT and FX chip textures for easier distinction again
- Organized some common functions and provided warnings for missing parameters

###### February 6, 2021
- Completed work for `Challenge Result`

###### February 2, 2021
- Changes made to support backup gauge option
- Fixed red laser end texture being slightly too short

###### January 16, 2021
- `Challenge Wheel` changes:
  - Changed chart display to only show chart title and difficulty to make more room
  - Changed requirements display to a vertical list, limited to 6 lines
  - Fixed incorrect opacity for inactive scrolling challenge names
  - Fixed fixed long challenge names all scrolling at the same time
  - Limited the number of charts displayed for a challenge to 3
- Gameplay-unrelated changes:
  - Implemented a JSON loader, currently being used for value caching
  - Removed developer options from skin settings

###### January 11, 2021
- Added timestamp to main result panel and changed stat display orders accordingly
- Changed difficulty level display behavior to allow for non-standard values

###### January 8, 2021
- Adjusted scoring threshold for determining `Average` score display
- Carried over the following for `Challenge Wheel`:
  - Adjustable jacket quality
  - Jacket loading improvements
  - Infinite/Gravity/Heavenly/Vivid difficulty names (also fixes incorrect difficulty being displayed)

###### December 15, 2020
- Added Skin Setting for adjusting `Song Select` jacket quality

###### December 14, 2020
- Improved jacket loading time in `Song Select`
- Fixed labels in list-like components getting cut off on resolutions higher than 1080P
- Fixed challenge names overflowing in `Challenge Wheel`
- Fixed challenge requirements overflowing in `Challenge Wheel`
- Fixed Best 20/50 indicators incorrectly appearing when no scores have submitted

###### December 7, 2020
- Added highest grade achieved onto the jackets of the song grid in `Song Select`
- Modified track texture for less distinction between lanes
- Modified BT textures for easier distinction when on top of FX chips or holds
- Fixed track cover not covering lane fully/track invisible effect not working
correctly

###### December 6, 2020
- Added scrolling to collection wheel to prevent rendering off the screen
- Fixed Best 20/50 indicator being cut off under certain conditions
- Fixed sort wheel displaying with incorrect labels and position (hopefully)
- Refactored `gamesettingsdialog` to prevent crashes from new/unknown settings

###### December 5, 2020
- Infinite/Gravity/Heavenly/Vivid difficulty names are now used if available
- Added an indicator for Best 20/50 songs that contribute to volforce during Song Select
- Fixed sort wheel not showing the correct labels for Song Select
- Fixed maximum chain not resetting on chart restart (F5)

###### October 29, 2020
- Refactored more `Song Select` components for reusability and design consistency
- Removed unused `easing` library
- Fixed a crash that occurred when list-like components are empty

###### October 28, 2020
- Completed work for `Challenge Wheel`
  - `Challenge Result` WIP
  - only access if using beta build for USC courses (official courses not implemented at time of writing)
- Refactored some `Song Select` components for better responsive sizing

###### October 2, 2020
- Minor refactoring and visual adjustments for score displays and cursors

###### September 30, 2020
- Modified `Gameplay` appearance slightly
- Fixed Multiplayer results crashes (hopefully)
- Fixed Multiplayer scoreboard during gameplay updating with incorrect names

###### September 27, 2020
- Completed work for Multiplayer screens, features to note:
  - If host, hover over users to display host controls (transfer host or kick user)
- Added Username and Score Difference displays to `Gameplay`
- Added the following toggles to Skin Settings:
  - User Info during `Gameplay` (both Username and Score Difference)
  - Score Difference exclusively
  - `[BT-A]` shortcut for Controls during `Song Select`
  - `[FX-L]` shortcut for Hard Gauge during `Multiplayer`
  - `[FX-R]` shortcut for Mirror Mode during `Multiplayer`
- Added upscore display on `Results` info panel
- Fixed scaling issues in `Song Select`
- Fixed indexing of nil value in multiplayer `Results`

###### September 22, 2020
- Completed work for Practice Mode, `gameplay` and `gamesettingsdialog` scripts updated
- Completed work for Results screen, features to note:
  - Increase hit graph scale with `[BT-A]`
  - Select from list of highscores (or player scores for Multiplayer) with `[FX-L]` / `[FX-R]`
  - Select screenshot region from Skin Settings: `fullscreen` or `panel`
- Moved `Singleplayer` and `Multiplayer` main menu buttons to a separate 'screen' to make room for upcoming `Challenges` feature
- Added new 'Controls' page for Practice Mode controls and basic setup
- Added Skin Setting caching for active collection/level and volforce to prevent visual bugs on Song Select screen

###### September 13, 2020
- Re-arranged 'Sort', 'Difficulty', and 'Collection' labels in Song Select screen
- Addressed crash caused by newline character being inserted in `skin.cfg`
- Enabled Hit Error bar (again), set position in Skin Settings
- Added a null check to Game Settings labels
- Removed all backgrounds and unused textures

###### September 12, 2020
- Completed work for gameplay screen, including multiplayer scoreboard
- Changed accessiblity for 'Controls' screen during Song Select: Hold `[BT-A]` to show, and press `[BT-D]` to navigate pages
  - 'General', 'Gameplay', and 'Results' pages added
  - Previous controller icon and hover behavior removed
- Added an outline to Search and Collection Name input fields when active
- Added volforce display to Song Select screen
- Refactored and cleaned up various scripts

###### September 8, 2020
- Completed work on song select screen and related components including:
  - Filter and Sort wheels
  - Collection Dialog
  - Game settings dialog, currently incomplete/inaccessible for Practice Mode
- Added 'Song Select' and 'Gameplay Settings' controls screen to song select, hover over controller icon in bottom-left corner to display
- Combined 'Controller' and 'Keyboard' sections for controls to account for overlapping actions

###### August 31, 2020
- Created 'Controls' screen, controller-navigable and accessible from a new button in the main menu
- Modified load-in behavior slightly:
  - If an update is available, title is hidden until appropriate actions taken in the prompt
  - Title fades in and the first button is highlighted when menu is fully loaded

###### August 26, 2020
- Replaced textures and shaders for buttons, lasers, track, and more
- Refactored and integrated hit animation system from LucidWave; using different textures
- Added settings for position and scale of hit error bar to 'Skin Settings'
- Enabled hit error bar to resize and scale based on user-defined hit windows

###### August 21, 2020
- Created dialog box for update prompt instead of fullscreen overlay
- Enabled update buttons to be controller-navigable

###### August 20, 2020
- Created main menu assets
- Modified titlescreen script:
  - Extracted controller handling logic
  - Change made to prompt player to install/view update if available
- Implemented osu!-like hit error bar