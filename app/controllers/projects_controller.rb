# == Schema Information
#
# Table name: projects
#
#  id            :integer          not null, primary key
#  name          :string
#  description   :text
#  configuration :text
#  has_errors    :boolean          default(FALSE)
#  status        :boolean          default(TRUE)
#  user_id       :integer
#  space_id      :integer
#  user_owner_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

##
# Project controller
#



class ProjectsController < ApplicationController
  layout 'dashboard'

  before_filter :allow
  before_filter :allow_space
  before_filter :allow_project, :except => [:index, :create]

  ##
  # Get /:username/:space/projects
  #
  def index
    @project = Project.new
  end

  ##
  # Get /:username/:space/:project
  #
  def show
    @repo_url = ENV['REPO_URL']
    @repos = Project.repos_config(@repo_url)
  end

  ##
  # Post /:username/:namespace/create
  #
  def create
    project = Project.create_new_project(project_create_params, @user, @space, me)

    flash_log('Create the project <b>' + project.name + '</b>',
              'Project was created correctly')

    redirect_to '/' + @user.username + '/' + @space.name + '/' + project.name
  rescue => ex
    flash[:error] = clear_exception ex.message
    redirect_to '/' + @user.username + '/' + @space.name
  end

  ##
  # Patch /:username/:namespace/:project
  #
  def edit
    @project.edit_project(project_edit_params[:description], project_edit_params[:status])

    flash_log('Edit the project <b>' + @project.name + '</b>', 'Project was edited correctly')
    redirect_to '/' + @user.username + '/' + @space.name + '/' + @project.name
  rescue => ex
    flash[:error] = clear_exception ex.message
    redirect_to '/' + @user.username + '/' + @space.name + '/' + @project.name
  end

  ##
  # Patch /:username/:namespace/:project/evaluate
  #
  def evaluate
    errors = Project.evaluate params[:evaluator]
    respond_evaluate errors
  rescue => ex
    flash.now[:error] = clear_exception ex.message
    respond_js
  end

  ##
  # Patch /:username/:namespace/:project/deploy
  #
  def deploy
    errors = Project.evaluate params[:deploy]
    @project.save_project_config params[:deploy], !@errors.nil?

    num_errors = errors.nil? ? 0 : errors.length
    notice = 'Deployed correctly.'
    notice += ' This project will be ignore because it has ' + num_errors.to_s +
        ' errors. Please click on Evaluate for more details.' unless errors.nil?

    flash.now[:notice] = notice if errors.nil?
    flash.now[:error] = notice unless errors.nil?

    respond_js
  rescue => ex
    flash.now[:error] = clear_exception ex.message
    respond_js
  end

  ##
  # Get /:username/:namespace/:project/setting
  #
  def setting
  end

  ##
  # Patch /:username/:namespace/:project/setting/change
  # Change space name
  #
  def change
    old_name = @project.name
    @project.change_project(project_name_params[:name])
    new_name = @project.name
    flash_log('Change project name <b>' + old_name + '</b> by <b>' + new_name + '</b>',
              'The project name was changed correctly')

    redirect_to '/' + @user.username + '/' + @space.name + '/' + new_name + '/setting'
  rescue => ex
    flash[:error] = clear_exception ex.message
    redirect_to '/' + @user.username + '/' + @space.name + '/' + old_name + '/setting'
  end

  ##
  # Delete /:username/:namespace/setting/delete
  #
  def delete
    @project.delete_project(project_name_params[:name])

    flash_log('Delete project <b>' + project_name_params[:name] + '</b>',
              'The project was deleted correctly')
    redirect_to '/' + @user.username + '/' + @space.name
  rescue => ex
    flash[:error] = clear_exception ex.message
    redirect_to '/' + @user.username + '/' + @space.name + '/' + @project.name + '/setting'
  end

  private

  ##
  #
  #
  def respond_evaluate(errors)
    respond_to do |format|
      if errors.nil?
        flash.now[:notice] = 'Your configuration code look great!!! Now you can deploy!'
        format.js
      else
        format.json { render json: errors  }
      end
      format.html { redirect_to '/' + @user.username + '/' + @space.name + '/' + @project.name }
    end
  end

  ##
  #
  #
  def respond_js
    respond_to do |format|
      format.js
      format.html { redirect_to '/' + @user.username + '/' + @space.name + '/' + @project.name }
    end
  end

  ##
  # Never trust parameters from the scary internet, only allow the white list through.
  #
  def project_create_params
    params.require(:project).permit(:name, :description)
  end

  ##
  # Never trust parameters from the scary internet, only allow the white list through.
  #
  def project_edit_params
    params.require(:project).permit(:name, :description, :status)
  end

  ##
  # Never trust parameters from the scary internet, only allow the white list through.
  #
  def project_name_params
    params.require(:project).permit(:name)
  end

  ##
  # Set flash and log
  #
  def flash_log(log_description, msg)
    save_log log_description, 'Project', @user.id
    flash[:notice] = msg
  end

end
