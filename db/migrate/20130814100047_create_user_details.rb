class CreateUserDetails < ActiveRecord::Migration
  def change
    create_table :user_details do |t|
      # t.references :source
      t.integer :sex_id
      t.integer :area_id
      t.integer :brand_id
      t.string  :series
      t.string  :plate_num
      t.integer :balance, null: false, default: 0
      t.attachment :image

    end

    add_index :user_details, [:area_id, :brand_id]
    # add_index :user_details, :source_id
  end
end
