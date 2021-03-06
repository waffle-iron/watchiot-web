# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  username               :string(25)
#  first_name             :string(25)
#  last_name              :string(35)
#  address                :text
#  country_code           :string(3)
#  phone                  :string(15)
#  status                 :boolean          default(TRUE)
#  receive_notif_last_new :boolean          default(TRUE)
#  passwd                 :string
#  passwd_salt            :string
#  auth_token             :string
#  provider               :string
#  uid                    :string
#  plan_id                :integer
#  api_key_id             :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

##
# User model
#
class User < ActiveRecord::Base
  attr_accessor :passwd_confirmation, :passwd_new, :remember_me

  has_many :teams
  has_many :emails
  has_many :spaces
  has_many :projects
  has_many :logs
  has_many :verify_clients
  belongs_to  :api_key
  belongs_to :plan

  validates :username, uniqueness: true,
            length: { minimum: 1 },
            format: { without: /\s+/, message: 'No empty spaces admitted for the username.' }
  validates_presence_of :username, on: :create
  validates_presence_of :passwd, on: :create
  validates_presence_of :passwd_confirmation, on: :create
  validates_confirmation_of :passwd
  validates :passwd, length: { minimum: 8 }

  validates :phone, numericality: { only_integer: true }, allow_nil: true

  validates :username, exclusion: {
                         in: %w(home auth register verify login logout doc price download contact),
                         message: '"%{value}" is reserved.' }

  before_validation :username_format

  before_create do
    generate_token(:auth_token)
    generate_api_key
    assign_plan
  end

  ## -------------------------- Instance method ------------------------------ ##

  ##
  # Register a new account
  #
  def register(email)
    raise StandardError, 'The email is not valid' if
        email.email.nil? || email.email.empty?

    User.save_user_and_email self, email

    token = VerifyClient.create_token(self.id, email.email, 'register')
    Notifier.send_signup_email(email.email, self, token).deliver_later
  end

  ##
  # Disable the account
  #
  def delete_account(username)
    raise StandardError, 'The username is not valid' if self.username != username
    raise StandardError, 'You have to transfer your spaces'\
                         ' or delete them' if Space.exists?(user_id: self.id)

    self.update!(status: false)
  end

  ##
  # change the username
  #
  def change_username(new_username)
    self.update!(username: new_username)
  end

  ##
  # Change the password
  #
  def change_passwd(params)
    old_password = BCrypt::Engine.hash_secret(params[:passwd], self.passwd_salt)
    passwd_confirmation = params[:passwd_new] == params[:passwd_confirmation]
    same_old_passwd = self.passwd == old_password
    passwd_is_short = params[:passwd_new].nil? || params[:passwd_new].length < 8

    raise StandardError, 'The old password is not correctly' unless same_old_passwd
    raise StandardError, 'Password has less than 8 characters' if passwd_is_short
    raise StandardError, 'Password does not match the confirm' unless passwd_confirmation

    self.update!(passwd: BCrypt::Engine.hash_secret(params[:passwd_new], self.passwd_salt))
  end

  ##
  # Reset the password
  #
  def reset_passwd(params)
    passwd_confirmation = params[:passwd_new] == params[:passwd_confirmation]
    passwd_is_short = params[:passwd_new].nil? || params[:passwd_new].length < 8

    raise StandardError, 'Password has less than 8 characters' if passwd_is_short
    raise StandardError, 'Password does not match the confirm' unless passwd_confirmation

    return if self.status.nil? || !self.status

    email = Email.find_primary_by_user(self.id).take || Email.find_by_user(self.id).take
    raise StandardError, 'You dont have an email' if email.nil?

    # if the email is not primary it never has activated the account
    self.active_account(email) unless email.primary?

    Notifier.send_reset_passwd_email(email.email, self).deliver_later
    self.update!(passwd: BCrypt::Engine.hash_secret(params[:passwd_new], self.passwd_salt))
  end

  ##
  # Active the account after register and validate the email
  #
  def active_account(email)
    raise StandardError, 'The account can not be activate' if
        email.nil? || email.user.id != self.id

    email.update!(checked: true, primary: true)
    self.update!(status: true)

    Notifier.send_signup_verify_email(email.email, self).deliver_later
  end

  ##
  # A member was invite, finish register, enter username,
  # password and confirmation
  #
  def invite(user_params, email)
    raise StandardError, 'The account can not be activate' if email.nil?
    self.username = user_params[:username] # set the username
    self.passwd = user_params[:passwd] # set the password
    self.passwd_confirmation = user_params[:passwd_confirmation]

    # save user and activate
    User.save_user_and_email(self, email, true)
  end

  ## ------------------------- Class method ------------------------------ ##

  ##
  # Login the account
  #
  def self.login(email, passwd)
    user = authenticate(email, passwd)
    raise StandardError, 'Account is not valid' if user.nil?
    user
  end

  ##
  # Register or login with omniauth
  #
  def self.omniauth(auth)
    User.find_by_provider_and_uid(auth['provider'], auth['uid']) || User.create_with_omniauth(auth)
  end

  ##
  # Create a new account member
  #
  def self.create_new_account(email_member)
    password = User.generate_passwd
    user = User.new(username: email_member, passwd: password, passwd_confirmation: password)
    email = Email.new(email: email_member)

    User.save_user_and_email(user, email)

    token = VerifyClient.create_token(user.id, email_member, 'invited')
    Notifier.send_create_user_email(email_member, token).deliver_later
    user
  end

  ##
  # Send forgot notification
  #
  def self.send_forgot_notification(criteria)
    return if criteria.nil? || criteria.empty?
    user = User.find_by_username criteria # find by username
    email = Email.find_primary_by_email(criteria).take # find by primary email

    # if it does not primary try to find for no primary
    email = Email.find_email_forgot(criteria) if user.nil? || email.nil?

    user = email.user if user.nil? && !email.nil?
    # find by user id first try with the primary or any
    email = Email.find_primary_by_user(user.id).take ||
            Email.find_by_user(user.id).take if email.nil? && !user.nil?

    return if user.nil? || !user.status? || email.nil?

    token = VerifyClient.create_token(user.id, email, 'reset')
    Notifier.send_forget_passwd_email(email.email, user, token).deliver_later
  end

  private

  ## ------------------------- Private Instance method ---------------------------- ##

  ##
  # This method generate a token for the client session
  #
  def generate_token(column)
    begin
      self[column] = SecureRandom.urlsafe_base64
    end while User.exists?(column => self[column])
  end

  ##
  # This method generate an api key for the client
  #
  def generate_api_key
    begin
      api_key = SecureRandom.uuid
    end while ApiKey.exists?(:api_key => api_key)

    api = ApiKey.new
    api.api_key = api_key
    api.save

    self.api_key = api
  end

  ##
  # This method assign the free plan by default
  #
  def assign_plan
    self.plan_id = Plan.find_by_name('Free').id
  end

  ##
  # Set username always lowercase, self.name.gsub! /[^0-9a-z ]/i, '_'
  # the space is change for -
  #
  def username_format
    return if self.username.nil?
    self.username.gsub!(/[^0-9a-z\- ]/i, '_')
    self.username.gsub!(/\s+/, '-')
    self.username = self.username.downcase
    self.username = self.username.byteslice(0, 24) #substring 24
  end

  ## ------------------------- Private Class method ---------------------------- ##

  ##
  # This method try to authenticate the client, other way return nil
  #
  def self.authenticate(email, passwd)
    return if passwd.nil? || passwd.empty? || email.nil? || email.empty?
    user_email = Email.find_primary_by_email(email).take

    user = user_email.user unless user_email.nil?
    user = User.find_by_username(email) if user_email.nil?
    return if user.nil?

    same_passwd = user.passwd == BCrypt::Engine.hash_secret(passwd, user.passwd_salt)
    user if user.status? && same_passwd
  end

  ##
  # Register with omniauth
  #
  def self.create_with_omniauth(auth)
    user = User.new(username: auth['info']['nickname'],
                    provider: auth['provider'],
                    uid: auth['uid'])

    user.first_name = first_name(auth['info']['name'])
    user.last_name = last_name(auth['info']['name'])
    user.passwd = generate_passwd
    user.passwd_confirmation = user.passwd

    email = Email.new(email: auth['info']['email'])
    User.save_user_and_email user, email, true
    user
  end

  ##
  # Save user and email routine
  #
  def self.save_user_and_email(user, email, checked = false)
    passwd_confirm = user.passwd == user.passwd_confirmation
    passwd_is_short = user.passwd.nil? || user.passwd.length < 8

    raise StandardError, 'Password has less than 8 characters' if passwd_is_short
    raise StandardError, 'Password does not match the confirm' unless passwd_confirm
    raise StandardError, 'The email is primary in other account' if
        Email.find_primary_by_email(email.email).exists?

    ActiveRecord::Base.transaction do
      save_user user, checked
      email.save_email user.id, checked
    end

    Notifier.send_signup_verify_email(email.email, user).deliver_later if checked
  end

  ##
  # Save user
  #
  def self.save_user(user, checked)
    user.passwd_salt = BCrypt::Engine.generate_salt
    user.passwd = BCrypt::Engine.hash_secret(user.passwd, user.passwd_salt)
    user.passwd_confirmation = user.passwd
    user.status = checked
    user.save!
  end

  ##
  # Generate a randow password
  #
  def self.generate_passwd
    chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    password = ''
    10.times { password << chars[rand(chars.size)] }
    password
  end

  ##
  # Split first name
  #
  def self.first_name(name)
    name.split(' ').first[0..24]
  end

  ##
  # Split last name
  #
  def self.last_name(name)
    name.split(' ', 2).last[0..34]
  end
end
