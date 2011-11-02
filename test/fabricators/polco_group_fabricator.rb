Fabricator(:polco_group) do
  name Faker::Company.bs
  title Faker::Company.name
  type :custom
  member_ids []
  follower_ids []
  comments []
end

Fabricator(:oh, :class_name => :polco_group) do
  name 'OH'
  title 'OH_state'
  type :state
  member_ids []
  follower_ids []
  comments []
end