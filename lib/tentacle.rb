# encoding: UTF-8
require 'neo4j'
require_relative '../models/site'
require_relative '../models/participant'
require_relative '../models/comment'
require_relative 'parsers'
require 'rubygems'
require 'watir'
require 'open-uri'
require 'nokogiri'
require 'mechanize'
Neo4j::Session.open(:server_db, ENV['GRAPHENEDB_URL'])
class Tentacle
  def initialize(url = "https://news.ycombinator.com/item?id=8792778", depth = 2)
    @depth ||= depth
    @seed_url = prep_url(url)
    @site  = Site.first_or_create(url)
    perform
  end

  def perform
    url = @site.url
    seed_klass = choose_parser_class(url)
    @parser = seed_klass.new(url)
    mechanize_for_links_to
    @parser.sites.each do |site|
      begin
        klass = choose_parser_class(site.url)
        puts "parser class #{klass.to_s} to parse #{site.url}"
        klass.new(site.url, @site).perform
      rescue
        next
      end
    end
  end

  def self.to_graph_json(objects)
    nodes = {}
    edges = {}

    objects.each_with_index do |object, i|
      case object

      when Neo4j::ActiveNode, Neo4j::Server::CypherNode
        if object.is_a? Participant
          link = "/participant/#{object.name}"
        elsif object.is_a? Site
          link = object.url
        elsif object.is_a? Comment
          link = object.site.try(:url) || ""
        else
          link = ""
        end
        nodes[object.neo_id] = {
          id: object.neo_id,
          labels: (object.is_a?(Neo4j::ActiveNode) ? [object.class.name] : object.labels),
          role: (object.is_a?(Neo4j::ActiveNode) ? object.class.name : object.labels),
          caption: (object.is_a?(Neo4j::ActiveNode) ? (object[:url] || object[:name])  : object.labels),
          link: URI.escape(link),
          properties: (object.is_a?(Neo4j::ActiveNode) ? [object.attributes] : object.props)
        }
      when Neo4j::ActiveRel, Neo4j::Server::CypherRelationship
        caption = ""
        if object.try(:type).present?
          caption = object.type
        elsif object.try(:rel_type).present?
          caption = object.rel_type
        end

        edges[[object.start_node.neo_id, object.end_node.neo_id]] = {
          source: object.start_node.neo_id,
          target: object.end_node.neo_id,
          caption: caption.to_s.capitalize.gsub("_", " "),
          type: object.try(:type),
          properties: object.props
        }
      else
        fail "Invalid value found: #{object.inspect}"
      end
    end
    puts "done"

    {
      nodes: nodes.values,
      edges: edges.values
    }.to_json
  end

  private

  def mechanize_for_links_to
    agent = Mechanize.new
    page = agent.get('http://www.google.com/')

    google_form = page.form('f')
    google_form.q = link_to_query

    puts "submitting search to google"
    page = agent.submit(google_form, google_form.buttons.first)
    puts "results returned from google"
    n_page = Nokogiri::HTML(page.body)
    links = n_page.search("#center_col a")
    non_cached_links = links.reject{|l| l.text.encode!('UTF-8', 'UTF-8', :invalid => :replace).match("Cached")}
    unless page.body.match("did not match any documents")
      non_cached_links.map do |link|
        puts "found referrence link: " + "@"*44
        puts link.text
        puts "@"*88
        uri = extract_link_from_googly_href(link)
        next if uri.to_s.empty?
        klass = choose_parser_class(uri.to_s)
        klass.new(uri.to_s, @site).perform
      end
    end
  end

  def extract_link_from_googly_href(link)
    url_match = link[:href].match(/q=(https?\:\/\/[^&]+)/)
    if url_match.nil?
      nil
    else
      url = url_match[1]
      URI.decode(url) if url
    end
  end

  def choose_parser_class(url)
    uri = URI.parse(url)
    case uri.host
    when "news.ycombinator.com"
      Ycombinator
    when 'www.wired.com', 'www.telegraph.co.uk'
      Disqus
    when 'www.theguardian.com'
      Guardian
    when 'www.zdnet.com'
      Zdnet
    else
      Parser
    end
  end

  def link_to_query
    removed_protocal = @site.url.gsub(/https?:\/\//, "")
    "link: #{removed_protocal}"
  end

  def prep_url(url)
    url.gsub(/https?\:\/\//, "")
  end
end


