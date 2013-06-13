class StaffExtension < ActiveRecord::Base
  belongs_to :office
  belongs_to :user
end
