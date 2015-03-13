class Parser
  attr_reader :sites
  def initialize( url: nil, stem_site: nil, websocket: nil )
    @websocket = websocket
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
  end

  def perform
    if @stem_site.present? && !@stem_site.referred_by.map(&:url).include?( @site.url ) && @stem_site != @site
      puts ")"*88
      @websocket.send(@stem_site.neo_id.to_s  + @stem_site.url + "  >>>   "   +  @site.neo_id.to_s + @site.url) if @websocket
      puts @stem_site.neo_id.to_s  + @stem_site.url + "  >>>   "   +  @site.neo_id.to_s + @site.url
      puts ")"*88
      @stem_site.referred_by << @site
    end

    @sites.each do |site|
      puts "<"*88
      @websocket.send(site.url + "<<<" + @site.url) if @websocket
      puts site.url + "<<<" + @site.url
      puts "<"*88
      @site.contains << site if @site.url != site.url && !@site.contains.include?(site)
    end
    @site.previously_scraped = true
  end

  def save_pair(name, text, links = [])
    return if name.empty? || text.empty?
    participant = Participant.first_or_create(name)
    @site.participants << participant unless @site.participants.include? participant
    comment = Comment.find_by(text: text) || Comment.create(text: text)
    links.each do |link|
      site = Site.first_or_create(link[:href])
      comment.sites << site if site.present?
    end
    participant.comments << comment unless participant.comments.include? comment
    @site.comments << comment unless @site.comments.include? comment
  end

  def reject?
    true if (@site.url.match(/pdf$/) || @site.participants.count > 1)
  end
end
