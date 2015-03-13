require_relative 'parser'
require 'watir-scroll'
class Fyre < Parser
  def perform
    # return if @site.previously_scraped == true
    # bot1 = "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    # bot2 = "Googlebot-News"
    # chrome = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
    # capabilities = Selenium::WebDriver::Remote::Capabilities.phantomjs("phantomjs.page.settings.userAgent" => bot2)
    # driver = Selenium::WebDriver.for :phantomjs, :desired_capabilities => capabilities
    @wait = Watir::Browser.new :phantomjs
    @wait.window.resize_to(1280, 600) #no mobile ads
    @wait.goto @site.url #visit site
    if @wait.h3(:id, 'comments').present?
      comment = @wait.h3(:id, 'comments')
    else
      comment = @wait.div(:id, 'comments')
    end
    @wait.scroll.to comment #initiate comments in salon.com
    @wait.screenshot.save("/Users/voodoologic/awesome.png") #test a screenshot
    begin
      @wait.div(:class, 'fyre-comment-stream').wait_until_present(10) #wait 10 seconds for comments
    rescue => e
      puts e
    end

    Watir::Wait.while { @wait.div(:class, 'fyre-stream-more-container').visible? && @wait.div(:class, 'fyre-stream-more-container').click} #click every 'more comments'

    @fyre_page = Nokogiri::HTML(@wait.html)
    @fyre_page.search('.fyre-comment-wrapper').each do |blob|
      user    = fetch_user(blob)
      comment = fetch_comment(blob)
      links   = fetch_links(blob)
      save_pair(user, comment, links)
    end
    @wait.close
    super
  rescue Watir::Wait::TimeoutError => e
    puts "timeout error"
    sleep 0.3
    if _r = (_r || 0) + 1 and _r < 5
      retry
    else
      #NOOP
    end
  rescue StandardError => e
    puts e
  end

  def fetch_user(blob)
    blob.search('.fyre-comment-username span').text.squish
  end

  def fetch_comment(blob)
    blob.search('.fyre-comment p').text.squish
  end

  def fetch_links(blob)
    referenced_people = blob.search('.fyre-mention, .fyre-comment-username')
    comment_links     = blob.search('a') - referenced_people
    comment_links     = comment_links.reject{|link| link[:href].nil?}
    comment_links.each do |link|
      site = Site.first_or_create(link[:href])
      puts "found links in comment: #{link[:href]}"
      @sites << site if site.present?
    end
    comment_links
  end

end
