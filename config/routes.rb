# -*- encoding : utf-8 -*-

Cba::Application.routes.draw do

  #resources :bill_comments

  #resources :member_votes

  get "search/index"

  resources :polco_groups

  resources :votes

  resources :legislators

  resources :bills

  match "/bills/vote_on_bill/:id/:value" => "bills#vote_on_bill", :as => :vote_on_bill

  match "/users/geocode" => "users#geocode"

  match "/users/save_geocode" => "users#save_geocode"

  match "/users/district" => "users#district"

  # Switch locales
  match 'switch_lcoale/:locale' => "home#set_locale", :as => 'switch_locale'
  
  # Switch draft mode
  match 'draft_mode/:mode' => "home#set_draft_mode", :as => 'draft_mode'

  match 'search' => "search#index", :as => 'searches'

  # Comments
  resources :comments, :except => :show

  # SiteMenu
  resources :site_menus do
    collection do
      post :sort_menus
    end
  end

  # BLOGS
  resources :blogs do
    member do
      get :delete_cover_picture
    end
    resources :postings do
      member do
        get :delete_cover_picture
      end
      resources :comments
    end
  end
  resources :postings, :only => [:show]

  match 'feed' => "home#rss_feed", :as => 'feed'

  # PAGES
  match '/p/:permalink' => 'pages#permalinked', :as => 'permalinked'
  resources :pages do
    member do
      get :delete_cover_picture
      get :sort_components
      post :sort_components
    end
    collection do
      get  :new_article
      post :create_new_article
      get  :templates
    end
    resources :comments
    resources :components
  end

  # PAGE TEMPLATES
  resources :page_templates

  # USERS
  match 'registrations' => 'users#index', :as => 'registrations'
  match 'hide_notification/:id' => 'users#hide_notification', :as => 'hide_notification'
  match 'show_notification/:id' => 'users#show_notification', :as => 'show_notification'
  match 'notifications' => 'users#notifications', :as => 'notifications'
  match 'profile/:id'   => 'users#show', :as => 'profile'

  devise_for :users, :controllers => { :registrations => 'registrations' }
  resources :users, :only => [:show,:destroy] do
    resources :invitations
    member do
      get :crop_avatar
      put :crop_avatar
      get :edit_role
      put :update_role
      get :details
    end
  end

  # AUTHENTICATIONS
  match '/auth/:provider/callback' => 'authentications#create'
  resources :authentications, :only => [:index,:create,:destroy]
  match '/auth/failure' => 'authentications#auth_failure'

  # ROOT
  root :to => 'home#index'

end
