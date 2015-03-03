require_relative 'parser'
class Disqus < Parser

  def perform
    begin
    @wait = Watir::Browser.new
    @wait.goto @site.url
    @wait.wait
    @wait.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    @wait.wait
    while !@wait.link(data_ui: 'commentsOpen').present? do
      sleep 1
      puts 'waiting for discus link to show up in wired.'
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

    while @wait.link(data_action: 'more-posts').present? do
      @wait.link(data_action: 'more-posts').click
      @websocket.send("accessing more comments") if @websocket
      @wait.wait(1)
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
