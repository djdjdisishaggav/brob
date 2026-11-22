--!strict
-- Pure unlock rules. Shared so the client can explain a lock and the server
-- can enforce it from the same definition.
--
-- Progress shape: { cleared = { [chapterId] = { [difficultyId] = true } } }

local Config = require(script.Parent.Config)

export type Progress = { cleared: { [string]: { [string]: boolean } } }

local Unlocks = {}

function Unlocks.emptyProgress(): Progress
	return { cleared = {} }
end

-- Drops anything that is not a known chapter/difficulty flag.
function Unlocks.sanitize(raw: any): Progress
	local progress = Unlocks.emptyProgress()
	if type(raw) ~= "table" or type(raw.cleared) ~= "table" then
		return progress
	end
	for _, chapter in Config.Chapters do
		local row = raw.cleared[chapter.Id]
		if type(row) == "table" then
			for _, difficulty in Config.Difficulties do
				if row[difficulty.Id] == true then
					progress.cleared[chapter.Id] = progress.cleared[chapter.Id] or {}
					progress.cleared[chapter.Id][difficulty.Id] = true
				end
			end
		end
	end
	return progress
end

local function hasCleared(progress: Progress, chapterId: string, difficultyId: string): boolean
	local row = progress.cleared[chapterId]
	return row ~= nil and row[difficultyId] == true
end

function Unlocks.isChapterUnlocked(progress: Progress, chapterId: string): boolean
	local chapter = Config.getChapter(chapterId)
	if not chapter then
		return false
	end
	local rule = chapter.Unlock
	if not rule then
		return true
	end
	return hasCleared(progress, rule.Chapter, rule.Difficulty)
end

function Unlocks.isDifficultyUnlocked(progress: Progress, chapterId: string, difficultyId: string): boolean
	local difficulty = Config.getDifficulty(difficultyId)
	if not difficulty or not Config.getChapter(chapterId) then
		return false
	end
	if not difficulty.UnlockAfter then
		return true
	end
	return hasCleared(progress, chapterId, difficulty.UnlockAfter)
end

function Unlocks.isUnlocked(progress: Progress, chapterId: string, difficultyId: string): boolean
	return Unlocks.isChapterUnlocked(progress, chapterId)
		and Unlocks.isDifficultyUnlocked(progress, chapterId, difficultyId)
end

-- Requirement sentence for a locked chapter, or nil when it is open.
function Unlocks.chapterRequirement(progress: Progress, chapterId: string): string?
	local chapter = Config.getChapter(chapterId)
	if not chapter or Unlocks.isChapterUnlocked(progress, chapterId) then
		return nil
	end
	local rule = chapter.Unlock :: Config.UnlockRule
	local needChapter = Config.getChapter(rule.Chapter)
	local needDifficulty = Config.getDifficulty(rule.Difficulty)
	if not needChapter or not needDifficulty then
		return "Not available yet"
	end
	return `Clear {needChapter.Name} on {needDifficulty.Name} to unlock`
end

-- Requirement sentence for a locked difficulty on a chapter, or nil when it is open.
function Unlocks.difficultyRequirement(progress: Progress, chapterId: string, difficultyId: string): string?
	local difficulty = Config.getDifficulty(difficultyId)
	local chapter = Config.getChapter(chapterId)
	if not difficulty or not chapter or Unlocks.isDifficultyUnlocked(progress, chapterId, difficultyId) then
		return nil
	end
	local need = Config.getDifficulty(difficulty.UnlockAfter :: string)
	if not need then
		return "Not available yet"
	end
	return `Clear {chapter.Name} on {need.Name} to unlock {difficulty.Name}`
end

-- Hardest unlocked difficulty at or below `preferredId` for a chapter.
function Unlocks.bestDifficulty(progress: Progress, chapterId: string, preferredId: string?): string
	local preferred = preferredId and Config.getDifficulty(preferredId)
	local best = Config.Difficulties[1].Id
	for _, difficulty in Config.Difficulties do
		local withinPreference = preferred == nil or difficulty.Order <= preferred.Order
		if withinPreference and Unlocks.isDifficultyUnlocked(progress, chapterId, difficulty.Id) then
			best = difficulty.Id
		end
	end
	return best
end

return Unlocks
