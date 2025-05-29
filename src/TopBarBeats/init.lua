--!strict

--[[
  TopBarBeats Music Player (Extension of TopBarPlus https://1foreverhd.github.io/TopbarPlus/)
  Published under the MIT License.
  © 5/28/2025 Blankscarface23 😎✨

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
]]

local TopBarBeats = {}

-- Types --
type Track = { name: string, id: string }

-- Services --
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Module-level variables --
TopBarBeats.TopBarPlus = nil :: any?
TopBarBeats.isPlaying = false :: boolean

TopBarBeats.RootNode = nil :: any?
TopBarBeats.TrackTitleIcon = nil :: any?
TopBarBeats.PausePlayButton = nil :: any?

TopBarBeats.TrackList = {} :: { Track }
TopBarBeats.CurrentTrack = nil :: Sound?
TopBarBeats.CurrentTrackIndex = 1 :: number

-- Helper Modules --
local img = require(script.img)
local attribute = require(script.attribution)

-- Helper Functions --

--[=[
	@function getTrackName
	@within TopBarBeats
	@param assetUri string
	@return string?

	Returns the title of a track.
]=]
local function getTrackName(assetUri: string): string?
	local assetId = tonumber(assetUri:match("%d+"))
	if not assetId then
		return nil
	end

	local success, info = pcall(function()
		return MarketplaceService:GetProductInfo(assetId)
	end)

	if success and info then
		return info.Name
	else
		warn("Failed to get info:", info)
		return nil
	end
end

--[=[
	@function validateSoundId
	@within TopBarBeats
	@param soundId string
	@return string

	Validates sound IDs for track list.
]=]
local function validateSoundId(soundId: string): string
	if not soundId:match("^rbxassetid://%d+$") then
		error(`Malformed SoundId: {soundId}. Must be in format 'rbxassetid://<digits>'`)
	end
	return soundId
end

--[=[
	@function shuffleTable
	@within TopBarBeats
	@param t {any}
	@return {any}

	Creates a shuffled copy of the input table using the Fisher-Yates shuffle algorithm.
]=]
local function shuffleTable(t: { any }): { any }
	local shuffled = {}
	for i = 1, #t do
		shuffled[i] = t[i]
	end

	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	return shuffled
end

-- TopBarBeats API --

--[=[
	@function loadTracks
	@within TopBarBeats
	@param playlist {[number]: string}
	@param config {[string]: boolean}?
	@return nil
	
	Loads the requested track ids.
	config options: autostart, shuffle
	config is NOT required 
	
	Format for playlist is as follows:
	TopBarBeats:loadTracks(
		{"rbxassetid://132839662402626", "rbxassetid://131065621936266", ...},
		{ autostart = true, shuffle = true }
	)
]=]
function TopBarBeats:loadTracks(playlist: { [number]: string }, config: { [string]: boolean }?)
	self.TrackList = {} -- reset on each load
	for _, trackId in pairs(playlist) do
		-- Make sure trackId has correct prefix (optional auto-fix)
		if not trackId:match("^rbxassetid://") then
			trackId = "rbxassetid://" .. trackId
		end

		-- Validate trackId format strictly
		validateSoundId(trackId)

		local name = getTrackName(trackId)
		if not name then
			warn(`Issue loading track: {trackId}`)
			return
		end

		table.insert(self.TrackList, { name = name, id = trackId })
	end

	if config and next(config) then
		if config.shuffle then
			TopBarBeats.TrackList = shuffleTable(TopBarBeats.TrackList)
		end
		if config.autostart then
			TopBarBeats:toggleMusic(true)
		end
	end
end

--[=[
	@function setupControls
	@within TopBarBeats
	@return nil
	
	Loads the requested track ids.
]=]
function TopBarBeats:setupControls()
	local function attemptSetup()
		if not TopBarBeats.TopBarPlus then
			error("Unable to setup controls - Did you initialize TopBarBeats with TopBarBeats:init()?")
		end

		local TopBarIcon = TopBarBeats.TopBarPlus

		local function rewindMusic()
			if TopBarBeats.CurrentTrack and TopBarBeats.TrackList and TopBarBeats.CurrentTrackIndex then
				-- Restart Current Song if listening longer than five seconds --
				if TopBarBeats.CurrentTrack.TimePosition > 5 then
					TopBarBeats:toggleMusic(true, true)
					return
				end

				if TopBarBeats.CurrentTrackIndex == 1 then
					TopBarBeats.CurrentTrackIndex = #TopBarBeats.TrackList
				else
					TopBarBeats.CurrentTrackIndex -= 1
				end

				TopBarBeats:toggleMusic(true, true)
			end
		end

		local function fastForwardMusic()
			if TopBarBeats.CurrentTrack and TopBarBeats.TrackList and TopBarBeats.CurrentTrackIndex then
				if TopBarBeats.CurrentTrackIndex == #TopBarBeats.TrackList then
					TopBarBeats.CurrentTrackIndex = 1
				else
					TopBarBeats.CurrentTrackIndex += 1
				end

				TopBarBeats:toggleMusic(true, true)
			end
		end

		local trackTitleIcon = TopBarIcon.new()
			:setName("Made with 💖 by Blankscarface23")
			:setLabel("TopBarBeats! 😎")
			:lock()
			:oneClick()
		TopBarBeats.TrackTitleIcon = trackTitleIcon

		local rewindButton =
			TopBarIcon.new():setImage(img.REWIND):setCaption("Rewind"):bindEvent("selected", rewindMusic):oneClick()
		local pausePlayButton = TopBarIcon.new():setImage(img.PLAY):setCaption("Play"):oneClick()

		TopBarBeats.PausePlayButton = pausePlayButton

		local function handlePausePlay()
			if TopBarBeats.isPlaying then
				pausePlayButton:setImage(img.PLAY)
				pausePlayButton:setCaption("Play")
			else
				pausePlayButton:setImage(img.PAUSE)
				pausePlayButton:setCaption("Pause")
			end
			TopBarBeats:toggleMusic(not TopBarBeats.isPlaying)
		end

		pausePlayButton:bindEvent("selected", handlePausePlay)

		local fastForwardButton = TopBarIcon.new()
			:setImage(img.FASTFORWARD)
			:setCaption("Fast Forward")
			:bindEvent("selected", fastForwardMusic)
			:oneClick()

		-- Root Node --
		TopBarBeats.RootNode = TopBarIcon.new()
			:setImage(img.APP_ICON)
			:setName("TopBarBeats")
			:setCaption("TopBarBeats")
			:bindToggleKey(Enum.KeyCode.M)
			:setMenu({ trackTitleIcon, rewindButton, pausePlayButton, fastForwardButton })

		return true
	end

	local success, err = pcall(attemptSetup)

	if not success then
		warn(`TopBarBeats Error: {err}`)
	end
end

--[=[
	@function toggleMusic
	@within TopBarBeats
	@param isEnabled boolean
	@param needsRestart boolean?
	@return nil
	
	Loads TopBarBeats into TopBarPlus.
]=]
function TopBarBeats:toggleMusic(isEnabled: boolean, needsRestart: boolean?)
	-- Safely turn off/on TopBarBeats tracks --
	local function tryToggle()
		if not TopBarBeats.CurrentTrack then
			error("Unable to play Track - Did you initialize TopBarBeats with TopBarBeats:init()?")
		end

		if not isEnabled then
			TopBarBeats.CurrentTrack:Pause()
			return true
		end

		local trackInfo = TopBarBeats.TrackList[TopBarBeats.CurrentTrackIndex]
		local name, id = trackInfo.name, trackInfo.id

		-- Validate again before playback
		validateSoundId(id)

		if TopBarBeats.TrackTitleIcon then
			TopBarBeats.TrackTitleIcon:setLabel(name)
		end

		if needsRestart then
			TopBarBeats.CurrentTrack.TimePosition = 0
		end

		TopBarBeats.CurrentTrack.SoundId = id
		TopBarBeats.CurrentTrack:Resume()

		return true
	end

	local success, err = pcall(tryToggle)

	if success then
		TopBarBeats.isPlaying = isEnabled
	else
		warn(`TopBarBeats Error: {err}`)
	end
end

--[=[
	@function setupControls
	@within TopBarBeats
	@param TopBarPlus any
	@return nil
	
	Loads TopBarBeats into TopBarPlus.
]=]
function TopBarBeats:init(TopBarPlus: any)
	if not TopBarPlus or typeof(TopBarPlus) ~= "table" then
		error("TopBarBeats Could not be Initialized; Make sure you are passing the imported TopBarPlus module.")
		return
	end

	TopBarBeats.TopBarPlus = TopBarPlus

	-- Create SoundGroup and Sound --
	if not SoundService:FindFirstChild("TopBarBeats") then
		local TopBarBeatsSoundGroup = Instance.new("SoundGroup")

		TopBarBeatsSoundGroup.Name = "TopBarBeats"
		TopBarBeatsSoundGroup.Parent = SoundService

		if not TopBarBeatsSoundGroup:FindFirstChild("Sound") then
			TopBarBeats.CurrentTrack = Instance.new("Sound") :: Sound

			if TopBarBeats.CurrentTrack then
				TopBarBeats.CurrentTrack.Name = "TopBarTrack"
				TopBarBeats.CurrentTrack.Parent = TopBarBeatsSoundGroup
			end
		end
	end

	TopBarBeats:setupControls()

	-- Register Track Events --
	if TopBarBeats.CurrentTrack and TopBarBeats.TrackList and TopBarBeats.CurrentTrackIndex then
		-- Move to next track cyclically --
		local function handleTrackEnded()
			if TopBarBeats.CurrentTrackIndex == #TopBarBeats.TrackList then
				TopBarBeats.CurrentTrackIndex = 1
			else
				TopBarBeats.CurrentTrackIndex += 1
			end

			TopBarBeats:toggleMusic(true)
		end

		-- Make sure PausePlay button exists; set image, as requested --
		local function setPlayingImage(image: number)
			if not image or not TopBarBeats.PausePlayButton then
				return
			end

			TopBarBeats.PausePlayButton:setImage(image)
		end

		TopBarBeats.CurrentTrack.Ended:Connect(handleTrackEnded)
		TopBarBeats.CurrentTrack.Paused:Connect(function()
			TopBarBeats.isPlaying = false
			setPlayingImage(img.PLAY)
		end)
		TopBarBeats.CurrentTrack.Resumed:Connect(function()
			TopBarBeats.isPlaying = true
			setPlayingImage(img.PAUSE)
		end)
		TopBarBeats.CurrentTrack.Played:Connect(function()
			TopBarBeats.isPlaying = true
			setPlayingImage(img.PAUSE)
		end)
	end
end

--[=[
	@function getIcon
	@within TopBarBeats
	@return any?
	
	Returns TopBarBeats Root node.
]=]
function TopBarBeats:getIcon(): any?
	return TopBarBeats["RootNode"]
end

--[=[
	@function destroy
	@within TopBarBeats
	@return nil
	
	Destroys TopBarBeats, along with references...
]=]
function TopBarBeats:destroy()
	-- Stop and destroy the current playing sound
	if self.CurrentTrack then
		self.CurrentTrack:Stop()
		self.CurrentTrack:Destroy()
	end

	-- Clear the track list and reset index
	self.TrackList = {}
	self.CurrentTrackIndex = 1
	self.isPlaying = false

	-- Destroy UI elements if they exist
	if self.RootNode then
		self.RootNode:destroy()
	end

	if self.TrackTitleIcon then
		self.TrackTitleIcon:destroy()
	end

	if self.PausePlayButton then
		self.PausePlayButton:destroy()
	end

	-- Clear TopBarPlus reference
	self.TopBarPlus = nil

	-- Optional: Remove the SoundGroup if you created it
	local soundGroup = SoundService:FindFirstChild("TopBarBeats")
	if soundGroup then
		soundGroup:Destroy()
	end
end

return TopBarBeats
