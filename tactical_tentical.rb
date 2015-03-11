# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'sass'
require 'haml'
require 'pry'
require 'neo4j'
require 'sinatra-websocket'
require 'watir-webdriver'
require "sinatra/reloader" if development?

require_relative 'lib/tentacle'

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
  results = process_results
  Tentacle.to_graph_json(results)
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
  site_relations        = Site.all.map(&:rels).flatten.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT || r.rel_type == :comment}
  participant_relations = Participant.all.map(&:rels).flatten.reject!{|r| r.rel_type == :COMMENTS || r.rel_type == :COMMENT}
  results << site_relations
  results << participant_relations
  results.flatten
end
