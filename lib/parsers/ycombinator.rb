require_relative 'parser'
class Ycombinator < Parser

  def perform
    groups = @page.search('.default')
    groups.each do |blob|
      participant = scrape_participant(blob).text
      comment     = scrape_comment(blob).text
      links       =  fetch_links(blob)
      next if (comment.empty? || participant.empty?)
      save_pair(participant, comment, links)
    end
    super
  end

  def scrape_participant(blob)
    blob.search('.comhead a:nth-child(1)')
  end

  def scrape_comment(blob)
    blob.search('.comment font')
  end

  def fetch_links(blob)
    links = blob.search(".comment a")
    links.each do |link|
      site = Site.first_or_create(link[:href])
      @sites << site if site.present?
    end
  end
end
