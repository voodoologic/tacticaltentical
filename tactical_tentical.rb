# encoding: UTF-8
require 'rubygems'
require 'sinatra'
require 'sass'
require 'haml'
require 'pry'
require 'neo4j'
require 'fileutils'

require_relative 'lib/tentacle'

Neo4j::Session.open(:server_db, ENV['GRAPHENEDB_URL'] || "http://localhost:7474")

set :server, 'thin'

# timeout 60

enable :logging
get '/' do
  haml :home
end

post '/search' do
  Tentacle.new(params.fetch("search"))
  FileUtils.rm 'results.json', force: true
  redirect "/"
end

get '/application.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :application, :views => "#{settings.root}/assets/stylesheets"
end

get '/json' do
  # [Site,Comment, Participant].each{|k| k.all.each(&:destroy)}
  if File.exist?("results.json")
     results = File.read("results.json")
  else
    results = [Site.all.map{|x| [x, x.rels.reject{|r| r.rel_type == :COMMENT}]}.flatten, Participant.all.map{|x| [x, x.rels.reject{|r|  r.rel_type == :COMMENTS }]}.flatten ].flatten
      json_results = Tentacle.to_graph_json(results)
      puts "!"*88
      puts'finished'
      f = File.open('results.json', 'w')
      f.write(json_results)
      f.close
      json_results
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
