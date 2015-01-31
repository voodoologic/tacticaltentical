class Site
  include Neo4j::ActiveNode
  property :url
  property :previously_scraped
  index :url
  has_many :out, :participants
  has_many :out, :comments, type: :comment
  has_many :out, :contains, model_class: Site
  has_many :in,  :referred_by, model_class: Site
  has_many :out, :referred_by, model_class: Site
  def self.first_or_create(url)
    Site.find_by(url: url) ||  Site.create(url: url)
  end

  def perviously_scraped?
    previously_scaped
  end
end
