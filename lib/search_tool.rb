class SearchTool
  def new(websocket=nil)
    @websocket = websocket
  end

  def google_reverse_search
    agent = Mechanize.new
    page = agent.get('http://www.google.com/')

    google_form = page.form('f')
    google_form.q = link_to_query

    puts "submitting search to google"
    @websocket.send(  "results returned from google" ) if @websocket
    page = agent.submit(google_form, google_form.buttons.first)
    puts "results returned from google"
    n_page = Nokogiri::HTML(page.body)
    links = n_page.search("#center_col a")
    non_cached_links = links.reject{|l| l.text.encode!('UTF-8', 'UTF-8', :invalid => :replace).match("Cached")}
    unless page.body.match("did not match any documents")
      non_cached_links.map do |link|
        puts "found referrence link: " + "@"*44
        @websocket.send( "found referrence link: #{link.text.encode!('UTF-8', 'UTF-8', :invalid => :replace)}" ) if @websocket
        puts link.text
        puts "@"*88
        uri = extract_link_from_googly_href(link)
        next if uri.to_s.empty?
        klass = choose_parser_class(uri.to_s)
        begin
          klass.new(url: uri.to_s, stem_site: @site, websocket: @websocket ).perform
        rescue => e
          puts "@@@@@@@@@ #{__FILE__}:#{__LINE__}"
          puts "\n********** error = #{ e.inspect }"
        end
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
end
