##
# Chart controller
#
class ChartController < ApplicationController
  layout 'dashboard'

  ##
  # Get /:username/chart
  #
  def show
    user = User.find_by_username(params[:username]) || not_found

    unless auth? && current_user.username == user.username
      render 'general/chart', layout: 'application'
      return
    end
  end
end
