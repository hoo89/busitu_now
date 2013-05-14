require 'twitter'

class TwitterBot
  def initialize
    @bot = Twitter::Client.new(
      :consumer_key => $TWITTER_CONSUMER_KEY,
      :consumer_secret => $TWITTER_CONSUMER_SECRET,
      :oauth_token => $TWITTER_KEY,
      :oauth_token_secret => $TWITTER_SECRET
    )
  end
  
  #Post message to somewhere
  #post("post from %(name)", :name=>"Taro")
  def post(str,hash)
    hash.each{|k,v|
      str.gsub!("%(#{k.to_s})", v)
    }
    @bot.update(str)
  end
end

class TwitterBotDummy
  def post(str,hash)
  end
end

