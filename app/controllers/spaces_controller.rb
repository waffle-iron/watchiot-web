class SpacesController < ApplicationController
  layout 'dashboard'

  ##
  # Get /:username/spaces
  #
  def index
    owner_user = User.find_by_username(params[:username])  or not_found

    if !is_auth? || current_user.username != owner_user.username
      render 'general/spaces', layout: 'application'
      return
    end
    @space = Space.new
    @spaces = Space.where(user_id: owner_user.id).find_each
  end

  ##
  # Post /:username/spaces/create
  #
  def create
    owner_user = User.find_by_username(params[:username])  or not_found

    @space = Space.new(space_params)
    @space.can_subscribe = @space.is_public
    @space.user_id = owner_user.id
    @space.user_owner_id = current_user.id

    if @space.save
      save_log 'Create the space <b>' + @space.name + '</b>', 'Create Space', owner_user.id
      redirect_to '/' + params[:username] + '/' + @space.name, status: 303
    else
      render :index
    end
  end

  ##
  # Get /:username/:spacename
  #
  def show
    owner_user = User.find_by_username(params[:username])  or not_found
    @space = Space.where(user_id: owner_user.id, name: params[:spacename]).first  or not_found

    if !is_auth? || current_user.username != owner_user.username
      render 'general/spaces', layout: 'application'
      return
    end

    @project = Project.new
  end

  ##
  # Get /:username/:spacename/setting
  #
  def setting
    owner_user = User.find_by_username(params[:username])  or not_found
    @space = Space.where(user_id: owner_user.id, name: params[:spacename]).first  or not_found

    if !is_auth? || current_user.username != owner_user.username
      redirect_to '/'
      return
    end
  end

  private

  ##
  # Never trust parameters from the scary internet, only allow the white list through.
  #
  def space_params
    params.require(:space).permit(:name, :description, :is_public)
  end
end
