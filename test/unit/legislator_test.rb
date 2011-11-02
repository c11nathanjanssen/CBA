require 'test_helper'

class LegislatorTest < ActiveSupport::TestCase

  def setup
    @user = Fabricate(:user)
    @legislator = Fabricate(:rep)
  end

  test "The chamber should update correctly" do
    assert_not_nil @legislator
    #assert true
  end

  test "We should get their party name" do
    assert_equal("Republican", @legislator.party)
  end

  test "We should be able to read their full state name" do
    assert_equal("OH", @legislator.state)
  end

  test "We should be able to get their chamber" do
    assert_equal("U.S. House of Representatives", @legislator.chamber)
  end

  test "We should be able to update all legislators" do
    Legislator.destroy_all
    Legislator.update_legislators
    # should be at least the number of reps (435) + the number of senators
    assert_operator Legislator.all.count, :>=, 535
  end

  test "We should be able to get the most recent actions from a legislator" do
    legislator_result = YAML::load(File.open("#{Rails.root}/test/fixtures/govtrack_person.yml"))
    role = Legislator.find_most_recent_role(legislator_result)
    assert_equal Date.parse("2009-01-06"), role[:startdate]
  end

  test "we should be able to add constituents for state and district" do
    @legislator.state_constituents << @user
    @legislator.district_constituents << @user
    assert_equal 1, @legislator.state_constituents.count
    assert_equal 1, @legislator.district_constituents.count
    assert @legislator.valid?
  end

  #test "should be able to get the reps for all legislators" do
  #  Legislator.all.each do |l|
  #    puts l.the_rep
  #  end
  #end

end
