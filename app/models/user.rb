# -*- encoding : utf-8 -*-

# This is a Device-User-Class extended with ROLES, Avatar-handling, and more
class User
  include Mongoid::Document
  include Mongoid::Spacial::Document # GeoIndex
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Geocoder::Model::Mongoid

  geocoded_by :coordinates
  # TODO ^^ is this still needed?
  cache

  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  field :name, :type => String
  field :roles_mask, :type => Fixnum, :default => 0
  field :use_gravatar, :type => Boolean, :default => true
  field :invitation_id, :type => BSON::ObjectId
  # tbb modifications for polco specific code
  field :zip_code, :type => String
  field :coordinates, :type => Array

  field :us_state, :type => String # TODO enum for this?
  field :district, :type => String

  has_many :custom_groups, :class_name => "PolcoGroup", :inverse_of => :owner

  has_many :votes

  has_and_belongs_to_many :joined_groups, :class_name => "PolcoGroup", :inverse_of => :members

  has_and_belongs_to_many :followed_groups, :class_name => "PolcoGroup", :inverse_of => :followers

  has_and_belongs_to_many :senators, :class_name => "Legislator", :inverse_of => :state_constituents
  belongs_to :representative, :class_name => "Legislator", :inverse_of => :district_constituents

  #after_save :update_member_count

  def invitation
    @invitation ||= Invitation.criteria.for_ids(self.invitation_id).first
  end

  def invitation=(inv)
    @invitation = nil
    self.invitation_id = inv.id
  end

  field :location, type: Array, spacial: true

  def articles
    []
  end

  references_many :authentications, :dependent => :delete
  references_many :postings, :dependent => :delete
  references_many :invitations, :dependent => :delete

  embeds_many :user_notifications
  embeds_many :user_groups
  has_many    :articles

  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
  validates :email, :presence => true, :email => true
  validates_uniqueness_of :email, :case_sensitive => false


  attr_accessible :name, :email, :password, :password_confirmation, :roles_mask,
                  :remember_me, :authentication_token, :confirmation_token,
                  :avatar, :clear_avatar, :crop_x, :crop_y, :crop_w, :crop_h,
                  :time_zone, :language, :use_gravatar, :invitation_id,
                  :location_token

  attr_accessor :clear_avatar

  has_mongoid_attached_file :avatar,
                            :styles => {
                                :popup => "800x600=",
                                :medium => "300x300>",
                                :thumb => "100x100>",
                                :icon => "64x64"
                            },
                            :processors => [:cropper]
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h
  after_update  :reprocess_avatar, :if => :cropping?

  # Notifications
  after_create   :async_notify_on_creation
  before_destroy :async_notify_on_cancellation
  before_update  :notify_if_confirmed

  # Authentications
  after_create :save_new_authentication
  after_create :first_user_hook

  # Roles - Do not change the order and do not remove roles if you
  # already have productive data! Thou it's safe to append new roles
  # at the end of the string. And it's safe to rename roles in place
  ROLES = [:guest, :confirmed_user, :author, :moderator, :maintainer, :admin, :registered]

  scope :with_role, lambda { |role| {:where => {:roles_mask.gte => ROLES.index(role)}} }

  def bills_voted_on(chamber)
    # the bills in the table are ordered by most recent at the top
    votes = self.votes.all.to_a.select{|v| v.bill.chamber == chamber}.sort_by(&:created_at).map(&:bill).uniq
  end

  def registered?
    (self.role == :registered || !self.zip_code.nil?)
  end

  def cropping?
    !crop_x.blank? && !crop_y.blank? && !crop_w.blank? && !crop_h.blank?
  end

  def avatar_geometry(style = :original)
    paperclip_geometry avatar, style
  end

  def new_avatar?
    if avatar.updated_at && ((Time::now() - Time::at(self.avatar.updated_at)) < 1.minute)
      self.use_gravatar = false
      save
      true
    else
      false
    end
  end

  def admin?
    User.all.any? ? (self == User.first || role?(:admin)) : true
  end

  def role=(role)
    self.roles_mask = ROLES.index(role)
    Rails.logger.warn("SET ROLES TO #{self.roles_mask} FOR #{self.inspect}")
  end

  # return user's role as symbol.
  def role
    ROLES[roles_mask].to_sym
  end

  # Ask if the user has at least a specific role.
  #   @user.role?('admin')
  def role?(role)
    self.roles_mask >= ROLES.index(role.to_sym)
  end

  # virtual attribute needed for the view but is false always.
  def clear_avatar
    false
  end

  # clear a previous uploaded avatar-image.
  def clear_avatar=(new_value)
    self.avatar = nil if new_value == '1'
  end

  # fetch attributes from the omniauth-record.
  def apply_omniauth(omniauth)
    self.email = omniauth['user_info']['email'] if email.blank?
    apply_trusted_services(omniauth) if self.new_record?
    authentications.build(:provider => omniauth['provider'], :uid => omniauth['uid'])
  end

  # remove the password and password-confirmation attribute if not needed.
  def update_with_password(params={})
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end
    super
  end

  # Remove an URL of the local avatar or the gravatar
  def avatar_url(mode)
    if self.use_gravatar
      "http://gravatar.com/avatar/#{gravatar_id}.png?cache=#{self.updated_at.strftime('%Y%m%d%H%M%S')}"
    else
      avatar.url(mode)
    end
  end

  # Link to the gravatar profile
  def gravatar_profile
    if self.use_gravatar
      "http://gravatar.com/#{gravatar_id}"
    end
  end

  def vote_on(bill, value)
    puts "test"
    # test to make sure the user is a member of a group
    my_groups = self.joined_groups
    puts "joined group size is #{my_groups.size}"
    unless my_groups.empty?
      unless bill.voted_on?(self)
        my_groups.each_with_index do |g, i|
          puts "processing #{value} for #{self} name: #{g.name} bill: #{bill.title} index #{i}"
          unless Vote.create(:value => value, :user => self, :polco_group => g, :bill => bill)
             raise "vote not valid"
          else
            puts "created vote #{value} for group #{g.name}"
          end
        end
      else
        Rails.logger.warn "already voted on"
        puts "all ready voted on"
        false
        #raise "already voted on"
      end
      #bill.save!
    else
      raise "no joined_groups for this user"
    end
  end

  # district fun
  def get_district_from_coords(coords)
    lat, lon = coords # .first, coords.last
    self.coordinates = [lat, lon]
    feed_url = "#{GOVTRACK_URL}perl/district-lookup.cgi?lat=#{lat}&long=#{lon}"
    feed = Feedzirra::Feed.fetch_raw(feed_url)
    if feed == 0
      raise "Failed to connect to #{feed_url}"
    else
      govtrack_data = Feedzirra::Parser::GovTrackDistrict.parse(feed)
    end
    if govtrack_data.districts.count > 1
      raise "too many for this coordinate (strange)"
    else
      result = govtrack_data.districts.first
      result.district = "#{result.us_state}#{"%02d" % result.district.to_i}"
    end
    [result]
  end

  def get_districts_by_zipcode(zipcode)
    feed_url = "#{GOVTRACK_URL}perl/district-lookup.cgi?zipcode=#{zipcode}"
    feed = Feedzirra::Feed.fetch_raw(feed_url)
    districts = Feedzirra::Parser::GovTrackDistrict.parse(feed).districts
    districts.each do |d|
      d.district = "#{d.us_state}#{"%02d" % d.district.to_i}"
    end
    districts
  end

  def add_district_data(junior_senator, senior_senator, representative, district, us_state)
    self.senators.push(junior_senator)
    self.senators.push(senior_senator)
    self.representative = representative
    self.district = district
    self.add_baseline_groups(us_state, district)
    self.role = :registered # 7 = registered (or 6?)
    self.save!
  end

  def add_baseline_groups(us_state, district)
    [[us_state, :state],[district, :district],['USA', :country],['Dan Cole',:common]].each do |name, type|
       g = PolcoGroup.find_or_create_by(:name => name, :type => type)
       #g.members.push(self)
       g.member_count += 1
       # but what if the user is already in this group?
       puts self.joined_groups.inspect
       self.joined_groups.push(g) unless self.joined_groups.include?(g)
    end
  end

  def get_members(members)
    legs = []
    members.each do |member|
      # need to clear previous members
      if leg = Legislator.where(:govtrack_id => member.govtrack_id).first
        legs << leg
      else
        raise "legislator #{member.govtrack_id} not found"
      end
    end
    # TODO -- mongo this
    senators = legs.select { |l| l.title == 'Sen.' }.sort_by { |u| u.start_date }
    members = Hash.new
    members[:senior_senator] = senators.first
    members[:junior_senator] = senators.last
    members[:representative] = (legs - senators).first
    members
  end

