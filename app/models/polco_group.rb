class PolcoGroup
  include ContentItem
  include VotingHelpers
  
  acts_as_content_item
  has_cover_picture

  references_many :comments, :inverse_of => :commentable, :as => 'commentable'
  validates_associated :comments

  # needed for comments
  field :interpreter,                             :default => :markdown
  field :allow_comments,        :type => Boolean, :default => true
  field :allow_public_comments, :type => Boolean, :default => true

  field :name, :type => String
  field :type, :type => Symbol, :default => :custom
  field :description, :type => String
  index :name
  index :type
  field :vote_count, :type => Integer, :default => 0
  field :follower_count, :type => Integer, :default => 0
  field :member_count, :type => Integer, :default => 0
  index :follower_count
  index :member_count
  index :vote_count

  belongs_to :owner, :class_name => "User", :inverse_of => :custom_groups

  has_and_belongs_to_many :members, :class_name => "User", :inverse_of => :joined_groups
  has_and_belongs_to_many :followers, :class_name => "User", :inverse_of => :followed_groups

  has_many :votes

  #before_validation :make_title

  def make_title
    puts "making title and setting draft to false for #{self.name}"
    self.title = "#{self.name}_#{self.type}"
    self.is_draft = false
    true
  end

  def add_member(user_obj)
    self.members.push(user_obj)
    self.member_count += 1
    self.save
  end

  #we want to increment member_count when a new member is added
  #before_save :update_followers_and_members

  # some validations
  validates_uniqueness_of :name, :scope => :type
  validates_inclusion_of :type, :in => [:custom, :state, :district, :common, :country], :message => 'Only valid groups are custom, state, district, common, country'

  scope :states, where(type: :state)
  scope :districts, where(type: :district)
  scope :customs, where(type: :custom)

  # time to create the ability to follow

  def update_followers_and_members
    #self.reload
    #puts "follower size #{self.follower_ids.size}"
    self.follower_count = self.follower_ids.size
    #puts "member size #{self.member_ids.size}"
    self.member_count = self.member_ids.size
    puts "now followers #{self.follower_count} and members #{self.member_count} for #{self.name}"
    puts "is the model valid #{self.valid?}"
  end

  def the_rep
    if self.type == :district
      if self.name =~ /([A-Z]{2})-AL/ # then there is only one district
        puts "The district is named #{self.name}"
        l = Legislator.where(state: $1).where(district: 0).first
      else # we have multiple districts for this state
        data = self.name.match(/([A-Z]+)(\d+)/)
        state, district_num = data[1], data[2].to_i
        l = Legislator.representatives.where(state: state).and(district: district_num).first
        #l = Legislator.all.select { |l| l.district_name == self.name }.first
      end
    else
      l = "Only districts can have a representative"
    end
    l || "Vacant"
  end

  def get_bills
    # TODO -- set this to the proper relation
    # produces bills
    Vote.where(polco_group_id: self.id).desc(:updated_at).all.to_a
  end

  def build_group_tally
    self.votes.map(&:bill).uniq
  end

  def get_votes_tally(bill)
    # TODO -- need to make this specific to a bill, not all votes of the polco group
    process_votes(self.votes.where(bill_id: bill.id).all.to_a)
  end

  def senators
    if self.type == :state
      Legislator.senators.where(state: self.name).all.to_a
    else
      nil
    end
  end

  def senators_hash
    if self.type == :state
      legs=Legislator.senators.where(state: self.name).all.to_a.sort_by { |u| u.start_date }
      {junior_senator: legs.last, senior_senator: legs.first}
    else
      nil
    end
  end

end
