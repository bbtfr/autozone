class Bcst::Programme < ActiveRecord::Base
  belongs_to :provider

  extend Share::Ids2Resources
  define_ids2resources_methods 'Bcst::Host', :hosts

end
