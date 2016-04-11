# Description:
#   RSS Parser
#
# Dependencies:
#   Cron
#   feedparser
#   request
#
# Configuration:
#   Hardcoded roomID
#
# Commands:
#   hubot rss help - Displays RSS help menu
#   hubot rss add #url - Add RSS Feed
#   hubot rss remove #url - Removes RSS Feed
#   hubot rss list - Displays all RSS Feeds
#
# TODO:
# Allow multiple roomids instead of hardcoded

# Send to room id.
roomid = "d934705e-bd1f-45d1-8721-102342b89d63"

cron = require('cron').CronJob #Task Scheduling
feedparser = require 'feedparser' #RSS Parser
request = require 'request' #HTTP Request

module.exports = (robot) ->

    addRSS = (url, callback) ->
        ###
        Check RSS list and add.
        ###
        urls = robot.brain.data["#{roomid}_RSSReader"]
        urls = [] if !urls?
        # Replace single-byte and double-byte spaces.
        try
            url = url.replace(/\ /g, "").replace(/\ã€€/g, "")
        catch error
            response.send "Invalid URL."
            return

        for item in urls
            if item == url
                # Already exists in list, exit.
                response.send "
                #{url} already exists
                to #{roomid}
                "
                return

        # Add RSS list.
        urls.push url
        # Persisting the data.
        robot.brain.data["#{roomid}_RSSReader"] = urls
        robot.brain.save()
        response.send "Added #{url} to #{roomid}"
        callback url #Callback method.

    removeRSS = (url, callback) ->
        ###
        Remove from the list a URL.
        ###
        urls = robot.brain.data["#{roomid}_RSSReader"]
        nurls = []
        # Replacing single-byte and double-byte spaces.
        try
            url = url.replace(/\ /g, "").replace(/\ã€€/g, "")
        catch error
            response.send "Invalid URL."
            return

        if urls
            for item in urls
                if item != url
                    # Unmatch.
                    nurls.push item

            # Save data.
            robot.brain.data["#{roomid}_RSSReader"] = nurls
            robot.brain.save()
            callback url
        else
            response.send "No RSS to remove."

    infoRSS = (url, callback) ->
        ###
        Callback request and grab RSS.
        ###
        request(url)
            .pipe(new feedparser [])
            .on("error", console.log.bind console)
            .on("meta", (meta) -> callback url, meta)

    listRSS = (callback) ->
        ###
        Get the metadata and callback.
        ###
        urls = robot.brain.data["#{roomid}_RSSReader"]
        if urls
            for url in urls
                infoRSS url, (url, meta) ->
                    callback url, meta
        else
            response.send "No RSS added."

    readRSS = (url, callback) ->
        entries = []
        request(url)
            .pipe(new feedparser [])
            .on("error", console.log.bind console)
            .on("data", entries.push.bind entries)
            .on("end", ->
                lastEntries = {}
                for entry in entries
                    lastEntries[entry.link] = true
                    if robot.brain.data[url]? and not robot.brain.data[url][entry.link]?
                        callback entry
                robot.brain.data[url] = lastEntries
                robot.brain.save()
            )

    # Initialize hubot response for send message.
    response = new robot.Response(robot, {room: roomid})
    robot.hear /RSS ADD (.*)/i, (msg) ->
        # Checking the addtion of RSS url.
        addRSS msg.match[1], (url) ->
            # Request RSS infomation.
            infoRSS url, (url, meta) ->
                response.send "
                ================================================================\n
                Room ID: #{roomid}\n
                Title: #{meta.title}\n
                Description: #{meta.description}\n
                Link: #{meta.link}\n
                RSS: #{url}
                "

    robot.hear /RSS LIST/i, (msg) ->
        # Show a list of RSS.
        listRSS (url, meta) ->
            response.send "
            ================================================================\n
            Room ID: #{roomid}\n
            Title: #{meta.title}\n
            Description #{meta.description}\n
            Link: #{meta.link}\n
            RSS: #{url}
            "

    robot.hear /RSS REMOVE (.*)/i, (msg) ->
        # Remove from the list a URL.
        removeRSS msg.match[1], (url) ->
            response.send "Removed #{url} from #{roomid}"

    robot.hear /RSS HELP/i, (msg) ->
        # RSS reader help.
        response.send "
        This script fetches a RSS url regularly (15 second interval).\n
        [Usage]\n
          # Add URL to the RSS list.\n
          > rss add {RSS URL}\n
          # Remove URL from RSS list.\n
          > rss remove {RSS URL}\n
          # Show RSS list.\n
          > rss list\n
        "

    # Initialize cron.
    new cron("*/15 * * * * *", =>
        urls = robot.brain.data["#{roomid}_RSSReader"]
        for url in urls
            readRSS url, (entry) ->
                response.send "RSS Reader\n =====================================================\n
                #{entry.title} #{entry.link}
                "
    ).start()
