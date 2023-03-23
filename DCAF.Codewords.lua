DCAF.Codewords = {
    FlashGordon = { "Flash Gordon", "Prince Barin", "Ming", "Princess Aura", "Zarkov", "Klytus", "Vultan" },
    JamesBond = { "Moneypenny", "Jaws", "Swann", "Gogol", "Tanner", "Blofeld", "Leiter" },
    RockHeroes = { "Idol", "Dio", "Vaughan", "Lynott", "Lemmy", "Mercury", "Fogerty" },
    Disney = { "Goofy", "Donald Duck", "Mickey", "Snow White", "Peter Pan", "Cinderella", "Baloo" },
    Poets = { "Eliot", "Blake", "Poe", "Keats", "Shakespeare", "Yeats", "Byron", "Wilde" },
    Painters = { "da Vinci", "van Gogh", "Rembrandt", "Monet", "Matisse", "Picasso", "Boticelli" },
    Marvel = { "Wolverine", "Iron Man", "Thor", "Captain America", "Spider Man", "Black Widow", "Star-Lord" }
}

DCAF.CodewordTheme = {
    ClassName = "DCAF.CodewordTheme",
    Codewords = {}
}

function DCAF.Codewords:RandomTheme(singleUse)
    local codewords, index = listRandomItem(DCAF.Codewords)
    local theme = DCAF.CodewordTheme:New(codewords, singleUse)
    if isBoolean(singleUse) and singleUse == true then
        table.remove(DCAF.CodewordTheme, index)
    end
    return DCAF.CodewordTheme:New(codewords)
end

function DCAF.CodewordTheme:New(codewords, singleUse)
    local theme = DCAF.clone(DCAF.CodewordTheme)
    if isBoolean(singleUse) then
        theme.SingleUse = singleUse
    else
        theme.SingleUse = true
    end
    listCopy(codewords, theme.Codewords)
    return theme
end

function DCAF.CodewordTheme:GetNextRandom()
    local codeword, index = listRandomItem(self.Codewords)
    if self.SingleUse then
        table.remove(self.Codewords, index)
    end
    return codeword
end