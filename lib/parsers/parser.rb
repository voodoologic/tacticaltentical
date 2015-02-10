class Parser
  attr_reader :sites
  def initialize( url: nil, stem_site: nil, websocket: nil )
    @websocket = websocket
    @links = []
    @sites  = []
    @stem_site = stem_site
    begin #if there is something wrong with the url -- bail
      @site = Site.first_or_create(url)
    rescue
      return unless @site
    end
    # return if @site.previously_scraped?
    puts "~"*88
    @websocket.send("attempting to open #{@site.url}") if @websocket
    puts "attempting to open #{@site.url}"
    puts "~"*88
    begin
      # url = open(@site.url, read_timeout: 10)
      # @page = nokogiri::html(url)
      # if @page.text.empty?
        @wait = Watir::Browser.new(:ff)
        @wait.goto @site.url
        @wait.sroll.to :bottom
        sleep 3
        @page = Nokogiri::HTML(@wait.html)
        disqus_url = @page.search("iframe#dsq-2")
        if disqus_url.first.present?
          puts "this is a disqus forum.. :)"
          Disqus.new(url: @site.url, websocket: @websocket)
          return
        end
        @wait.close
      # end
      perform
    rescue => e
      puts e;
      @site.previously_scraped = false
    end
  end

  def perform
    if @stem_site.present? && !@stem_site.referred_by.map(&:url).include?( @site.url ) && @stem_site != @site
      puts ")"*88
      @websocket.send(@stem_site.neo_id.to_s  + @stem_site.url + "  >>>   "   +  @site.neo_id.to_s + @site.url) if @websocket
      puts @stem_site.neo_id.to_s  + @stem_site.url + "  >>>   "   +  @site.neo_id.to_s + @site.url
      puts ")"*88
      @stem_site.referred_by << @site
    end
    @links.each do |link|
      @sites << site.first_or_create(link[:href])
      @sites.uniq!
    end
    @sites.each do |site|
      puts "<"*88
      @websocket.send(site.url + "<<<" + @site.url) if @websocket
      puts site.url + "<<<" + @site.url
      puts "<"*88
      @site.contains << site if @site.url != site.url && !@site.contains.include?(site)
    end
    # @site.previously_scraped = true
  end

  def save_pair(name, text)
    return if name.empty? || text.empty?
    participant = participant.first_or_create(name)
    @site.participants << participant unless @site.participants.include? participant
    comment = comment.find_by(text: text) || comment.create(text: text)
    participant.comments << comment unless participant.comments.include? comment
    @site.comments << comment unless @site.comments.include? comment
  end

  def reject?
    true if (@site.url.match(/pdf$/) || @site.participants.count > 1)
  end
end
