require_relative 'parser'
class Zdnet < Parser
  def perform
    groups = @page.search('.fyre-comment-wrapper')
    return "*"*44 + "couldn't find comments for #{@url.url}" unless groups.count > 0
    groups.each do |blob|
      participant = scrape_participant(blob).text
      comment = scrape_comment(blob).text
      next if (comment.empty? || participant.empty?)
      save_pair(participant, comment)
    end
    fetch_links
    super
  end

  def scrape_participant(blob)
    blob.search(".fyre-comment-username span").text.squish
  end
  def scrape_comment(blob)
    blob.search(".fyre-comment p").text.squish
  end

  def fetch_links
    @links = @page.search('.fyre-comment-wrapper .fyre-comment a')
  end
end
