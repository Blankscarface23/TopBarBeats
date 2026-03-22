--!strict

--[[
  TopBarBeats Music Player (Extension of TopBarPlus https://1foreverhd.github.io/TopbarPlus/)
  Published under the MIT License.
  © 5/28/2025 Blankscarface23

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
export type RepeatMode = "All" | "One" | "Off"

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

-- Volume --
TopBarBeats.Volume = 0.5 :: number
TopBarBeats.VolumeStep = 0.1 :: number
TopBarBeats.IsMuted = false :: boolean
TopBarBeats._preMuteVolume = 0.5 :: number

-- Repeat mode --
TopBarBeats.RepeatMode = "All" :: RepeatMode

-- Connection tracking for cleanup --
TopBarBeats._connections = {} :: { RBXScriptConnection }

-- Helper Modules --
local img = require(script.img)
local _attribute = require(script.attribution)

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

--[=[
	@function applyVolume
	@within TopBarBeats

	Applies the current volume to the SoundGroup.
]=]
local function applyVolume()
	local soundGroup = SoundService:FindFirstChild("TopBarBeats") :: SoundGroup?
	if soundGroup then
		soundGroup.Volume = TopBarBeats.IsMuted and 0 or TopBarBeats.Volume
	end
end

-- TopBarBeats API --

--[=[
	@function loadTracks
	@within TopBarBeats
	@param playlist {[number]: string}
	@param config {[string]: any}?
	@return nil

	Loads the requested track ids.
	config options: autostart, shuffle, volume
	config is NOT required

	Format for playlist is as follows:
	TopBarBeats:loadTracks(
		{"rbxassetid://132839662402626", "rbxassetid://131065621936266", ...},
		{ autostart = true, shuffle = true, volume = 0.5 }
	)
]=]
function TopBarBeats:loadTracks(playlist: { [number]: string }, config: { [string]: any }?)
	self.TrackList = {} -- reset on each load
	self.CurrentTrackIndex = 1

	for _, trackId in ipairs(playlist) do
		-- Make sure trackId has correct prefix (optional auto-fix)
		if not trackId:match("^rbxassetid://") then
			trackId = "rbxassetid://" .. trackId
		end

		-- Validate trackId format strictly
		local validOk, validErr = pcall(validateSoundId, trackId)
		if not validOk then
			warn(`TopBarBeats: Skipping invalid track - {validErr}`)
			continue
		end

		local name = getTrackName(trackId)
		if not name then
			warn(`TopBarBeats: Skipping track (could not fetch name): {trackId}`)
			continue
		end

		table.insert(self.TrackList, { name = name, id = trackId })
	end

	if #self.TrackList == 0 then
		warn("TopBarBeats: No valid tracks were loaded.")
		return
	end

	if config and next(config) then
		if config.volume then
			self.Volume = math.clamp(config.volume :: number, 0, 1)
			applyVolume()
		end
		if config.shuffle then
			self.TrackList = shuffleTable(self.TrackList)
		end
		if config.autostart then
			self:toggleMusic(true, true)
		end
	end
end

--[=[
	@function setVolume
	@within TopBarBeats
	@param volume number -- 0 to 1
	@return nil

	Sets the playback volume.
]=]
function TopBarBeats:setVolume(volume: number)
	self.Volume = math.clamp(volume, 0, 1)
	self.IsMuted = false
	applyVolume()
end

--[=[
	@function getVolume
	@within TopBarBeats
	@return number

	Returns the current volume (0 to 1).
]=]
function TopBarBeats:getVolume(): number
	return self.Volume
end

--[=[
	@function setRepeatMode
	@within TopBarBeats
	@param mode RepeatMode -- "All", "One", or "Off"
	@return nil

	Sets the repeat mode.
]=]
function TopBarBeats:setRepeatMode(mode: RepeatMode)
	self.RepeatMode = mode
end

--[=[
	@function setupControls
	@within TopBarBeats
	@return nil

	Sets up the TopBarPlus controls and menu.
]=]
function TopBarBeats:setupControls()
	local function attemptSetup()
		if not TopBarBeats.TopBarPlus then
			error("Unable to setup controls - Did you initialize TopBarBeats with TopBarBeats:init()?")
		end

		local TopBarIcon = TopBarBeats.TopBarPlus

		-- Rewind: restart if >5s in, otherwise previous track --
		local function rewindMusic()
			if not TopBarBeats.CurrentTrack or #TopBarBeats.TrackList == 0 then return end

			if TopBarBeats.CurrentTrack.TimePosition > 5 then
				TopBarBeats:toggleMusic(true, true)
				return
			end

			if TopBarBeats.CurrentTrackIndex <= 1 then
				TopBarBeats.CurrentTrackIndex = #TopBarBeats.TrackList
			else
				TopBarBeats.CurrentTrackIndex -= 1
			end

			TopBarBeats:toggleMusic(true, true)
		end

		-- Fast forward: next track --
		local function fastForwardMusic()
			if not TopBarBeats.CurrentTrack or #TopBarBeats.TrackList == 0 then return end

			if TopBarBeats.CurrentTrackIndex >= #TopBarBeats.TrackList then
				TopBarBeats.CurrentTrackIndex = 1
			else
				TopBarBeats.CurrentTrackIndex += 1
			end

			TopBarBeats:toggleMusic(true, true)
		end

		-- Track Title (display only) --
		local trackTitleIcon = TopBarIcon.new()
			:setName("Made with love by Blankscarface23")
			:setLabel("TopBarBeats!")
			:lock()
			:oneClick()
		TopBarBeats.TrackTitleIcon = trackTitleIcon

		-- Rewind --
		local rewindButton = TopBarIcon.new()
			:setImage(img.REWIND)
			:setCaption("Rewind")
			:bindEvent("selected", rewindMusic)
			:oneClick()

		-- Play/Pause --
		local pausePlayButton = TopBarIcon.new()
			:setImage(img.PLAY)
			:setCaption("Play")
			:oneClick()
		TopBarBeats.PausePlayButton = pausePlayButton

		local function handlePausePlay()
			local willPlay = not TopBarBeats.isPlaying
			if willPlay then
				pausePlayButton:setImage(img.PAUSE)
				pausePlayButton:setCaption("Pause")
			else
				pausePlayButton:setImage(img.PLAY)
				pausePlayButton:setCaption("Play")
			end
			TopBarBeats:toggleMusic(willPlay)
		end
		pausePlayButton:bindEvent("selected", handlePausePlay)

		-- Fast Forward --
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

	Plays or pauses the current track.
]=]
function TopBarBeats:toggleMusic(isEnabled: boolean, needsRestart: boolean?)
	local function tryToggle()
		if not TopBarBeats.CurrentTrack then
			error("Unable to play Track - Did you initialize TopBarBeats with TopBarBeats:init()?")
		end

		if #TopBarBeats.TrackList == 0 then
			warn("TopBarBeats: No tracks loaded.")
			return true
		end

		if not isEnabled then
			TopBarBeats.CurrentTrack:Pause()
			return true
		end

		local trackInfo = TopBarBeats.TrackList[TopBarBeats.CurrentTrackIndex]
		if not trackInfo then
			warn("TopBarBeats: Invalid track index.")
			return true
		end

		local name, id = trackInfo.name, trackInfo.id
		validateSoundId(id)

		-- Update track title label --
		if TopBarBeats.TrackTitleIcon then
			TopBarBeats.TrackTitleIcon:setLabel(name)
		end

		-- Handle track switching or restart --
		local isNewTrack = TopBarBeats.CurrentTrack.SoundId ~= id
		TopBarBeats.CurrentTrack.SoundId = id

		if needsRestart or isNewTrack then
			TopBarBeats.CurrentTrack.TimePosition = 0
			TopBarBeats.CurrentTrack:Play()
		else
			TopBarBeats.CurrentTrack:Resume()
		end

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
	@function init
	@within TopBarBeats
	@param TopBarPlus any
	@return nil

	Initializes TopBarBeats with a TopBarPlus reference.
]=]
function TopBarBeats:init(TopBarPlus: any)
	if not TopBarPlus or typeof(TopBarPlus) ~= "table" then
		error("TopBarBeats Could not be Initialized; Make sure you are passing the imported TopBarPlus module.")
		return
	end

	TopBarBeats.TopBarPlus = TopBarPlus

	-- Create SoundGroup and Sound --
	local soundGroup = SoundService:FindFirstChild("TopBarBeats") :: SoundGroup?
	if not soundGroup then
		local newGroup = Instance.new("SoundGroup")
		newGroup.Name = "TopBarBeats"
		newGroup.Volume = TopBarBeats.Volume
		newGroup.Parent = SoundService
		soundGroup = newGroup
	end

	if soundGroup and not soundGroup:FindFirstChild("TopBarTrack") then
		local sound = Instance.new("Sound") :: Sound
		sound.Name = "TopBarTrack"
		sound.SoundGroup = soundGroup
		sound.Parent = soundGroup
		TopBarBeats.CurrentTrack = sound
	elseif soundGroup then
		TopBarBeats.CurrentTrack = soundGroup:FindFirstChild("TopBarTrack") :: Sound?
	end

	TopBarBeats:setupControls()

	-- Register Track Events --
	if TopBarBeats.CurrentTrack then
		-- Advance to the next track based on repeat mode --
		local function handleTrackEnded()
			if #TopBarBeats.TrackList == 0 then return end

			if TopBarBeats.RepeatMode == "One" then
				-- Replay the same track
				TopBarBeats:toggleMusic(true, true)
			elseif TopBarBeats.RepeatMode == "All" then
				-- Advance cyclically
				if TopBarBeats.CurrentTrackIndex >= #TopBarBeats.TrackList then
					TopBarBeats.CurrentTrackIndex = 1
				else
					TopBarBeats.CurrentTrackIndex += 1
				end
				TopBarBeats:toggleMusic(true, true)
			elseif TopBarBeats.RepeatMode == "Off" then
				-- Advance but stop at the end of the playlist
				if TopBarBeats.CurrentTrackIndex < #TopBarBeats.TrackList then
					TopBarBeats.CurrentTrackIndex += 1
					TopBarBeats:toggleMusic(true, true)
				else
					-- End of playlist; stop playing
					TopBarBeats.isPlaying = false
					if TopBarBeats.PausePlayButton then
						TopBarBeats.PausePlayButton:setImage(img.PLAY)
						TopBarBeats.PausePlayButton:setCaption("Play")
					end
				end
			end
		end

		local function setPlayingImage(image: number)
			if not image or not TopBarBeats.PausePlayButton then return end
			TopBarBeats.PausePlayButton:setImage(image)
		end

		-- Store connections for cleanup --
		table.insert(TopBarBeats._connections, TopBarBeats.CurrentTrack.Ended:Connect(handleTrackEnded))
		table.insert(TopBarBeats._connections, TopBarBeats.CurrentTrack.Paused:Connect(function()
			TopBarBeats.isPlaying = false
			setPlayingImage(img.PLAY)
			if TopBarBeats.PausePlayButton then
				TopBarBeats.PausePlayButton:setCaption("Play")
			end
		end))
		table.insert(TopBarBeats._connections, TopBarBeats.CurrentTrack.Resumed:Connect(function()
			TopBarBeats.isPlaying = true
			setPlayingImage(img.PAUSE)
			if TopBarBeats.PausePlayButton then
				TopBarBeats.PausePlayButton:setCaption("Pause")
			end
		end))
		table.insert(TopBarBeats._connections, TopBarBeats.CurrentTrack.Played:Connect(function()
			TopBarBeats.isPlaying = true
			setPlayingImage(img.PAUSE)
			if TopBarBeats.PausePlayButton then
				TopBarBeats.PausePlayButton:setCaption("Pause")
			end
		end))
	end
