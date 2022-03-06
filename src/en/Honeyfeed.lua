-- {"id":1298,"ver":"1.0.0","libVer":"1.0.0","author":"ardittristan"}

local baseURL = "https://www.honeyfeed.fm"

local GENRE_FILTER_EXT = {
    "All",
    "Action",
    "Adventure",
    "Boys Love",
    "Collaboration",
    "Comedy",
    "Crime",
    "Culinary",
    "Drama",
    "Ecchi",
    "Fantasy",
    "Game",
    "Girls Love",
    "Gun Action",
    "Harem",
    "Historical",
    "Horror",
    "Isekai",
    "Magic",
    "Martial Arts",
    "Mecha",
    "Military / War",
    "Music",
    "Mystery",
    "Other",
    "Philosophical",
    "Post-Apocalyptic",
    "Psychological",
    "Romance",
    "School",
    "Sci-Fi",
    "Seasonal",
    "Seinen",
    "Short Story",
    "Shoujo",
    "Shounen",
    "Slice of Life",
    "Space",
    "Sports",
    "Supernatural",
    "Survival",
    "Thriller",
    "Tragedy",
    "Vampire",
    "Yaoi",
    "Yuri",
    "Zombie",
    "Adult"
}
local GENRE_FILTER_KEY = 500
local GENRE_FILTER_INT = {
    [0] = nil,
    "1",  -- Action
    "2",  -- Adventure
    "49", -- Boys Love
    "62", -- Collaboration
    "5",  -- Comedy
    "14", -- Crime
    "6",  -- Culinary
    "9",  -- Drama
    "10", -- Ecchi
    "11", -- Fantasy
    "13", -- Game
    "47", -- Girls Love
    "16", -- Gun Action
    "17", -- Harem
    "19", -- Historical
    "20", -- Horror
    "63", -- Isekai
    "26", -- Magic
    "28", -- Martial Arts
    "29", -- Mecha
    "30", -- Military / War
    "32", -- Music
    "33", -- Mystery
    "39", -- Other
    "36", -- Philosophical
    "66", -- Post-Apocalyptic
    "38", -- Psychological
    "40", -- Romance
    "42", -- School
    "43", -- Sci-Fi
    "61", -- Seasonal
    "44", -- Seinen
    "64", -- Short Story
    "46", -- Shoujo
    "48", -- Shounen
    "50", -- Slice of Life
    "51", -- Space
    "52", -- Sports
    "53", -- Supernatural
    "45", -- Survival
    "55", -- Thriller
    "65", -- Tragedy
    "56", -- Vampire
    "58", -- Yaoi
    "59", -- Yuri
    "60", -- Zombie
    "-1", -- Adult
}

local ORDER_BY_FILTER_EXT = {
    "New Novels",
    "Monthly Ranking",
    "Weekly Ranking"
}
local ORDER_BY_FILTER_KEY = 700
local ORDER_BY_FILTER_INT = {
    [0] = "/novels",
    "/ranking/monthly",
    "/ranking/weekly"
}

local function getHomePageNovels(subUrl, queryString)
    local document = GETDocument(baseURL .. subUrl .. queryString):selectFirst(".list-unit-novel"):select(".novel-unit-type-h")

    local novels = map(document, function(it)
        return Novel {
            title = it:selectFirst(".novel-name"):text(),
            link = baseURL .. it:selectFirst('.wrap-novel-links a[href^="/novels/"]'):attr("href"),
            imageURL = it:selectFirst(".wrap-image-unit-novel img"):attr("src")
        }
    end)

    return novels;
end

local function getStatus(status)
    local statuses = {
        Ongoing = NovelStatus.PUBLISHING,
        Finished = NovelStatus.COMPLETED
    }

    return statuses[status] or NovelStatus.UNKNOWN
end

local text = function(v) return v:text() end

local remove = function(v) return v:remove() end

local function trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end

local function emptyNil(str)
    if str == "" then
        return nil
    end
    return str
end

