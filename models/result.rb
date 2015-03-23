class Result
  include Mongoid::Document
  field :url, type: String
  field :json_cache_value, type: String
end
