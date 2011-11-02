# -*- encoding : utf-8 -*-

Cba::Application.routes.draw do

  # S2
  #get "bills/state_results"

  resources :subjects

  #resources :bill_comments

  #resources :member_votes

  get "search/index"
  get "home/polco_info"

  match "/polco_groups/manage_groups" => "polco_groups#manage_groups", :as => :manage_groups
  match "/polco_groups/update_groups" => "polco_groups#update_groups", :as => :update_groups

  # these are for json output only to manage groups
  match "/polco_groups/state_groups" => "polco_groups#state_groups"
  match "/polco_groups/district_groups" => "polco_groups#district_groups"
  match "/polco_groups/custom_groups" => "polco_groups#custom_groups"

  #match "/bills/senate_results" => "bills#senate_results"
  # H1. HB and S1. SB
  match "/introduced_bills/:chamber(/:bill_type(/:id))" => "bills#e_ballot", :as => :e_ballot

  # the new H2
  match "house/districts_and_reps" => "polco_groups#districts_and_reps"
  # now S2
  match "senate/states_and_senators" => "polco_groups#states_and_senators"

  # just a form process page
  match "/bills/process_page" => "bills#process_page"
  match "/users/blog/:username(/:comment_id)" => "users#blog"

  match "/bills/text/:id" => "bills#show_bill_text", :as => :full_bill_text

  resources :polco_groups  do
    resources :comments
  end

  # TODO -- might be deprecated since it is embedded
  resources :votes

  # index is H2, show is H2b
  resources :legislators do
    resources :comments
  end

  # H3. and S3 house results -- how represented are you in the house?
  match "/representation/:chamber" => "bills#results"

  # show is H1b and S1b
  resources :bills do
    resources :comments
  end

  match "/bills/vote_on_bill/:id/:value" => "bills#vote_on_bill", :as => :vote_on_bill

  match "/users/geocode" => "users#geocode"

  match "/users/save_geocode" => "users#save_geocode"

  match "/users/district" => "users#district"

  # Switch locales
  match 'switch_locale/:locale' => "home#set_locale", :as => 'switch_locale'
  
  # Switch draft mode
  match 'draft_mode/:mode' => "home#set_draft_mode", :as => 'draft_mode'

  match 'search' => "search#index", :as => 'searches'

  # Comments
  resources :comments, :except => :show
  
  # Tags
  match '/tag/:tag' => "home#tags", :as => 'tags'

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
  resources :postings, only: [:show] do
    collection do
      get :tags
    end
  end

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
    resources :page_components
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
    resources :user_groups
    resources :user_notifications
    member do
      get :crop_avatar
      put :crop_avatar
      get :edit_role
      put :update_role
      get :details
    end
    collection do
      get :autocomplete_ids
    end
  end

  # AUTHENTICATIONS
  match '/auth/:provider/callback' => 'authentications#create'
  resources :authentications, :only => [:index,:create,:destroy]
  match '/auth/failure' => 'authentications#auth_failure'

  resources :user_notifications do
    collection do
      get :emails
    end
  end

  # ROOT
  root :to => "bills#e_ballot"

end
