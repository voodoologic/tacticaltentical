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
  validate :url_is_valid?
  validates_uniqueness_of :url
  validates_presence_of :url


  def self.first_or_create(url)
    binding.pry if url.nil?
    Site.find_by(url: chop_off_trailing_slash(url)) ||  Site.create(url: chop_off_trailing_slash(url))
  end

  def perviously_scraped?
    previously_scaped
  end

  def url_is_valid?
    self.url =~ /\A#{URI::regexp(['http', 'https'])}\z/
  end

  before_save do
    self.url = chop_off_trailing_slash(self.url)
  end

  def chop_off_trailing_slash(url)
    if url =~ /\/$/
      url.chop
    else
      url
    end
  end

  def self.chop_off_trailing_slash(url)
    if url =~ /\/$/
      url.chop
    else
      url
    end
  end
end
