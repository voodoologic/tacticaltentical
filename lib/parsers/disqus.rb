require_relative 'parser'
class Disqus < Parser

  def perform
    @wait = Watir::Browser.new(:ff)
    @wait.goto @site.url
    sleep 1
    @wait.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    sleep 3
    @page = Nokogiri::HTML(@wait.html)
    disqus_url = @page.search("iframe#dsq-2")
    if disqus_url.first.nil?
      puts "couldn't find iframe"
      return
    end
    url = disqus_url.first[:src]
    @wait.goto(url)
    sleep 1
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
