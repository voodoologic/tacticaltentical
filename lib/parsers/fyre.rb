require_relative 'parser'
class Fyre < Parser
  def perform
    # return if @site.previously_scraped == true
    @wait = Watir::Browser.new :phantomjs
    @wait.goto @site.url
    # @wait.link.click
    @wait.wait(5)
    @wait.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    @wait.wait(3)
    timeout = 5
    attempt = 0
    while !@wait.div(:class, 'fyre-comment-stream').present? do
      @wait.wait(2)
      puts 'waiting for fyre link to show up.'
      attempt += 1
      break if attempt >= timeout
    end

    while @wait.div(:class, 'fyre-stream-more-container').present? && @wait.div(:class, 'fyre-stream-more-container').visible? do
      puts "clicked more link"
      begin
        @wait.div(:class, 'fyre-stream-more-container').click
      rescue
        break
      end
      @wait.wait(2)
    end

    @fyre_page = Nokogiri::HTML(@wait.html)
    @fyre_page.search('.fyre-comment-wrapper').each do |blob|
      user    = fetch_user(blob)
      comment = fetch_comment(blob)
      links   = fetch_links(blob)
      save_pair(user, comment, links)
    end
    @wait.close
    super
  rescue Watir::Wait::TimeoutError
    puts "timeout error"
    binding.pry
  rescue StandardError => e
    puts e
    binding.pry
  end

  def fetch_user(blob)
    blob.search('.fyre-comment-username span').text.squish
  end

  def fetch_comment(blob)
    blob.search('.fyre-comment p').text.squish
  end

  def fetch_links(blob)
    referenced_people = blob.search('.fyre-mention.fyre-mention-livefyre')
    comment_links     = blob.search('a') - referenced_people
    comment_links.each do |link|
      site = Site.first_or_create(link[:href])
      puts "found links in comment: #{link[:href]}"
      @sites << site if site.present?
    end
    comment_links
  end

end
