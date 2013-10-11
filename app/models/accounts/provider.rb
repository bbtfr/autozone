class Accounts::Provider < Accounts::Account
  include Accounts::Publicable
  include Accounts::RqrcodeTokenable

  set_detail_class Accounts::ProviderDetail

  include Share::Displayable
  
  has_many :hosts, class_name: 'Bcst::Host'
  has_many :programmes, class_name: 'Bcst::Programme'
  has_many :programme_lists, class_name: 'Bcst::ProgrammeList'

  has_many :exposures, class_name: 'Bcst::Exposure'
  has_many :traffic_reports, class_name: 'Bcst::TrafficReport'

  validates_presence_of :type

  def programme_list
    hash = (0..6).reduce({}) { |ret, day| ret[day.to_s] = []; ret } 
    programme_lists.each { |pl| hash[pl.day.to_s] << pl }
    hash
  end

  def programme_list_as_api_response
    hash = (0..6).reduce({}) { |ret, day| ret[day.to_s] = []; ret } 
    programme_lists.each { |pl| hash[pl.day.to_s] << pl.as_api_response(:base) }
    { list: hash }
  end

  api_accessible :detail, extend: :detail do |t|
    t.add :programmes, template: :base, append_to: :detail
  end
end