=begin
  def save_district_and_members(district, result)
    # TODO -- UPDATE
    self.district = district
    self.legislators = []
    result.members.each do |member|
      # need to clear previous members
      if leg = Legislator.where(:govtrack_id => member.govtrack_id).first
        self.legislators << leg
      else
        raise "legislator #{member.govtrack_id} not found"
      end
    end
    self.save!
  end
=end

  def get_geodata(params)
    case params[:commit]
      when "Yes" # the location is coming coming in from an ip lookup
        result = Geocoder.coordinates(params[:location])
        method = :ip_lookup
      when "Submit Address" # then, we have an address to code
        address = build_address(params)
        result = Geocoder.coordinates(address)
        method = :address
      when "Submit Zip Code" # we have a zip code to code
        result = get_district_by_zipcode(params[:zip_code])
        method = :zip_code
      when "Confirm address"
        result = params[:address]
        method = :confirmed_address
      else # they did a zip code lookup
        result = nil #Geocoder.coordinates(params[:full_zip])
        method = :none
    end
    {:geo_data => result, :method => method}
  end

  def get_ip(ip)
    Geocoder.coordinates(ip)
  end

  def joined_groups_tallies(bill)
    # the purpose of this is to show the tallies of all the groups
    # a member has joined. so we go through each joined group and add them up
    # for this bill -- this could be refactored significantly
    # TODO -- refactoring
    results = Array.new
    puts "joined groups size:"
    puts self.joined_groups.size
    puts "the big inspection"
    self.joined_groups.each do |t|
      puts "*****8282832*****"
      puts t.inspect
    end
    puts "8************************8"
    self.joined_groups.each_with_index do |g,i|
      puts "%% happy %%" + g.name + "!!" + i.to_s
      name = g.name
      # we should use the Vote table here!
      tally = bill.get_votes_by_name_and_type(g.name, g.type)
      puts "*****"
      puts tally
      puts "*****"
      results.push({:name => name, :tally => tally})
    end
    results
  end

  def followed_groups_tallies(bill)
    results = Array.new
    self.followed_groups.each do |g|
      name = g.name
      tally=bill.get_votes_by_name_and_type(g.name, g.type)
      results.push({:name => name, :tally => tally})
    end
    results
  end

  def district_number
    self.district.match(/\d+/)[0]
  end

  def reps_vote_on(house_bill)
    unless house_bill.member_votes.empty?
      leg = self.representative # Legislator.where(state: self.us_state, district: self.district_number.to_i).first
      if leg
        out = {:rep => leg.full_name, :vote => house_bill.find_member_vote(leg)}
      else
        raise "no representative found for #{self.name}"
      end
    else
      out = "no vote available"
    end
    out
  end

  def get_district
    PolcoGroup.where(name: self.district).and(type: :district).first
  end

  def senators_vote_on(senate_bill)
    out = Array.new
    unless senate_bill.member_votes.empty?
      legs = self.senators #.senators.where(state: self.us_state)
      # result is mongoid criteria
      if legs
        legs.each do |senator|
          # what if the member_vote is not found?
          if senate_bill.find_member_vote(senator)
            out.push({:senator=> senator.full_title, :vote => senate_bill.find_member_vote(senator)})
          else
            raise "#{senator.full_name} does not have a recorded record for #{senate_bill.title}"
          end
        end # legislators iteration
      else
        raise "no senators found for #{self.us_state}"
      end
    else
      out = "Your senators have not yet voted on #{senate_bill.tiny_title}"
    end
    out
  end
  
  def all_groups
    (u.followed_groups + u.joined_groups).sort_by(&:vote_count)
  end

  def non_district_groups_for_bill(bill)
    group_ids = (self.followed_groups + self.joined_groups).delete_if{|g| g.type == :district}.map(&:id)
    Vote.where(bill_id: bill.id).also_in(polco_group_id: group_ids).to_a.map{|v| v.polco_group}.uniq
  end
  
  def all_groups_for_bill(bill)
    # TODO --- optimize for mongoid
    # here we want to know if this user has any custom groups that have related votes on this bill
    # clearly this has to be based on the transactional database and not off of ruby code
    # we get this from the Vote object, which is heavily indexed
    group_ids = (self.followed_groups + self.joined_groups).map(&:id)
    Vote.where(bill_id: bill.id).also_in(polco_group_id: group_ids).to_a.map{|v| v.polco_group}.uniq
    #(self.followed_groups + self.joined_groups).select{|g| g.type == :custom && g.votes.map(&:bill).include?(bill)}
    # wow -- this is really tricky!!!! (and back-handed, but i think this is better than)
    # no, it cant' be done without a good bit of de-normalization (!!)
  end

  # purpose is to update the member count for each group
  # this is done every time a member is saved
  def update_member_count
    self.joined_groups.each do |jg|
      puts "calling for #{jg.name}"
      jg.update_followers_and_members
      jg.save
    end
    self.followed_groups.each do |fg|
      puts "calling for #{fg.name}"
      fg.update_followers_and_members
      fg.save
    end
  end

  def location_token
    if self.location[:lat].present? && self.location[:lng].present?
      "%3.4f,%3.4f" % [self.location[:lat], self.location[:lng]]
    end
  end

  def location_token=(str)
    coordinates = str.split(",").map! { |a| a.strip.gsub(/\(|\)/,'') }
    self.location = {
      lat: coordinates[0].to_f,
      lng: coordinates[1].to_f
    }
  end

  
