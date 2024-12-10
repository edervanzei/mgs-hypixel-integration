#
# Module for standardized intermediate storing of game and achievement data. 
# Different parsers parse into this, and then this can be propagated to the database
#
module GenericExternalGameLib  
  # We have not decided what this spam status of this game is, should be default
  SPAM_MODE_UNKNOWN = 0
  # This is manually or automatically set to be spam
  SPAM_MODE_SPAM = 1
  # We have manually decided that this is not spam
  SPAM_MODE_EXPLICITLY_NOT_SPAM = 2

  #
  # Throwable error if the it wasn't found, but we don't know what wasn't found
  #
  class NotFound < RuntimeError; end
  #
  # Throwable error if the User was explicitly not found
  #
  class UserNotFound < RuntimeError; end
  #
  # Throwable error if there was privacy issues
  #
  class Privacy < RuntimeError; end

  #
  # Just a standard error class
  #
  class Error < StandardError
    # Unclassified error
    UNKNOWN = 0
    # Privacy-protected data/account
    PRIVACY = 1
    # This player doesn't exist at all
    PLAYER_NONEXISTENT = 2
    # Got the wrong data, for example the wrong user
    WRONG_DATA_RECIEVED = 3
    # Successfully got data, but it says you cannot scan it for some other reason
    EXPLICITLY_NOT_SCANNABLE = 4
    
    # @return [Integer] number representing the error, from 0 to 4 ( Error::UNKNOWN to Error::EXPLICITLY_NOT_SCANNABLE )
    attr_accessor :error_code 
    
    # @return [String] description of error
    attr_accessor :error_message

    #
    # Make a new error instance
    #
    # @param [Integer] error_code Enum of GenericExternalGameLib::UNKNOWN, etc
    # @param [String] error_message More detailed description
    #
    def initialize(error_code, error_message)
      super()
      self.error_code    = error_code
      self.error_message = error_message
    end

    #
    # Checks the error if it is expected to be transient (to requeue) or permanent ( no point requeueing ).
    #
    # @return [Boolean] If was worth requeueing
    #
    def worthRequeing?
      return false if [PRIVACY, EXPLICITLY_NOT_SCANNABLE].include?(self.error_code)
      return true
    end
    
    #
    # Print the error
    #
    def printError
      puts "Error Code: #{self.error_code}\nError: #{self.error_message}"
    end
  end
  
  
  #
  # Abstract class for making all the holder have unified error handling
  #
  class GenericExternalGameLibClass < Object
    # @return [GenericExternalGameLib::Error] error
    attr_accessor :error #, :error_message

    #
    # Make a new error and add it to the class
    #
    # @param [Integer] error_code Enum of GenericExternalGameLib::UNKNOWN, etc
    # @param [String] error_message More detailed description
    #
    def newError(code, msg)
      self.error = GenericExternalGameLib::Error.new(code,msg)
    end
    
    def initialize
      self.error = false
    end
    
    def printError
      (self.error == false)? puts("No Error") : self.error.printError
    end
  end
  

  #
  # Holds a list of games
  #
  class GameListDataHolder < GenericExternalGameLibClass
    # @return [Array<GenericExternalGameLib::GameDataHolder>] list of external games
    attr_accessor :games
    # @return [Hash] key-value store with project speciifc data
    attr_accessor :information
    # @return [Integer] The total number of pages
    attr_accessor :pagecount
    # @return [Integer] The current page
    attr_accessor :page

    attr_accessor :game_id_lookup
    
    private :game_id_lookup, :game_id_lookup=

    def initialize
      super()
      @games = []
      @earned_achievement_count = 0
      @information = {}
      @pagecount = 0
      @page = 0
      @game_id_lookup = {}
    end
    
    #
    # @return [Integer] Number of achievements
    #
    def getTotalAchievementCount
      achs = 0
      @games.each do |g|
        achs += g.achievements.count
      end
      achs
    end

    #
    # @param [Integer/String] The external_id
    # @return [GenericExternalGameLib::GameDataHolder] A new, or existing game, with that external_id
    #
    def getOrAddGame(game_external_id)
      @game_id_lookup.fetch(game_external_id) { |new_game_external_id|
        new_game = GenericExternalGameLib::GameDataHolder.new
        new_game.external_id = new_game_external_id
        @games << new_game
        @game_id_lookup[new_game_external_id] = new_game
        new_game
      }
    end
    
    def printDebugStuff
      if @error == false
        puts "==============================================="
        puts "Number of games: #{@games.count}"
        puts "Page #{@page} of #{@pagecount}" if @page > 0 or @pagecount > 0
        puts "Number of achievements: #{self.getTotalAchievementCount}"
        if @information.length > 0
          puts "=== information ==="
          @information.each do |k,v|
            puts "#{k}: #{v}"
          end
        end
      else
        @error.printError
      end
    end
  end
  
  #
  # A holder for a single game
  #
  class GameDataHolder < GenericExternalGameLibClass
    # @return [Array<GenericExternalGameLib::AchievementDataHolder>] achievements for this game
    attr_accessor :achievements

    # @return [Array<String>] list of publishers and developers
    attr_accessor :developers, :publishers

    # @return [Hash<GenericExternalGameLib::AchievementDataHolder>] Achievements, but hashed on identifier
    attr_accessor :hsh_achievements
    # @return [Hash<GenericExternalGameLib::AchievementDataHolder>] is a subset of #hsh_achievements
    attr_accessor :hsh_earned_achievements

    # @return [Boolean] Is this game spam?
    attr_accessor :is_detected_as_spam

    attr_accessor :title, :external_id, :image, :last_update, :information, :storelink, :external_score,
                  :earned_achievement_count, :description, :sub_platform, :playtime, :use_playtime_for_comparison, :achievement_count, :earned_achievement_count_is_accurate
        
    def initialize
      super()
      @achievements = []
      @earned_achievement_count = 0
      @achievement_count = 0
      @information = {}
      @use_playtime_for_comparison = false
      @earned_achievement_count_is_accurate = true
      @is_detected_as_spam = false

      @hsh_achievements = {} # these are generated by generateHashes once all achievements have been added
      @hsh_earned_achievements = {} # these are generated by generateHashes once all achievements have been added
    end

    #
    # Make a new empty achievement in this game and return the handle of it
    #
    # @return [GenericExternalGameLib::AchievementDataHolder] The new achievement created
    #
    def newAch
      a = GenericExternalGameLib::AchievementDataHolder.new
      @achievements << a
      return a
    end

    #
    # Is any achievement secret
    #
    # @return [Boolean] If the game has any secret achievement
    #
    def hasSecretAch?
      @achievements.each do |a|
        return true if a.is_secret
      end
      false
    end
    
    #
    # Print all the ddebug stuff for the game
    #
    def printDebugStuff
      if @error == false
        puts "==============================================="
        puts "* SPAM DETECTED *" if @is_detected_as_spam
        puts "Game title: #{@title}"
        puts "Game sub_platform: #{@sub_platform}" if @sub_platform
        puts "Game external_id: #{@external_id}"
        puts "Game image: #{@image}"
        puts "Game description: #{@description}"
        puts "Game playtime: #{@playtime}" if @playtime
        @achievements.each do |a|
          a.printDebugLine
        end
        if @information.length > 0
          puts "=== information ==="
          @information.each do |k,v|
            puts "#{k}: #{v}"
          end
        end
        puts "==============================================="
      else
        @error.printError
      end
    end
  end
  
  #
  # One achievement
  #
  class AchievementDataHolder < GenericExternalGameLibClass
    attr_accessor :external_id, :locked_icon, :unlocked_icon, :title, :description, :external_value, 
                  :is_secret, :unlocked, :date_earned, :earned_offline, :external_url, :is_limited_time_challenge, 
                  :is_unobtainable, :external_rarity_percentage, :expansion_id
    
    #
    # Makes sure that we always have any data that needs to be present
    #
    def fallbackAchievementData
      if @unlocked == true and @date_earned == nil
        @date_earned = Time.current
        @earned_offline = true
      end
      @external_id = @external_id || @title
    end
    
    #
    # Debug data for this achievement
    #
    def printDebugLine
      p = "-"
      p = "U" if unlocked == true
      puts "*#{p}* '#{@title}', Ext_ID: #{@external_id}, icons: #{@locked_icon} & #{@unlocked_icon}, eo: #{@earned_offline}, ev: #{@external_value}, secr: #{@is_secret}, date: #{@date_earned}, ext_url: #{@external_url}, unob: #{@is_unobtainable}"
      puts "desc: #{@description}\n"
    end
  end
end

module ProfileInfo
  class ProfileContainer < GenericExternalGameLib::GenericExternalGameLibClass
    attr_accessor :avatar, :main_identifier, :nickname
    
    def printDebugLine
      puts "main_identifier: #{@main_identifier}"
      puts "nickname: #{@nickname}"
      puts "avatar: #{@avatar}"
    end
  
  end
end