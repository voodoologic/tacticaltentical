class Comment
  include Neo4j::ActiveNode
  property :text
  index :text
  has_one(:in, :participant)
  def self.first_or_create(text)
    Comment.find_by(text: text) || Comment.create(text: text)
  end

end
