# -*- encoding : utf-8 -*-

#require 'openid/store/filesystem'
#require File.join(Rails.root,'config/omniauth_settings')
#Rails.application.config.middleware.use OmniAuth::Builder do
#  if defined? OMNIAUTH_GOOGLE
#    #provider :google_apps, OpenID::Store::Filesystem.new('/tmp/openid.store')
#    provider :google_apps, OpenID::Store::Filesystem.new('/tmp/openid.store'), :domain => 'gmail.com'
#  end
#  
#  if defined? OMNIAUTH_OPENID
#    provider :open_id, OpenID::Store::Filesystem.new(Rails.root+'/tmp/openid.store')
#  end
#  provider( :twitter, OMNIAUTH_TWITTER_KEY, OMNIAUTH_TWITTER_SECRET, {:client_options => {:ssl => {:ca_path => OMNIAUTH_CAPATH}}} ) if defined?(OMNIAUTH_TWITTER_KEY)
#  provider( :facebook, OMNIAUTH_FACEBOOK_KEY, OMNIAUTH_FACEBOOK_SECRET) if defined?(OMNIAUTH_FACEBOOK_KEY)
#  provider( :linked_in, OMNIAUTH_LINKED_IN_KEY, OMNIAUTH_LINKED_IN_SECRET) if defined?(OMNIAUTH_LINKED_IN_KEY)
#  #provider( :thirty_seven_signals, OMNIAUTH_BASECAMP_ID, OMNIAUTH_BASECAMP_SECRET) if defined?(OMNIAUTH_BASECAMP_ID)
#  provider( :github, OMNIAUTH_GITHUB_ID, OMNIAUTH_GITHUB_SECRET) if defined?(OMNIAUTH_GITHUB_ID)
#  provider( :campus, OMNIAUTH_CAMPUS_ID, OMNIAUTH_CAMPUS_SECRET, OMNIAUTH_CAMPUS_URL) if defined?(OMNIAUTH_CAMPUS_ID)
#  #provider :LDAP, "LDAP-Login #{LDAP_HOST}", { :host => LDAP_HOST, :port => LDAP_PORT, :method => :plain,
#  #         :base => LDAP_TREEBASE, :uid => 'uid', :bind_dn => "uid=%s,cn=users,dc=xs1,dc=intern,dc=wwedu,dc=com" }
#end


#module OmniAuth
#  module Strategies
#    autoload :Campus, File::join(Rails.root,'lib/campus_authorization')
#  end
#end