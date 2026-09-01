local dfpwm = require("cc.audio.dfpwm")

local utils = {
        cache = {
                randomFromDictionary
        },
        addTables = function (a, b) -- <<<< probably doesn't work
                local c = {}
                for i = 1, #a do
                        c[i] = a[i] + b[i]
                end
                return c
        end,
        positiveDiffTables = function (a, b) -- <<<< probably doesn't work
                local c = {}
                for i = 1, #a do
                        local result = a[i] - b[i]
                        if result < 0 then
                                c[i] = -result
                        else
                                c[i] = result
                        end
                end
                return c
        end,
        log = function (logText, color)
                term.setTextColor(color or colors.white)
                print(logText)
                term.setTextColor(colors.white)
        end,
        blitText = function (text, fg, bg)
                fg, bg = colors.toBlit(fg), colors.toBlit(bg)
                fg, bg = string.rep(fg, #text), string.rep(bg, #text)
                return text, fg, bg
        end,
        decoder = dfpwm.make_decoder(),
        textToArray = function (text)
                local array = {}
                for char in text:gmatch(".") do
                        table.insert(array, char)
                end
                return array
        end,
        loopingIterator = function(i, amount, limit)
                local sum = i + amount
                if sum > limit then
                        return sum - limit
                elseif sum <= 0 then
                        return limit + sum
                else
                        return sum
	        end
        end,
        randomFromDictionary = function (self, dictionary, filter, skip_previous)
                local table = {}
                local i = 1
                local return_key
                for key, value in pairs(dictionary) do
                        if key ~= filter then
                                table[i] = value
                                i = i + 1
                        end
                end
                repeat
                        return_key = table[math.random(1, #table)]
                until not skip_previous or self.cache.randomFromDictionary ~= return_key
                self.cache.randomFromDictionary = return_key
                return return_key
        end,
        easeInPow = function (x, pow)
                return x^pow
        end
}

return utils