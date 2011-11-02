

users_to_add = 10
groups_to_add = 10

# we are duplicating numbers, we should use
# garner.hixson@pentagon.af.mi
#(0..50).to_a.sort{ rand() - 0.5 }[0..x]
# (0..50).to_a can be replaced with any array. 0 is "minvalue", 50 is "max value" x is "how many values i want out"

namespace :data do
  desc "Get us lots of users and votes"
  task :load_users => :environment do
    require 'faker'
    # load members
    puts "let us make lots of groups"
    new_ids = []
    groups_to_add.times do |i|
      p = PolcoGroup.new
      p.name = Faker::Company.name
      p.type = :custom
      p.save
      new_ids.push(p.id)
    end
    puts "let us make lots of users"
    users = []
    users_to_add.times do |i|
      u = User.new
      u.name = Faker::Name.name
      u.email = Faker::Internet.email
      u.password = "eieio_1282"
      u.password_confirmation = "eieio_1282"
      u.confirmed_at = Time.now()
      u.role = :confirmed_user
      # TODO -- geocode
      # geocode the user!!!
      # we need three random numbers
      ids = []
      6.times.map {rand(groups_to_add)}.each do |i|
        ids.push(new_ids[i])
      end
      u.followed_group_ids = ids[0..2]
      u.joined_group_ids   = ids[3..5]
      u.save
      users << u
    end
    votes = {1=>:aye, 2=>:nay, 3=>:abstain, 4=>:present}
    Bill.all.each do |b|
      # 20 votes on each bill
      5.times.map {rand(users_to_add)}.each do |u|
        puts "#{users[u].name} is voting on #{b.title}"
        users[u].vote_on(b, votes[rand(3)+1])
      end
    end
  end
end