end

--[=[
	@function getIcon
	@within TopBarBeats
	@return any?

	Returns TopBarBeats Root node.
]=]
function TopBarBeats:getIcon(): any?
	return self.RootNode
end

--[=[
	@function destroy
	@within TopBarBeats
	@return nil

	Destroys TopBarBeats, cleaning up all references and connections.
]=]
function TopBarBeats:destroy()
	-- Disconnect all event connections --
	for _, connection in ipairs(self._connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)

	-- Stop and destroy the current playing sound --
	if self.CurrentTrack then
		self.CurrentTrack:Stop()
		self.CurrentTrack:Destroy()
		self.CurrentTrack = nil
	end

	-- Clear the track list and reset state --
	self.TrackList = {}
	self.CurrentTrackIndex = 1
	self.isPlaying = false
	self.Volume = 0.5
	self.IsMuted = false

	-- Destroy UI elements --
	if self.RootNode then
		self.RootNode:destroy()
		self.RootNode = nil
	end

	if self.TrackTitleIcon then
		self.TrackTitleIcon:destroy()
		self.TrackTitleIcon = nil
	end

	if self.PausePlayButton then
		self.PausePlayButton:destroy()
		self.PausePlayButton = nil
	end

	-- Clear TopBarPlus reference --
	self.TopBarPlus = nil

	-- Remove the SoundGroup --
	local soundGroup = SoundService:FindFirstChild("TopBarBeats")
	if soundGroup then
		soundGroup:Destroy()
	end
end

return TopBarBeats
