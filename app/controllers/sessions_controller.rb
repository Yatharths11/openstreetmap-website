class SessionsController < ApplicationController
  include SessionMethods

  layout "site"

  before_action :disable_terms_redirect, :only => [:destroy]
  before_action :require_cookies, :only => [:new]

  authorize_resource :class => false

  def new
    append_content_security_policy_directives(
      :form_action => %w[*]
    )

    session[:referer] = safe_referer(params[:referer]) if params[:referer]
  end

  def create
    session[:remember_me] ||= params[:remember_me]
    session[:referer] = safe_referer(params[:referer]) if params[:referer]
    password_authentication(params[:username], params[:password])
  end

  def destroy
    @title = t "sessions.destroy.title"

    if request.post?
      if session[:token]
        token = UserToken.find_by(:token => session[:token])
        token&.destroy
        session.delete(:token)
      end
      session.delete(:user)
      session_expires_automatically
      if params[:referer]
        redirect_to safe_referer(params[:referer])
      else
        redirect_to :controller => "site", :action => "index"
      end
    end
  end

  private

  ##
  # handle password authentication
  def password_authentication(username, password)
    if (user = User.authenticate(:username => username, :password => password))
      successful_login(user)
    elsif (user = User.authenticate(:username => username, :password => password, :pending => true))
      unconfirmed_login(user)
    elsif User.authenticate(:username => username, :password => password, :suspended => true)
      failed_login t("sessions.new.account is suspended", :webmaster => "mailto:#{Settings.support_email}").html_safe, username
    else
      failed_login t("sessions.new.auth failure"), username
    end
  end
end