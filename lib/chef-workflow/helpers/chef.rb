require 'chef/search/query'
require 'chef/config'

module ChefHelper
  def perform_search(type, query)
    if results = Chef::Search::Query.new.search(type, query).first
      results.map(&:name)
    else
      []
    end
  end
end
