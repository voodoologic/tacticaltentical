class Comment
  include Neo4j::ActiveNode
  property :text
  index :name
  has_one(:in, :participant)
  has_one :in, :site
  def self.find_or_create(text)
    Comment.find_by(text: text) || Comment.create(text: text)
  end
end
