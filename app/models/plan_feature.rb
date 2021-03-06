# == Schema Information
#
# Table name: plan_features
#
#  id         :integer          not null, primary key
#  plan_id    :integer
#  feature_id :integer
#  value      :string(20)
#

##
# Plan feature model
#
class PlanFeature < ActiveRecord::Base
  belongs_to :plan
  belongs_to :feature

  scope :find_by_plan_and_feature, -> plan_id, feature_id { where('plan_id = ?', plan_id)
                                                .where('feature_id = ?', feature_id) }
end
