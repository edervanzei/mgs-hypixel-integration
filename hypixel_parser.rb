$LOAD_PATH << 'lib'
require 'hypixel_lib'

# *********************************************************************************************
# **** Parsing **** 
# *********************************************************************************************   
def parse_Game()
  g = HypixelLib::get_game_data()
  g.printDebugStuff
end

def parse_User(uuid)
  g = HypixelLib::get_user_data(uuid)
  g.printDebugStuff
end

parse_Game()
parse_User("f84c6a790a4e45e0879bcd49ebd4c4e2")