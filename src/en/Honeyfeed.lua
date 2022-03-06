-- {"id":1298,"ver":"1.0.0","libVer":"1.0.0","author":"ardittristan", "dep":["url>=1.0.0"]}

local baseURL = "https://www.honeyfeed.fm"
local qs = Require("url").querystring

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
    return "?"..qs({
        page = data["page"],
        k = data["search"]
    })
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
        end),
        Listing("Adult Latest Updated", true, function(data)
            return getHomePageNovels("/adult/novels", createFilterString({page = data[PAGE] + 1}))
        end),
        Listing("Adult Weekly Ranking", true, function(data)
            return getHomePageNovels("/adult/ranking/weekly", createFilterString({page = data[PAGE] + 1}))
        end),
        Listing("Adult Monthly Ranking", true, function(data)
            return getHomePageNovels("/adult/ranking/monthly", createFilterString({page = data[PAGE] + 1}))
        end)
    },

    parseNovel = function(novelURL, loadChapters)
        local document = GETDocument(novelURL)
        local novelWrap = document:selectFirst("#wrap-novel")

        local novel = NovelInfo {
            title = novelWrap:selectFirst("h1.text-center"):text(),
            description = table.concat(map(novelWrap:selectFirst("#wrap-synopsis"):select(".wrap-novel-body > div > *"), text), "\n"),
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
        return getHomePageNovels("/search/novel_title", createFilterString({page = data[PAGE] + 1, search = emptyNil(data[QUERY])}))
    end,

    shrinkURL = function(url) return url end,
    expandURL = function(url) return url end
}