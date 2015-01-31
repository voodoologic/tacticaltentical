require_relative 'parser'
class Ycombinator < Parser

  def perform
    groups = @page.search('.default')
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
    blob.search('.comhead a:nth-child(1)')
  end

  def scrape_comment(blob)
    blob.search('.comment font')
  end

  def fetch_links
    @links = @page.search(".comment a")
  end
end
