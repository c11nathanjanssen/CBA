class Bill
  include ContentItem
  include VotingHelpers

  acts_as_content_item

  references_many :comments, :inverse_of => :commentable, :as => 'commentable'
  validates_associated :comments

  # needed for comments
  field :interpreter,                             :default => :markdown
  field :allow_comments,        :type => Boolean, :default => true
  field :allow_public_comments, :type => Boolean, :default => true

  # initial fields
  field :congress, :type => Integer
  field :bill_number, :type => Integer
  field :bill_type, :type => String

  field :last_updated, :type => Date
  # update fields from GovTrackBill

  field :bill_state, :type => String #
  field :introduced_date, :type => Date #
  field :title, :type => String
  index :title
  field :titles, :type => Array #
  field :summary, :type => String #
  field :bill_actions, :type => Array #

  index :created_at

  # things i get with an extra call
  field :bill_html, :type => String

  # things i calculate
  field :ident, :type => String
  field :cosponsors_count, :type => Integer
  field :govtrack_id, :type => String
  # add index
  field :govtrack_name, :type => String

  index :govtrack_name

  field :summary_word_count, :type => Integer
  field :text_word_count, :type => Integer

  field :text_updated_on, :type => Date
  field :hidden, :type => Boolean

  before_save :set_not_draft

  def set_not_draft
    self.is_draft = false
    true
  end

  # roll call results
  field :roll_time, :type => DateTime
  index :roll_time
  # TODO -- this is recorded in votes -- can't we delete?
  field :ayes, :type => Integer
  field :nays, :type => Integer
  field :abstains, :type => Integer
  field :presents, :type => Integer

  scope :house_bills, where(title: /^h/)
  scope :senate_bills, where(title: /^s/)
  scope :introduced_house_bills, where(title: /^h/).and(bill_state: /^INTRODUCED|REPORTED|REFERRED$/)
  scope :introduced_senate_bills, where(title: /^s/).and(bill_state: /^INTRODUCED|REPORTED|REFERRED$/)
  #scope :rolled_house_bills, where(title: /^h/).excludes(bill_state: /^INTRODUCED|REPORTED|REFERRED$/)
  #scope :rolled_senate_bills, where(title: /^s/).excludes(bill_state: /^INTRODUCED|REPORTED|REFERRED$/)

  # Person.where(:age.exists => true)
  scope :house_roll_called_bills, where(:roll_time.exists => true) # .descending(:roll_time)

  belongs_to :sponsor, :class_name => "Legislator"
  has_and_belongs_to_many :cosponsors, :order => :state, :class_name => "Legislator"
  has_and_belongs_to_many :subjects

  validates_presence_of :govtrack_name

  has_many :votes
  embeds_many :member_votes

  def activity?
    self.votes.size > 0 || self.member_votes.size > 0
  end

  # Mongoid::Errors::Validations: Validation failed - Title can't be blank.
  def short_title
    # we show the first short title
    txt = nil
    if self.titles
      the_short_title = self.titles.select { |type, txt| type == 'short' }
      unless the_short_title.empty?
        txt = the_short_title.first.last
      end
    else
      Rails.logger.warn "no titles for #{self.ident}"
    end
    txt
  end

  def chamber
    self.title[0] == "h" ? :house : :senate
  end

  def long_title
    txt = nil
    if self.titles
      official_title = self.titles.select { |type, txt| type == 'official' }
    else
      raise "No official title for #{self.ident}"
    end
    txt = official_title.first.last unless official_title.empty?
    txt
  end

  def bill_title
    short_title || long_title.truncate(75) || "no title available!"
  end

  def tiny_title
    self.title.capitalize
  end

  # ------------------- Public booher_modules aggregation methods -------------------

  def get_overall_users_vote
    common_id = PolcoGroup.where(type: :common).first.id
    process_votes(self.votes.where(polco_group_id: common_id).all.to_a)
  end

  def get_votes_by_name_and_type(name, type) # RECENT
                                             # we need to protect against a group named by the state
    process_votes(self.votes.all.select { |v| (v.polco_group.name == name && v.polco_group.type == type) })
  end

  def voted_on?(user)
    if vote = user.votes.where(bill_id: self.id).first
       vote.value
    end
  end

  def users_vote(user)
    if vote = self.votes.all.select { |v| v.user = user }.first
      vote.value
    else
      "none"
    end
  end

  def self.full_type(bill_type)
    case bill_type
      when 'h' then
        'H.R.'
      when 'hr' then
        'H.Res.'
      when 'hj' then
        'H.J.Res.'
      when 'hc' then
        'H.C.Res.'
      when 's' then
        'S.'
      when 'sr' then
        'S.Res.'
      when 'sj' then
        'S.J.Res.'
      when 'sc' then
        'S.C.Res.'
    end
  end

  def full_number
    case bill_type
      when 'h' then
        'H.R.'
      when 'hr' then
        'H.Res.'
      when 'hj' then
        'H.J.Res.'
      when 'hc' then
        'H.C.Res.'
      when 's' then
        'S.'
      when 'sr' then
        'S.Res.'
      when 'sj' then
        'S.J.Res.'
      when 'sc' then
        'S.C.Res.'
    end + ' ' + bill_number.to_s
  end

  def passed?
    !(self.bill_state =~ /^PASS_OVER|PASSED|PASS_BACK|ENACTED/).nil?
  end

  def update_legislator_counts
    unless self.sponsor.nil?
      self.sponsor.update_attribute(:sponsored_count, self.sponsor.sponsored.length)
    end
    cosponsors.each do |cosponsor|
      cosponsor.update_attribute(:cosponsored_count, cosponsor.cosponsored.length)
    end
    if self.hidden?
      self.sponsor = nil
      self.cosponsors = []
      self.bill_html = nil
    end
  end

  def get_latest_action
    last_action = self.bill_actions.sort_by { |dt, tit| dt }.last
    {:date => last_action.first, :description => last_action.last}
  end

  def update_bill
    # assumes self.govtrack_name
    if self.govtrack_name
      file_data = File.new("#{Rails.root}/data/bills/#{self.govtrack_name}.xml", 'r')
    else
      raise "The bill does not have the property govtrack_name."
    end
    bill = Feedzirra::Parser::GovTrackBill.parse(file_data)
    # check for changes
    if bill && (self.introduced_date.nil? || (bill.introduced_date.to_date > self.introduced_date))
      # front-matter
      puts "updating #{self.govtrack_name}"
      self.congress = bill.congress
      self.bill_type = bill.bill_type
      self.bill_number = bill.bill_number
      self.last_updated = bill.last_updated.to_date
      # get titles
      self.ident = "#{self.congress}-#{self.bill_type}#{self.bill_number}"
      self.govtrack_id = "#{self.bill_type}#{self.congress}-#{self.bill_number}"

      # get actions
      self.bill_state = bill.bill_state
      self.introduced_date = bill.introduced_date.to_date

      self.titles = get_titles(bill.titles)
      self.bill_actions = get_actions(bill.bill_actions)
      self.summary = bill.summary

      # update subjects
      self.subjects = []
      bill.subjects.each do |subject|
        self.subjects.push(Subject.find_or_create_by(:name => subject))
      end
      #puts "the bill is valid? #{self.valid?}"

      # sponsors
      save_sponsor(bill.sponsor_id)
      save_cosponsors(bill.cosponsor_ids) unless bill.cosponsor_ids.empty?

      # Yield to a block that can perform arbitrary calls on this bill
      if block_given?
        yield(self)
      end

      # bill text
      get_bill_text if self.bill_html.blank? || self.text_updated_on.blank? || self.text_updated_on < Date.parse(self.bill_actions.first.first)

      self.cosponsors_count = self.cosponsors.count
      self.text_word_count = self.bill_html.to_s.word_count
      self.summary_word_count = self.summary.to_s.word_count
      true
    else
      puts "no need to update #{self.govtrack_name}"
      false
    end

  end

  def get_bill_text
    bill_object = HTTParty.get("#{GOVTRACK_URL}data/us/bills.text/#{self.congress.to_s}/#{self.bill_type}/#{self.bill_type + self.bill_number.to_s}.html")
    self.bill_html = bill_object.response.body
    self.text_updated_on = Date.today
    Rails.logger.info "Updated Bill Text for #{self.ident}"
  end

  def save_sponsor(id)
    sponsor = Legislator.where(:govtrack_id => id).first

    if sponsor
      self.sponsor = sponsor
      # now add this bill to the sponsor
      self.save
      sponsor.bills.push(self)
      sponsor.save!
    else
      raise "sponsor not in database!"
    end
    self.save
  end

  def save_cosponsors(cosponsors)
    cosponsors.each do |cosponsor_id|
      cosponsor = Legislator.where(:govtrack_id => cosponsor_id).first
      if cosponsor
        self.cosponsors << cosponsor
      else
        raise "cosponsor not found"
      end
    end
    self.save
  end

  def get_titles(raw_titles)
    titles = Array.new
    raw_titles.each_slice(2) do |title|
      titles.push title
    end
    titles
  end

  def get_actions(raw_actions)
    actions = Array.new
    raw_actions.each_slice(2) do |action|
      actions.push action
    end
    actions.sort_by { |d, a| d }.reverse
  end

  def find_member_vote(member)
    if self.member_votes
      if vote = self.member_votes.where(legislator_id: member.id).first
        vote.value
      else
        ""
      end
    else
      "no member votes to search"
    end
  end

  def members_tally
    process_votes(self.member_votes)
  end

  # TODO -- need to write ways to get titles and actions for views (but not what we store in the db)

  private

  # added by nate
  def self.bill_search(search)
    puts search
    if search
      # you have to have a class to perform where on (i think)
      self.where(short_title: /#{search}/i)
    else
      # does scoped work with mongoid
      scoped
    end
  end
  
  #added by nate
  def self.district_search(search)
    puts search
    if search
      # you have to have a class to perform where on (i think)
      self.where(district: /#{search}/i)
    else
      # does scoped work with mongoid
      scoped
    end
  end
    
    
    #added by nate
  def self.polcogroup_search(search)
    puts search
    if search
      # you have to have a class to perform where on (i think)
      self.where(polcogroup: /#{search}/i)
    else
      # does scoped work with mongoid
      scoped
    end 
  end
  
end