local function createFilterString(data)
    return "?" .. table.concat(mapNotNil({
        "page=" .. data["page"],
        not(emptyNil(data["genre"]) == nil) and ("genre_id=" .. data["genre"]) or nil,
        not(emptyNil(data["search"]) == nil) and ("k=" .. data["search"]) or nil
    }), "&")
end

return {
    id = 1298,
    name = "Honeyfeed",
    baseURL = baseURL,
    imageURL = "https://github.com/shosetsuorg/extensions/raw/dev/icons/WuxiaDotBlog.png",
    chapterType = ChapterType.HTML,
    hasSearch = true,

    listings = {
        Listing("Latest Updated", true, function(data)
            return getHomePageNovels("/novels", createFilterString({page = data[PAGE] + 1}))
        end),
        Listing("Weekly Ranking", true, function(data)
            return getHomePageNovels("/ranking/weekly", createFilterString({page = data[PAGE] + 1}))
        end),
        Listing("Monthly Ranking", true, function(data)
            return getHomePageNovels("/ranking/monthly", createFilterString({page = data[PAGE] + 1}))
        end)
    },

    parseNovel = function(novelURL, loadChapters)
        local document = GETDocument(novelURL)
        local novelWrap = document:selectFirst("#wrap-novel")

        local novel = NovelInfo {
            title = novelWrap:selectFirst("h1.text-center"):text(),
            description = table.concat(map(novelWrap:select(".wrap-novel-body > div > *"), text), "\n"),
            genres = map(novelWrap:selectFirst("#wrap-novel-info"):select('td > a[href^="/novels?genre_id"] .label'), text),
            status = getStatus(novelWrap:selectFirst("#wrap-novel-info > table > tbody > tr:nth-child(5) > td:nth-child(2)"):text()),
            authors = map(novelWrap:select("#wrap-novel-info > table > tbody > tr:nth-child(1) > td:nth-child(2) > div > div > div:nth-child(1) > span > a"), text)
        }

        pcall(function()
            novel:setImageURL(novelWrap:selectFirst(".wrap-img-novel-mask > img"):attr("src"))
        end)

        if loadChapters then
            local chapterWrap = novelWrap:selectFirst("#wrap-chapter")

            local i = 0
            local chapters = AsList(map(chapterWrap:select(".list-chapter > a.list-group-item"), function(it)
                i = i + 1
                return NovelChapter {
                    order = i,
                    title = trim(it:selectFirst("span.chapter-name"):text()),
                    link = baseURL ..it:attr("href"),
                    release = it:selectFirst("span.date-chapter-create-update"):text()
                }
            end))

            novel:setChapters(chapters)
        end
        return novel;
    end,

    getPassage = function(chapterURL)
        local htmlElement = GETDocument(chapterURL):selectFirst("#chapter-body > .wrap-body > div")

        -- Remove/modify unwanted HTML elements to get a clean webpage.
        map(htmlElement:select("span[data-category=button]"), remove)

        return pageOfElem(htmlElement)
    end,

    isSearchIncrementing = true,
    search = function(data)
        local page = data[PAGE] + 1

        local search = emptyNil(data[QUERY])
        local genre = GENRE_FILTER_INT[data[GENRE_FILTER_KEY]]

        if genre == nil and not(search == nil) then
            return getHomePageNovels("/search/novel_title", createFilterString({page = page, search = search}))
        end

        if genre == "-1" then
            return getHomePageNovels("/adult" .. ORDER_BY_FILTER_INT[data[ORDER_BY_FILTER_KEY]], createFilterString({page = page}))
        end

        return getHomePageNovels(ORDER_BY_FILTER_INT[data[ORDER_BY_FILTER_KEY]], createFilterString({page = page, genre = genre}))
    end,

    searchFilters = {
        DropdownFilter(GENRE_FILTER_KEY, "Genre (disables search)", GENRE_FILTER_EXT),
        DropdownFilter(ORDER_BY_FILTER_KEY, "Order by", ORDER_BY_FILTER_EXT)
    }
}