# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'sass'
require 'haml'
require 'pry'
require 'neo4j'
require 'sinatra-websocket'
require 'watir-webdriver'
require 'sinatra/reloader' if Sinatra::Base.environment == :development
require 'moped'
require 'mongoid'
require 'json/ext'
require_relative 'lib/tentacle'
require_relative 'lib/search_tool'

before do
  Mongoid.load!(Pathname.getwd + "mongoid.yml", Sinatra::Base.environment)
end

Neo4j::Session.open(:server_db, ENV['GRAPHENEDB_URL'] || "http://localhost:7474")

set :server, 'thin'
set :sockets, []

enable :logging
get '/' do
  @sites = Site.all
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

get '/site/:id' do
  @site = Site.find_by(id: params[:id])
  haml :site
end

get '/json' do
  root_site = "http://www.salon.com/2015/03/12/the_george_w_bush_email_scandal_the_media_has_conveniently_forgotten_partner"
  site = Site.first_or_create(root_site)

  result = Result.first_or_create(url: Site.chop_off_trailing_slash(root_site))
  if result.json_cache_value
    return result.json_cache_value
  else
    results = process_results(site)
    bundled_up_data = Tentacle.to_graph_json(results)
    result.json_cache_value = bundled_up_data
    result.url_id = site.id
    result.save
    bundled_up_data
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

def process_results(site)
  results = []
  results << Site.all.map{|x| x } #you have to do this so it doesn't return a search proxy
  results << Participant.all.map{|x| x}
  site_relations   = site.rels.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT || r.rel_type == :comment}
  participant_relations = Participant.all.map(&:rels).flatten.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT}
  results << site_relations
  results << participant_relations
  results.flatten
end
