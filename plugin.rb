# name:  discourse-omniauth-gitlab
# about: Authenticate Discourse with GitLab
# version: 0.0.3
# author: Achilleas Pipinellis
# url: https://gitlab.com/gitlab-org/discourse-omniauth-gitlab
gem 'rack', '2.0.1'
gem 'omniauth', '1.3.1'
gem 'multipart-post', '2.0.0'
gem 'faraday', '0.10.1'
gem 'jwt', '1.5.6'
gem 'multi_json', '1.12.1'
gem 'multi_xml', '0.6.0'
gem 'oauth2', '1.3.0'
gem 'omniauth-oauth2', '1.4.0'
gem 'omniauth-gitlab', '1.0.2'

class GitLabAuthenticator < ::Auth::Authenticator

  GITLAB_APP_ID = ENV['GITLAB_APP_ID']
  GITLAB_SECRET = ENV['GITLAB_SECRET']

  def name
    'gitlab'
  end

  def after_authenticate(auth_token)
    result = Auth::Result.new

    # Grap the info we need from OmniAuth
    data = auth_token[:info]
    name = data["first_name"]
    gl_uid = auth_token["uid"]
    email = data['email']

    # Plugin specific data storage
    current_info = ::PluginStore.get("gl", "gl_uid_#{gl_uid}")

    # Check if the user is trying to connect an existing account
    unless current_info
      existing_user = User.where(email: email).first
      if existing_user
        ::PluginStore.set("gl", "gl_uid_#{data[:gl_uid]}", {user_id: existing_user.id })
        result.user = existing_user
      end
    else
      result.user = User.where(id: current_info[:user_id]).first
    end

    result.name = name
    result.extra_data = { gl_uid: gl_uid }
    result.email = email

    result
  end

  def after_create_account(user, auth)
    data = auth[:extra_data]
    ::PluginStore.set("gl", "gl_uid_#{data[:gl_uid]}", {user_id: user.id })
  end

  def register_middleware(omniauth)
    omniauth.provider :gitlab,
     GITLAB_APP_ID,
     GITLAB_SECRET,
     {
       client_options:
       {
         site: ENV['GITLAB_URL']
       }
     }
  end
end


auth_provider title: 'with GitLab',
    message: 'Log in via GitLab (Make sure pop up blockers are not enabled).',
    frame_width: 920,
    frame_height: 800,
    authenticator: GitLabAuthenticator.new

# Discourse ships with zocial http://zocial.smcllns.com/sample.html
# In our case we don't have an icon for GitLab.
register_css <<CSS

.btn-social.gitlab {
  background: #554488;
}

CSS