private
  def reprocess_avatar
    avatar.reprocess!
  end

  def gravatar_id
    Digest::MD5.hexdigest(self.email.downcase) if self.email
  end

  def apply_trusted_services(omniauth)

    # Merge user_info && extra.user_info
    user_info = omniauth['user_info']
    if omniauth['extra'] && omniauth['extra']['user_hash']
      user_info.merge!(omniauth['extra']['user_hash'])
    end

    # try name or nickname
    if self.name.blank?
      self.name = user_info['name'] unless user_info['name'].blank?
      self.name ||= user_info['nickname'] unless user_info['nickname'].blank?
      self.name ||= (user_info['first_name']+" "+user_info['last_name']) unless \
             user_info['first_name'].blank? || user_info['last_name'].blank?
    end

    if self.email.blank?
      self.email = user_info['email'] unless user_info['email'].blank?
    end

    # Set a random password for omniauthenticated users
    self.password, self.password_confirmation = String::random_string(20)
    self.confirmed_at, self.confirmation_sent_at = Time.now

    # Build a new Authentication and remember until :after_create -> save_new_authentication
    @new_auth = authentications.build(:uid => omniauth['uid'], :provider => omniauth['provider'])
  end

# Called :after_create
  def save_new_authentication
    @new_auth.save unless @new_auth.nil?
  end

# Inform admin about sign ups and cancellations of accounts
  def async_notify_on_creation
    DelayedJob.enqueue('NewSignUpNotifier', Time.now, self.id)
  end

# Inform admin about cancellations of accounts
  def async_notify_on_cancellation
    DelayedJob.enqueue('CancelAccountNotifier', Time.now, self.inspect)
  end

# Inform admin if someone confirms an account
  def notify_if_confirmed
    if attribute_changed?('confirmed_at')
      DelayedJob.enqueue('AccountConfirmedNotifier', Time.now, self.id)
    end
  end

# If created user is first user, confirm and make admin
  def first_user_hook
    if User.count < 2
      self.confirmed_at = Time.now
      self.role=:admin
      self.save!
    end
  end

end

