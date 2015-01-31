class Guardian < Parser
  def perform
    @wait = Watir::Browser.new(:phantomjs)
    @wait.goto @site.url
    @wait.button(class: "js-discussion-show-button").click if  @wait.button(class: "js-discussion-show-button").present?
    @wait.buttons(class: 'd-show-more-replies__button').each {|button| button.click}
    @page = Nokogiri::HTML(@wait.html)

    @page.search(".d-comment__inner--top-level").each do |blob|
      user    = fetch_user(blob)
      comment = fetch_comment(blob)
      save_pair(user, comment)
    end
    @page.search(".d-comment__inner--response").each do |blob|
      user    = fetch_user(blob)
      comment = fetch_comment(blob)
      save_pair(user, comment)
    end
    fetch_links
    @wait.close
    super
  end

  def fetch_user(blob)
    blob.search('.d-comment__author span').text.squish
  end

  def fetch_comment(blob)
    blob.search('.d-comment__body').text.squish
  end

  def fetch_links
    @links = @page.seach('.d-comment__body a')
  end

end
