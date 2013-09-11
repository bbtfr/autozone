class CreateDealerDetails < ActiveRecord::Migration
  def change
    create_table :dealer_details do |t|
      # t.references :source
      t.integer :dealer_type_id
      t.string  :business_scope_ids
      t.string  :company
      t.string  :address
      t.string  :phone
      t.string  :open_during
      t.integer :balance, null: false, default: 0
      t.string  :rqrcode_token
      t.attachment :image

      t.float :latitude
      t.float :longitude

      t.string  :template_ids
      t.integer :balance_used, null: false, default: 0
      
    end

    # add_index :dealer_details, :source_id
  end
end