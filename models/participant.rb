class Participant
  include Neo4j::ActiveNode
  property :name
  index :name
  validates :name, :presence => true

  has_many(:out, :comments)
  has_many(:in, :sites)

  def self.first_or_create(name)
    Participant.find_by(name: name) || Participant.create(name: name)
  end


end
