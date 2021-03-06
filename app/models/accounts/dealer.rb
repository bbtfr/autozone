class Accounts::Dealer < Accounts::PublicAccount
  include Share::Localizable
  include Share::Statisticable

  before_save do
    if area_changed?
      self.mending.update_attributes(area_id: self.area_id) if self.mending
      self.cleanings.update_all(area_id: self.area_id)
      self.activities.update_all(area_id: self.area_id)
      self.bulk_purchasings.update_all(area_id: self.area_id)
    end
  end

  include Accounts::Weixinable

  before_save do
    if detail.weixin_app_id_changed? or detail.weixin_app_secret_changed? or
      detail.dealer_type_id_changed? or self.rank_id_changed?
      update_weixin
    end
  end

  before_save do
    if self.accepted_at_changed?
      self.rank_id = TypeRankMap[self.dealer_type_id]
    end
  end

  set_detail_class Accounts::DealerDetail
  delegate :dealer_type, :business_scopes, :rqrcode_image, 
    to: :detail, allow_nil: true
  delegate :latitude, :longitude, to: :location, allow_nil: true

  has_one :mending, class_name: 'Tips::Mending'
  has_many :cleanings, class_name: 'Tips::Cleaning'
  has_many :test_drivings, class_name: 'Tips::TestDriving'
  has_many :activities, class_name: 'Tips::Activity'
  has_many :bulk_purchasings, class_name: 'Tips::BulkPurchasing'
  has_many :vip_cards, class_name: 'Tips::VipCard'
  has_one :selling_brand, class_name: 'Tips::SellingBrand'

  has_many :construction_cases, class_name: 'Tips::ConstructionCase'

  has_many :orders, class_name: 'Tips::Order'
  has_many :recent_orders, -> { where "orders.created_at > ?", 1.month.ago }, 
    class_name: 'Tips::Order'

  has_many :mending_orders, class_name: 'Tips::MendingOrder'
  has_many :cleaning_orders, class_name: 'Tips::CleaningOrder'
  has_many :bulk_purchasing_orders, class_name: 'Tips::BulkPurchasingOrder'
  has_many :vip_card_orders, class_name: 'Tips::VipCardOrder'
  has_many :vehicle_insurance_orders, class_name: 'Tips::VehicleInsuranceOrder'
  has_many :secondhand_appraise_orders, class_name: 'Tips::SecondhandAppraiseOrder'
  has_many :test_driving_orders, class_name: 'Tips::TestDrivingOrder'

  has_many :reviews, through: :orders, class_name: 'Tips::Review'
  has_many :recent_reviews, through: :recent_orders, source: :review, 
    class_name: 'Tips::Review'

  has_many :operating_records, class_name: 'Statistic::OperatingRecord'
  has_many :sales_cases, class_name: 'Statistic::SalesCase'
  has_many :consumption_records, class_name: 'Statistic::ConsumptionRecord'

  validates_each :detail do |record, attr, value|
    if value.address.present? and value.address_changed?
      bmap_geocoding_url = "http://api.map.baidu.com/geocoder/v2/?ak=E5072c8281660dfc534548f8fda2be11&output=json&address=#{value.address}"
      begin
        result = JSON.parse(open(URI::encode(bmap_geocoding_url)).read)
        logger.info("  Requested BMap API #{bmap_geocoding_url}")
        logger.info("  Result: #{result['result'] rescue result}")
        if result['status'] == 0 and result['result'] and result['result'].any?
          record.location_attributes = {
            latitude: result['result']['location']['lat'],
            longitude: result['result']['location']['lng']
          }
        else
          record.errors.add(:address, :invalid)
        end
      rescue Exception => e
        record.errors.add(:base, e.message)
      end
    end

    if value and value.balance_used_changed?
      if value.balance_used > record.adverts_balance
        record.errors.add(:base, :not_enough_balance)
      end
    end
  end

  delegate :address, to: :detail

  RankTemplateAbility = Accounts::DealerDetail::Templates.map do |k, v|
    [k, Rank[v[1]]]
  end.to_h

  TypeTemplateAbility = Accounts::DealerDetail::Templates.map do |k, v|
    [k, v[2].map { |v| Accounts::DealerDetail::DealerType[v] }]
  end.to_h

  def has_template? template
    return true unless Accounts::DealerDetail::TemplateSymbols.include? template
    return false unless detail.template_syms.include? template
    return can_use_template? template
  end

  def can_use_template? template
    return true unless RankTemplateAbility[template]
    return false unless accepted?
    return false if rank_id < RankTemplateAbility[template]
    return false unless TypeTemplateAbility[template].include? dealer_type_id
    return true
  end

  dealer_type_ids = []
  TypeRankAbility = Accounts::DealerDetail::Ranks.map do |v|
    dealer_type_ids += v[1].map do |vv| 
      [vv, Accounts::DealerDetail::DealerType[vv]]
    end
    [Rank[v[0]], dealer_type_ids]
  end.to_h

  type_ranks = []
  Accounts::DealerDetail::Ranks.each do |v|
    type_ranks += v[1].map do |vv|
      [Accounts::DealerDetail::DealerType[vv], Rank[v[0]]]
    end
  end
  TypeRankMap = type_ranks.to_h

  def dealer_type_to_select
    TypeRankAbility[self.rank_id]
  end

  scope :with_dealer_type, -> (dealer_type) {
    detail_ids = Accounts::DealerDetail.with_dealer_type(dealer_type).pluck(:id)
    where(detail_id: detail_ids)
  }

  scope :with_business_scope, -> (business_scope) {
    detail_ids = Accounts::DealerDetail.with_business_scope(business_scope).pluck(:id)
    where(detail_id: detail_ids)
  } 

  scope :with_specific_service, -> (specific_service) {
    detail_ids = Accounts::DealerDetail.with_specific_service(specific_service).pluck(:id)
    where(detail_id: detail_ids)
  }

  def mending_goal_attainment
    Share::Statisticable.goal_attainment mending_orders
  end

  def cleaning_goal_attainment
    Share::Statisticable.goal_attainment cleaning_orders
  end

  def bulk_purchasing_goal_attainment
    Share::Statisticable.goal_attainment bulk_purchasing_orders
  end

  def vip_card_goal_attainment
    Share::Statisticable.goal_attainment vip_card_orders
  end

  extend Share::MethodCache
  define_cached_methods :mending_goal_attainment, :cleaning_goal_attainment, 
    :bulk_purchasing_goal_attainment, :vip_card_goal_attainment, expires_in: 1.hour

  def to_detail_without_statistic_builder
    json = to_base_builder
    json.detail do
      json.attributes!.merge! detail.to_base_builder.attributes!
      json.extract! self, :area_id, :area
      if location
        json.latitude location.latitude
        json.longitude location.longitude
      end
    end
    json
  end

  def to_detail_builder
    json = to_base_builder
    json.detail do
      json.attributes!.merge! detail.to_base_builder.attributes!
      json.extract! self, :area_id, :area, :stars, :mending_goal_attainment,
        :cleaning_goal_attainment, :bulk_purchasing_goal_attainment,
        :vip_card_goal_attainment, :rank_id, :rank
        :orders_count
      if location
        json.latitude location.latitude
        json.longitude location.longitude
      end
      json.builder! self, :mending, :without_dealer
      json.last_3_orders(orders.includes(:user).reorder('id DESC').first(3).map{|o|o.to_base_builder.attributes!})
      json.last_3_reviews(reviews.includes(order:[:user]).first(3).map{|o|o.to_base_builder.attributes!})
    end
    json
  end

  def send_invitation_instructions invite_mobile
    send_devise_notification(:invitation_instructions, { :to => invite_mobile })
  end

end
