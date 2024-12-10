require 'open-uri'
require 'json'
$LOAD_PATH << '.'
require 'generic_external_game_lib'

module HypixelLib

  def HypixelLib::get_game_data()
    # Not necessary API Key
    game = GenericExternalGameLib::GameDataHolder.new
    url = "https://api.hypixel.net/v2/resources/achievements"

    begin
      reply = URI.parse(url).open
      data = JSON.parse(reply.read)

      if data and data["success"]
        achievements = data["achievements"]

        achievements.each_key do |minigame|
          oneTimeAch = achievements[minigame]["one_time"]
          oneTimeAch.each_key do |achKey|
            achievement = oneTimeAch[achKey]

            a = game.newAch()
            # a.locked_icon   = nil #Not available
            # a.unlocked_icon = nil #Not available
            a.title          = achievement["name"]
            a.external_id    = "#{minigame}_#{achKey}".downcase
            a.description    = achievement["description"]
            # time_integer = achievement.attribute('completed_timestamp').value.to_i
            # a.date_earned    = Time.at(time_integer)
            # a.unlocked       = time_integer != 0
            # a.earned_offline = false # set to true if date_earned is unknown
          end
        end
      else
        game.newError(GenericExternalGameLib::Error::UNKNOWN, "no reply gotten")
      end
    rescue Exception => e
      game.newError(GenericExternalGameLib::Error::UNKNOWN, e.message)
      puts e.message
      e.backtrace.each do |trace|
        puts trace
      end
    end

    return game
  end

  def HypixelLib::get_user_data(uuid)
    game = GenericExternalGameLib::GameDataHolder.new

    api_key = "" # Your api key from https://developer.hypixel.net/dashboard
    url = "https://api.hypixel.net/v2/player?uuid=#{uuid}"
    headers = {
      "API-Key" => api_key,
    }

    begin
      reply = URI.parse(url).open(headers)
      data = JSON.parse(reply.read)

      if data and data["success"]
        achievements = data["player"]["achievementsOneTime"]

        achievements.each do |achievement|
          a = game.newAch()
          a.locked_icon    = nil #Not available
          a.unlocked_icon  = nil #Not available
          a.external_id    = achievement
          a.unlocked       = true
          a.earned_offline = false # set to true if date_earned is unknown
        end
      else
        game.newError(GenericExternalGameLib::Error::UNKNOWN, "no reply gotten")
      end
    rescue Exception => e
      game.newError(GenericExternalGameLib::Error::UNKNOWN, e.message)
      puts e.message
      e.backtrace.each do |trace|
        puts trace
      end
    end

    return game
  end
end
