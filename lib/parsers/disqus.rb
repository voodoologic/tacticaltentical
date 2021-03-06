require_relative 'parser'
class Disqus < Parser

  def perform
    return if @site.previously_scraped == true
    Watir.default_timeout = 280
    @watir = Watir::Browser.new :phantomjs
    @watir.goto @site.url
    @watir.wait(5)
    @watir.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    @watir.wait(3)
    timeout = 5
    attempt = 0
    while !@watir.link(data_ui: 'commentsOpen').present? do
      sleep 1
      puts 'waiting for discus link to show up in wired.'
      attempt += 1
      break if attempt >= timeout
    end

    @page = Nokogiri::HTML(@watir.html)
    disqus_url = @page.search("iframe#dsq-2")
    if disqus_url.first.nil?
      puts "couldn't find iframe"
      return
    end
    url = disqus_url.first[:src]

    @watir.goto(url)

    while @watir.link(data_action:'reveal').present?
      @watir.link(data_action:'reveal').click
    end

    page ||= 0
    while @watir.link(data_action: 'more-posts').present? do
      @watir.link(data_action: 'more-posts').click
      puts "fetching page #{page}"
      page += 1
      @websocket.send("accessing more comments") if @websocket
      # @watir.wait(3)
      while @watir.link(data_action:'reveal').present?
        @watir.link(data_action:'reveal').click
      end
    end
    @disqus_page = Nokogiri::HTML(@watir.html)
    @disqus_page.search(".post-content").each do |blob|
      user    = fetch_user(blob)
      comment = fetch_comment(blob)
      links   = fetch_links(blob)
      save_pair(user, comment, links)
    end
    @watir.close
    super
  rescue Watir::Wait::TimeoutError
    puts "timeout error"
  rescue StandardError => e
    puts e
  end

  def fetch_user(blob)
    blob.search('.author a').text.squish
  end

  def fetch_comment(blob)
    blob.search('.post-message').text.squish
  end

  def fetch_links(blob, &block)
    comment_links = blob.search('.post-message a')
    comment_links = comment_links.reject{|link| link[:href].nil?}
    comment_links.each do |link|
      site = Site.first_or_create(link[:href])
      puts "found links in comments: #{link[:href]}"
      @sites << site if site.present?
      yield link if block_given?
    end
    comment_links
  end
end
