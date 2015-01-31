class Parser
  attr_reader :sites
  def initialize(url, stem_site= nil)
    @links = []
    @sites  = []
    @stem_site = stem_site
    @site = Site.first_or_create(url)
    # return if @site.previously_scraped?
    puts "~"*88
    puts "attempting to open #{@site.url}"
    puts "~"*88
    begin
      url = open(@site.url, read_timeout: 10)
      @page = Nokogiri::HTML(url)
      if @page.text.empty?
        @wait = Watir::Browser.new(:phantomjs)
        @wait.goto @site.url
        @page = Nokogiri::HTML(@wait.html)
        @wait.close
      end
      perform
    rescue
      @site.previously_scraped = false
    end
  end

  def perform
    if @stem_site.present? && !@stem_site.referred_by.map(&:url).include?( @site.url ) && @stem_site != @site
      puts ")"*88
      puts @stem_site.neo_id.to_s  + @stem_site.url + "  >>>   "   +  @site.neo_id.to_s + @site.url
      puts ")"*88
      @stem_site.referred_by << @site
    end
    @links.each do |link|
      @sites << Site.first_or_create(link[:href])
      @sites.uniq!
    end
    @sites.each do |site|
      puts "<"*88
      puts site.url + "<<<" + @site.url
      puts "<"*88
      @site.contains << site if @site.url != site.url && !@site.contains.include?(site)
    end
    # @site.previously_scraped = true
  end

  def save_pair(name, text)
    return if name.empty? || text.empty?
    participant = Participant.first_or_create(name)
    @site.participants << participant unless @site.participants.include? participant
    comment = Comment.find_by(text: text) || Comment.create(text: text)
    participant.comments << comment unless participant.comments.include? comment
    @site.comments << comment unless @site.comments.include? comment
  end

  def reject?
    true if (@site.url.match(/pdf$/) || @site.participants.count > 1)
  end
end
