class PolcoGroup
  include Mongoid::Document
  #include ContentItem
  #acts_as_content_item
  #has_cover_picture
  include VotingHelpers

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

  #we want to increment member_count when a new member is added
  before_save :update_followers_and_members

  # some validations
  validates_uniqueness_of :name, :scope => :type
  validates_inclusion_of :type, :in => [:custom, :state, :district, :common, :country], :message => 'Only valid groups are custom, state, district, common, country'

  scope :states, where(type: :state)
  scope :districts, where(type: :district)
  scope :customs, where(type: :custom)

  # time to create the ability to follow

  def update_followers_and_members
    #self.reload
    self.follower_count = self.followers.size
    self.member_count = self.members.size
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

  def get_votes_tally
    # TODO -- need to make this specific to a bill, not all votes of the polco group
    process_votes(self.votes)
  end

  def senators
    if self.type == :state
      Legislator.senators.where(state: self.name).all.to_a
    else
      nil
    end
  end

end
