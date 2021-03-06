##
# Apikey model
#
class CreateApiKeys < ActiveRecord::Migration
  def change
    create_table :api_keys do |t|
      t.string :api_key

      t.timestamps null: false
    end

    add_index :api_keys, :api_key, unique: true
  end
end
