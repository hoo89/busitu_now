# -*- coding: utf-8 -*-
require 'sinatra'
require 'erb'
require 'data_mapper'
require './app_config'
require './lib/get_address_table'
require './lib/twitter_bot'
require './lib/utils'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

DataMapper.setup(:default, 'sqlite3:db.sqlite3')

#名前とMACアドレスを対応づけるDB
class NameTable
  include DataMapper::Resource
  property :id, Serial
  property :mac, String
  property :name, String
  property :created_at, DateTime
  auto_upgrade!
end

#直近のログイン状態を保存するDB
class LoginState
  include DataMapper::Resource
  property :name,  String, :key => true
  property :login, Boolean
  property :last_login, DateTime
  property :last_logout, DateTime
  property :login_minute, Integer, :default => 0
  auto_upgrade!
end

#ログイン、ログアウトのログを取るDB
class LoginLog
  include DataMapper::Resource
  property :id, Serial
  property :name,  String
  property :login, DateTime
  property :logout, DateTime
  auto_upgrade!
end

def update_login_state(hash)
  more = hash[:more_users]
  less = hash[:less_users]
  time_now = Time.now
  ok = true

  more.each{|i|
    ok&&=LoginState.first_or_create(:name => i).update(
      :login => true,
      :last_login => time_now
      )
    ok&&=LoginLog.create(
        :name => i,
        :login => time_now
      )
  }

  #DB reflesh
  less.each{|i|
    s = LoginState.get(i)
    m = s ? s.login_minute+((time_now-s.last_login.to_time)/60).to_i : 0

    ok&&=LoginState.first_or_create(:name => i).update(
      :login => false,
      :last_logout => time_now,
      :login_minute => m
      )
    ok&&=LoginLog.last(:name => i).try(:update,{:login =>time_now})
  }

  ok
end

configure do
  set :my_router, RouterScraper.new
  set :my_bot, TwitterBot.new
end

before do
  #get_address_tableで現在のMACアドレスとIPアドレスのHash配列を返すインスタンス
  @router = settings.my_router
  #postメソッドで入退室を投稿するインスタンス
  @bot = settings.my_bot
  #今入室している機器のアドレス一覧 #=>[{:mac=>"32:61:3C:4E:B6:05",:ip=>192.168.0.10},...]
  @now_addresses = @router.get_address_table
end

get '/' do
  erb :register
end

post '/register' do
  @name = params[:name]
  entry = @now_addresses.find{|i| request.ip == i[:ip]}
  @mac = entry[:mac] unless entry.nil?
  if !@mac||!@name
    #error
    ok = nil
  else
    #record
    ok = NameTable.create(
        :mac => @mac,
        :name => @name,
        :created_at => Time.now
      )
  end
  if ok
    erb :register_success 
  else 
    erb :register_failure, :locals => { :debug_data => [@now_addresses,@name,@mac,request.ip,params] }
  end
end

get '/post_in_out' do
  prev_users = LoginState.all(:login => true).map{|i| i.name}
  now_users = @now_addresses.map{|i|
    NameTable.first(:mac => i[:mac]).try(:name)
  }.compact.uniq

  more = now_users - prev_users
  less = prev_users - now_users
  
  #update record
  update_success=update_login_state(:more_users => more, :less_users => less)

  #Twitter Post
  time = DateTime.now.new_offset(Rational(9, 24)).strftime("%R")
  more.each{|i|
    @bot.post("%(name) さんが入室しました。%(time)", {:name=>i,:time=>time})
  }
  less.each{|i|
    @bot.post("%(name) さんが退室しました。%(time)", {:name=>i,:time=>time})
  }

  if more.empty? && less.empty?
    "No member changed."
  elsif !update_success
    "DB update error occurred."
  else
    "Posted!"
  end
end

get '/post_members' do
  time = DateTime.now.new_offset(Rational(9, 24)).strftime("%R")
  m=LoginState.all(:login => true).map{|i| i.name}.join(" ")
  unless m.empty?
    @bot.post("部室なう！ %(members) %(time)", {:members=>m,:time=>time})
    "Posted!"
  else
    "No Member."
  end
end

get '/name_table' do
  @table = NameTable.all
  erb :name_table
end

get '/login_state' do
  @table = LoginState.all
  erb :login_state
end

get '/login_log' do
  @table = LoginLog.all
  erb :login_log
end

get '/delete_id' do
  ok=NameTable.get(params.keys[0].to_i).try(:destroy)
  if ok
    "削除しました。"
  else
    "削除に失敗しました。"
  end
end
