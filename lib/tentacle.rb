# encoding: UTF-8
require 'neo4j'
require_relative '../models/site'
require_relative '../models/participant'
require_relative '../models/comment'
require_relative '../models/result'
require_relative 'parsers'
require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'mechanize'

Neo4j::Session.open(:server_db, (ENV['GRAPHENEDB_URL'] || "http://localhost:7474"),  {basic_auth: {username: ENV['NEO4J_USERNAME'], password: ENV['NEO4J_PASSWORD']}})

class Tentacle
  def initialize(url: "https://news.ycombinator.com/item?id=8792778", websocket: nil, depth:  2)
    @websocket = websocket
    @depth ||= depth
    @seed_url = prep_url(url)
    @site  = Site.first_or_create(url)
    perform
  end

  def perform
    url = @site.url
    seed_klass = SearchTool.choose_parser_class(url)
    @parser = seed_klass.new(url: url, stem_site: @site, websocket: @websocket)
    @parser.perform
    mechanize_for_links_to
    @parser.sites.each do |site|
      begin
        klass = SearchTool.choose_parser_class(site.url)
        @websocket.send( "parser class #{klass.to_s} to parse #{site.url}" ) if @websocket
        puts "parser class #{klass.to_s} to parse #{site.url}"
        klass.new(url: site.url, stem_site: @site, websocket: @websocket).perform
      rescue => e
        puts e
        next
      end
    end
  end

  def self.to_graph_json(objects)
    nodes = {}
    edges = {}

    objects.each_with_index do |object, i|
      case object

      when Neo4j::ActiveNode
        link = set_link(object)
        cluster = set_cluster(object)
        nodes[object.neo_id] = {
          id: object.neo_id,
          labels: [object.class.name],
          role: object.class.name,
          caption: object[:url] || object[:name],
          text:  object[:text],
          link: URI.escape(link),
          properties: object.attributes,
          cluster: cluster
        }
      when Neo4j::Server::CypherNode
        set_link(object)
        nodes[object.neo_id] = {
          id: object.neo_id,
          labels: object.labels,
          role: object.labels,
          caption: object.labels,
          link: URI.escape(link),
          properties: object.props
        }
      when Neo4j::ActiveRel, Neo4j::Server::CypherRelationship
        caption = set_caption(object)

        edges[[object.start_node.neo_id, object.end_node.neo_id]] = {
          source: object.start_node.neo_id,
          target: object.end_node.neo_id,
          caption: caption.to_s.capitalize.gsub("_", " "),
          type: object.try(:type),
          properties: object.props
        }
      else
        nil
      end
    end
    @websocket.send( "done" ) if @websocket
    puts "done"

    {
      nodes: nodes.values,
      edges: edges.values
    }.to_json
  end

  private

  def self.set_cluster(object)
    case object
    when Participant
      contributes_to_more_than_one_site?(object) ? 1 : 0
    when Site
      has_known_screen_scraper?(object) ? 3 : 2
    when Comment
      did_someone_cut_and_paste_an_idea?(object) ? 5 : 4
    end
  end

  def self.did_someone_cut_and_paste_an_idea?(object)
    Comment.where(text: object.text).count > 2
  end

  def self.has_known_screen_scraper?(object)

    if object.url =~ /\A#{URI::regexp(['http', 'https'])}\z/
      uri = URI.parse(object.url)
    end
    if uri
      ["news.ycombinator.com", 'www.wired.com', 'www.telegraph.co.uk', 'www.theguardian.com', 'www.zdnet.com'].include? uri.host
    else
      false
    end
  end

  def self.contributes_to_more_than_one_site?(object)
    object.sites.count > 1
  end

  def self.set_caption(object)
    caption = ""
    caption = object.type if object.respond_to?(:type)
    caption = object.rel_type if object.try(:rel_type).present?
  end

  def self.set_link(object)
    case object
    when Participant
      "/participant/#{object.name}"
    when Site
      object.url
    when Comment
      object.site.try(:url) || ""
    else
      ""
    end
  end

  def mechanize_for_links_to
    st = SearchTool.new(@site,@websocket)
    st.google_reverse_search
  end

  def prep_url(url)
    url.gsub(/https?\:\/\//, "")
  end
end


