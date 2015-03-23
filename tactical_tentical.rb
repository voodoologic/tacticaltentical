# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'sass'
require 'haml'
require 'pry'
require 'neo4j'
require 'sinatra-websocket'
require 'watir-webdriver'
require 'sinatra/reloader' if development?
require 'moped'
require 'mongoid'
require 'json/ext'
Mongoid.load!(Pathname.getwd + "mongoid.yml", :production)
require_relative 'lib/tentacle'
require_relative 'lib/search_tool'
before do
  mongo_uri  = ENV['MONGOLAB_URI'] || 'localhost'
  mongo_port = '27017'
  connection = [mongo_uri, mongo_port].join(':')
  @session = Moped::Session.new([connection])
  @session.use :test
end

Neo4j::Session.open(:server_db, ENV['GRAPHENEDB_URL'] || "http://localhost:7474")

set :server, 'thin'
set :sockets, []

# timeout 60

enable :logging
get '/' do
  haml :home
end

post '/search' do
  Tentacle.new(url: params.fetch("search"))
  redirect "/"
end

get '/application.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :application, :views => "#{settings.root}/assets/stylesheets"
end

get '/json' do
  # [Site,Comment, Participant].each{|k| k.all.each(&:destroy)}
  binding.pry
  root_site = "http://www.salon.com/2015/03/12/the_george_w_bush_email_scandal_the_media_has_conveniently_forgotten_partner"
  site_cache = Result.where(url: root_site)
  site_cache = Result.first unless site_cache.exist?
  if site_cache.json_cache_value
    return site_cache.json_cache_value
  else
    results = process_results
    Tentacle.to_graph_json(results)
  end
end

get '/statuses' do
  request.websocket do |ws|
    ws.onopen do
      ws.send("websocket online")
      settings.sockets << ws
    end
    ws.onmessage do |msg|
      message = JSON.parse(msg)
      Tentacle.new(url: message["extend"], websocket: ws) if message["extend"]
      FileUtils.rm 'results.json', force: true
      puts "!"*88
      puts'finished'
      ws.send("reload the page")
      EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end
    ws.onclose do
      warn("websocket closed")
      settings.sockets.delete(ws)
    end
  end
end

get '/json/participant/:name' do
  name = URI.decode(params[:name])
  p = Participant.find_by(name: name)
  data = [p, p.rels, p.comments.map{|x|[x, x.rels]}, p.sites.map{|x|[x]}].flatten
  Tentacle.to_graph_json(data)
end

get '/participant/:name' do
  return haml :user
end

get '/delete' do
  [Site, Comment, Participant].each{|k| k.all.each(&:destroy)}
  FileUtils.rm 'results.json', force: true
  redirect "/"
end

private

def process_results
  results = []
  results << Site.all.map{|x| x } #you have to do this so it doesn't return a search proxy
  results << Participant.all.map{|x| x}
  site_relations        = site_cache.map(&:rels).flatten.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT || r.rel_type == :comment}
  participant_relations = Participant.all.map(&:rels).flatten.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT}
  results << site_relations
  results << participant_relations
  results.flatten
end
