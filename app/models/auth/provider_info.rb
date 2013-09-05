module Auth
  class ProviderInfo < ActiveRecord::Base    
    belongs_to :source, class_name: 'Provider'
    alias_attribute :user, :source
    alias_attribute :provider, :source

    attr_accessible :source
    attr_accessible :company, :phone, :reg_img

    # Fake attributes
    attr_accessor :dealer_type_id, :business_scope_ids, :address, :open
    attr_accessible :dealer_type_id, :business_scope_ids, :address, :open

    def serializable_hash(options={})
      options = { 
        only: [:company, :phone],
        # methods: [:reg_img],
      }.update(options)
      super(options)
    end

  end
end