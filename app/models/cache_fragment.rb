class CacheFragment < ActiveRecord::Base

  class << self
    def for_removal_fragment(name, site_id)
      CacheFragment.create(:name => name, :site_id => site_id)
    end
  end
end
