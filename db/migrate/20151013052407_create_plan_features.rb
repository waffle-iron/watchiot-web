##
# Plan feature model
#
class CreatePlanFeatures < ActiveRecord::Migration
  def change
    create_table :plan_features do |t|
      t.references :plan
      t.references :feature
      t.string :value, limit: 20
    end

    add_index :plan_features, :plan_id
    add_index :plan_features, :feature_id
  end
end
