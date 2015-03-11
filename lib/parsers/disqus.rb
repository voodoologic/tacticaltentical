require_relative 'parser'
class Disqus < Parser

  def perform
    return if @site.previously_scraped == true
    @wait = Watir::Browser.new :phantomjs
    @wait.goto @site.url
    @wait.wait(1)
    @wait.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    @wait.wait(10)
    timeout = 5
    attempt = 0
    while !@wait.link(data_ui: 'commentsOpen').present? do
      sleep 1
      puts 'waiting for discus link to show up in wired.'
      attempt += 1
      break if attempt >= timeout
    end

    @page = Nokogiri::HTML(@wait.html)
    disqus_url = @page.search("iframe#dsq-2")
    if disqus_url.first.nil?
      puts "couldn't find iframe"
      return
    end
    url = disqus_url.first[:src]

    @wait.goto(url)

    while @wait.link(data_action:'reveal').present?
      @wait.link(data_action:'reveal').click
    end

    page ||= 0
    while @wait.link(data_action: 'more-posts').present? do
      @wait.link(data_action: 'more-posts').click
      puts "fetching page #{page}"
      page += 1
      @websocket.send("accessing more comments") if @websocket
      @wait.wait(3)
      while @wait.link(data_action:'reveal').present?
        @wait.link(data_action:'reveal').click
      end
    end
    @disqus_page = Nokogiri::HTML(@wait.html)
    @disqus_page.search(".post-content").each do |blob|
      user = fetch_user(blob)
      comment = fetch_comment(blob)
      save_pair(user, comment)
    end
    fetch_links
    @wait.close
    super
  rescue Watir::Wait::TimeoutError
    puts "timeout error"
  rescue StandardError
    puts e
  end

  def fetch_user(blob)
    blob.search('.author a').text.squish
  end

  def fetch_comment(blob)
    blob.search('p').text.squish
  end

  def fetch_links
    @links = @disqus_page.search(".post-message a")
    puts "found links in comments: "
    puts @links.map{|x| x[:href]}.join(" ")
  end
end
