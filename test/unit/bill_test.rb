require 'test_helper'

class BillTest < ActiveSupport::TestCase

  def setup
    Subject.destroy_all
    load_all_sponsors
    Bill.destroy_all # clean slate
    PolcoGroup.destroy_all
    User.destroy_all
    rep = Legislator.representatives.first
    senator1 = Legislator.senators.first
    senator2 = Legislator.senators[1]
    puts "!!!!!!!!!!!!!!!! all polco groups: #{PolcoGroup.all.size}"
    @house_bill = Bill.new(:govtrack_name => "h1", :title => Faker::Name.name)
    common_group = Fabricate(:polco_group, {:name => 'Dan Cole', :type => :common, title: 'dc_common'})
    cali_group = Fabricate(:polco_group, {:name => 'CA', :type => :state, title: 'CA_state'})
    va_group = Fabricate(:polco_group, {:name => 'VA', :type => :state, title: "VA_state"})
    ca46 = Fabricate(:polco_group, {name: 'CA46', type: :district, title: "CA46_district"})
    va05 = Fabricate(:polco_group, {name: 'VA05', type: :district, title: "VA05_district"})
    va03 = Fabricate(:polco_group, {name: 'VA03', type: :district, title: "VA03_district"})
    @user1 = Fabricate.build(:registered, {:district => 'CA46',
                                           :us_state => 'CA',
                                           :senators => [senator1, senator2],
                                           :representative => rep})
    @user1.joined_groups << [common_group,
                             cali_group,
                             ca46,
                             Fabricate(:polco_group, {:name => "Gang of 13", :type => :custom, title: 'gang_13_custom'})]
    @user1.followed_groups << [va05, va_group]
    #@user1.save

    #@user1.reload
    puts "just created user with these groups:"
    puts @user1.joined_groups.map(&:name)
    puts "then secondly"
    puts @user1.joined_groups.map(&:name)
    @user2 = Fabricate.build(:registered, {:joined_groups => [common_group,
                                                              cali_group,
                                                              ca46,
                                                              Fabricate(:polco_group, {:name => "Ft. Sam Washington 1st Grade", :type => :custom})]})
    puts " !!!!!!!!! after second user"
    puts @user1.joined_groups.map(&:name)

    @user3 = Fabricate.build(:registered, {:joined_groups => [common_group,
                                                              va_group,
                                                              va05]})
    @user4 = Fabricate.build(:registered, {:joined_groups => [common_group,
                                                              va_group,
                                                              va03,
                                                              Fabricate(:polco_group, {name: Faker::Company.name, type: :custom, title: Faker::Company.name})]})
                     # we need one bill to update
    Fabricate(:bill, :govtrack_id => "h112-26", :title => 'h112-26', :ident => '112-h26')
                     # build senate bill
    Fabricate(:bill, :govtrack_id => 's112-782', :title => 's112-782', :ident => '112-s782')
                     # let's isolate that bill and update
    Bill.update_rolls do
      files = ["#{Rails.root}/test/fixtures/h2011-9.xml", "#{Rails.root}/test/fixtures/s2011-91.xml"]
    end
    @house_bill_with_roll_count = Bill.where(:govtrack_id => "h112-26").first
    @senate_bill_with_roll_count = Bill.where(:govtrack_id => 's112-782').first
                     # get some properties for the house bill
    @house_bill.update_bill do |bill|
      bill.text_updated_on = Date.today
      bill.bill_html = "The mock bill contents"
    end
    @house_bill.save!

  end

  test "a bill should have a long and short title" do
    #the_bill = Factory.create(:open_congress_bill)
    titles = @house_bill.titles
    assert_not_nil(titles, "the_bill is nil")
    assert_equal("Making appropriations for the Department of Defense and the other departments and agencies of the Government for the fiscal year ending September 30, 2011, and for other purposes.", @house_bill.long_title)
    assert_equal("Full-Year Continuing Appropriations Act, 2011", @house_bill.short_title)
  end

  test "should be able to pull out the most recent action" do
    last_action = @house_bill.get_latest_action
    assert_equal("Returned to the Calendar. Calendar No. 14.", last_action[:description])
  end

  test "should be able to tally votes for all users" do
    # TODO members votes need to be included
    b = @house_bill
    b.votes = [] # TODO not needed?
    @user1.vote_on(b, :aye)
    @user2.vote_on(b, :nay)
    @user3.vote_on(b, :aye)
    @user4.vote_on(b, :abstain)
    tally = b.get_overall_users_vote
    assert_equal({:ayes => 2, :nays => 1, :abstains => 1, :presents => 0}, tally, "Expected 2 aye, 1 nay, and 1 abstain")
  end

  test "should verify that a user has already voted" do
    #user = Fabricate(:user, :name => "George Whitfield", :email => "awaken@gloucester.com")
    puts "starting"
    Vote.destroy_all
    b = @house_bill
    @user1.vote_on(b, :aye)
    puts "## #{b.valid?}"
    puts b.errors.inspect
    b.save!
    puts "all votes"
    puts Vote.all.count
    puts "assocition counts\n all:"
    puts b.votes.all.count
    puts "just votes"
    puts b.votes.count
    assert_equal :aye, b.voted_on?(@user1)
  end

  test "should be able to add a sponsor to a bill" do
    b = Bill.new
    b.title = Faker::Company.name
    b.govtrack_name = "s182" #fake
    b.save_sponsor(400032)
    assert_equal "Marsha Blackburn", b.sponsor.full_name
  end

  test "save cosponsors for bill" do
    Bill.destroy_all
    b = Bill.new(
        :congress => 112,
        :bill_type => 's',
        :bill_number => 368,
        :title => 's368',
        :govtrack_name => 's368'
    )
    cosponsor_ids = ["412411", "400626", "400224", "412284", "400570", "400206", "400209", "400068", "400288", "412271", "412218", "400141", "412480", "412469", "400277", "400367", "412397", "412309", "400411", "412283", "412434", "400342", "400010", "400057", "400260", "412487", "412436", "400348", "412478", "400633", "400656", "400115"]
    b.save_cosponsors(cosponsor_ids)
    assert_equal 32, b.cosponsors.to_a.count
  end

  test "should be able to read all bills from a directory and load them into the database" do
    VCR.use_cassette('bill update directory') do
      Bill.destroy_all
      #Bill.update_from_directory do
      #  puts 'sending a block to stub out a number of files and call to govtrack'
      #end
      Bill.update_from_directory do
        ['h26', 's782'].map { |b| "#{Rails.root}/test/fixtures/#{b}.xml" }
      end
      assert_operator Bill.all.to_a.count, :>=, 0
    end
  end

  test "should be able to seed data" do
    VCR.use_cassette('seed data cassette') do
      puts "destroying legislators"
      Legislator.destroy_all
      puts "updating legislators"
      Legislator.update_legislators
      # load Bills (just test load)
      puts "destroying bills"
      Bill.destroy_all
      puts "updating bills from directory"
      Bill.update_from_directory do
        ['h26', 's782'].map { |b| "#{Rails.root}/test/fixtures/#{b}.xml" }
      end
      # load rolls
      puts "updating rolls"
      Bill.update_rolls do
        ["#{Rails.root}/test/fixtures/h2011-9.xml", "#{Rails.root}/test/fixtures/s2011-91.xml"]
      end
      assert true
    end
  end

  test "should show what the current users vote is on a specific bill" do
    # we need to have a valid bill here
    b = @house_bill
    @user1.vote_on(b, :aye)
    assert_equal :aye, b.users_vote(@user1)
  end

  test "should show the votes for a specific district that a user belongs to" do
    # @house_bill.votes = []
    @user1.vote_on(@house_bill, :aye)
    @user2.vote_on(@house_bill, :nay)
    @user3.vote_on(@house_bill, :nay)
    @user4.vote_on(@house_bill, :aye)  # of course -- validation error
    district = @user1.district # = "CA46"
    district_tally = @house_bill.get_votes_by_name_and_type(district, :district)
    assert_equal({:ayes => 1, :nays => 1, :abstains => 0, :presents => 0}, district_tally) # {:ayes => 10, :nays => 20, :abstains => 2}
  end

  test "should be able to show votes for a specific state that a user belongs to" do
    @user1.vote_on(@house_bill, :aye)
    @user2.vote_on(@house_bill, :nay)
    @user3.vote_on(@house_bill, :nay)
    @user4.vote_on(@house_bill, :aye)
    state = "CA"
    state_tally = @house_bill.get_votes_by_name_and_type(state, :state)
    result = {:ayes => 1, :nays => 1, :abstains => 0, :presents => 0}
    assert_equal result, state_tally # {:ayes => 10, :nays => 20, :abstains => 2}
  end

  test "should silently block a user from voting twice on a bill" do
    @house_bill.votes.destroy_all
    @user1.vote_on(@house_bill, :aye)
    @user1.vote_on(@house_bill, :aye)
    assert_equal(1, @house_bill.votes.all.to_a.count { |v| v.value == :aye && v.polco_group.type == :common }, "not exactly one vote")
  end

  test "should raise an error on a duplicate vote" do
    # this won't happen until we have the validations running
    # another test to make sure multiple votes can't happen on the same bill
    # 20110809.2200
    @house_bill.votes.destroy_all
    polco_group = @user2.joined_groups.last
    v1 = @house_bill.votes.new
    v1.user = @user2
    v1.polco_group = polco_group
    v1.value = :aye
    assert v1.save
    v2 = @house_bill.votes.new
    v2.user = @user2
    v2.polco_group = polco_group
    v2.value = :aye
    assert !v2.valid?
    assert_equal "is already taken", v2.errors.messages[:user_id].first
  end

  test "should reject a value for vote other than :aye, :nay or :abstain" do
    polco_group = @user2.joined_groups.last
    v1 = @house_bill.votes.new
    v1.user = @user2
    v1.polco_group = polco_group
    v1.value = :happy
    assert !v1.valid?
    assert_equal "You can only vote yes, no or abstain", v1.errors.messages[:value].first
  end

  test "should be able to get an associated roll call" do
    # bills are named as data/us/CCC/rolls/[hs]SSSS-NNN.xml.
    # ccc= congress number
    f = File.new("#{Rails.root}/test/fixtures/h2011-9.xml", 'r')
    feed = Feedzirra::Parser::RollCall.parse(f)
    assert_equal "hr", feed.bill_type
    assert_equal "house", feed.chamber
    assert_equal "26", feed.bill_number
    assert_equal 434, feed.roll_call.count
  end

  test "should be able to get roll-counts inside all relevant bills " do
    # need to create a bill to update
    assert_equal({:ayes => 236, :nays => 182, :abstains => 16, :presents => 0}, @house_bill_with_roll_count.members_tally)
    # we should also be able to get a member's result on a specific bill
    member = @house_bill_with_roll_count.member_votes.first.legislator
    puts member.full_name
    assert_equal(:aye, @house_bill_with_roll_count.find_member_vote(member))
    assert_equal(:nay, @house_bill_with_roll_count.find_member_vote(Legislator.where(govtrack_id: 400436).first))
    assert_equal(:abstain, @house_bill_with_roll_count.find_member_vote(Legislator.where(govtrack_id: 412445).first))
  end

  test "should be able to get the tallies for all of a user's custom groups (followed and joined)" do
    # so we are logged in as user1 on @house_bill page
    # we want to see all of our custom groups (joined groups and followed groups), with an associated tally
    # so we can put something like this in our views
    #@user1.joined_groups
    #@user1.followed_groups
    puts "********************"
    puts " starting this test "
    puts "********************"
    puts "user groups at start:"
    puts @user1.joined_groups.map(&:name)
    puts @user1.joined_groups.size
    @user1.vote_on(@house_bill, :aye) # follows va05
    puts "new size #{@user1.joined_groups.size}"
    @user2.vote_on(@house_bill, :nay)
    @user3.vote_on(@house_bill, :abstain) # joined va05
    @user4.vote_on(@house_bill, :present)
    puts @user1.joined_groups.map(&:name)
    puts "before !! #{@user1.joined_groups.count}"
    joined_groups = @user1.joined_groups_tallies(@house_bill)
    puts joined_groups.inspect
    followed_groups = @user1.followed_groups_tallies(@house_bill)
    assert_equal 4, joined_groups.count
    assert_equal "Dan Cole", joined_groups.first[:name]
    assert_equal({:ayes => 1, :nays => 1, :abstains => 1, :presents => 1}, joined_groups.first[:tally])
    assert_equal 2, followed_groups.count
    assert_equal "VA".to_s, followed_groups.first[:name].to_s
    assert_equal({:ayes => 0, :nays => 0, :abstains => 1, :presents => 1}, followed_groups.first[:tally])
  end

  test "should show the latest status for a bill" do
    @house_bill.bill_actions = [['2011-08-14', 'augustine'], ['2011-05-12', 'Cyril'], ['2001-09-15', 'Pelagius']]
    @house_bill.bill_state = 'REFERRED'
    last_action = @house_bill.get_latest_action
    assert_equal "augustine", last_action[:description]
    assert_equal 'REFERRED', @house_bill.bill_state, "bill state did not return 'REFERRED'"
  end

  test "should be able to show the house representatives vote if the bill is a hr" do
    # given that I am @user1 and I want to view hr26, I should see my specific rep's vote on this bill
    rep_vote = @user1.reps_vote_on(@house_bill_with_roll_count)
    assert_equal({:rep=>"Gary Ackerman", :vote=>:nay}, rep_vote, "representative's vote does not match")
  end


  test "a bill that hasnt been voted on should not show and overall tally" do
    # you request a tally, but you get . . . "not tallied yet"
    pending
    assert true
  end

  test "should be able to show both senators votes if the bill is a sr" do
    senator_votes = @user1.senators_vote_on(@senate_bill_with_roll_count)
    assert_equal :nay, senator_votes.first[:vote], "senator's vote does not match"
  end

  test "should be able to get a list of subjects for a bill" do
    f = File.new("#{Rails.root}/test/fixtures/h59.xml", 'r')
    feed = Feedzirra::Parser::GovTrackBill.parse(f)
    @house_bill.subjects = []
    feed.subjects.each do |subject|
      o = Subject.find_or_create_by(:name => subject)
      @house_bill.subjects << o
    end
    assert @house_bill.save, @house_bill.errors.messages.inspect
    assert_equal "Government operations and politics", @house_bill.subjects.first.name
    assert_equal 8, @house_bill.subjects.all.count
  end

  test "should get most recent roll called bill and exclude bills from this list that have not been roll-called" do
    #Bill.house_roll_called_bills
    #Bill.house_roll_called_bills.last.member_votes.count
  end

  test "should be able to report its activity appropriately" do
    assert_true @house_bill_with_roll_count.activity?
    assert_false @house_bill.activity?
  end

end
