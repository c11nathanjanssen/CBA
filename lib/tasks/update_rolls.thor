class UpdateRolls < Thor

  ENV['RAILS_ENV'] ||= 'production'
  require File.expand_path('config/environment.rb')

  desc "delete_all_member_votes", "deletes all member votes from all bills (DANGER!)"
  def delete_all_member_votes
    # use with caution
    Bill.all.to_a.each do |b|
      b.member_votes = []
      b.roll_time = nil
      b.save
    end
  end

  desc "update_rolls", "update the rolls of all bills"
  def update_rolls
    Dir.glob("#{Rails.root}/data/rolls/*.xml").sort_by { |f| f.match(/\/.+\-(\d+)\./)[1].to_i }.each do |bill_path|
      process_roll(bill_path)
    end
  end

  desc "process_roll", "update an individual role give a path to an xml file"
  def process_roll(path)
    f = File.new(path, 'r')
    feed = Feedzirra::Parser::RollCall.parse(f)
    govtrack_id = "#{feed.bill_type}#{feed.congress}-#{feed.bill_number}"
    if the_bill = we_need_to_look_at_it(feed, govtrack_id)
      puts "Processing #{File.basename(f)} for #{govtrack_id}"
      # then go through each roll call and add the member vote
      the_bill.roll_time = Time.now
      the_bill.member_votes = []
      feed.roll_call.each do |v|
        if l = Legislator.where(govtrack_id: v.member_id).first
          #puts "adding vote of #{get_value(v.member_vote)} for #{l.full_name}"
          the_bill.member_votes << MemberVote.new(:value => get_value(v.member_vote), :legislator => l)
        else
          raise "legislator #{v.member_id} not found"
        end # legislator check
        the_bill.save
      end # feed check
    else
      puts "we don't need to look at #{File.basename(f)} with category #{feed.bill_category}"
    end # bill check
  end

  no_tasks do
    def get_value(the_value)
      # we have the potential to customize the values here based on
      # :yea_vote, :nay_vote, etc
      case the_value
        when "+"
          result = :aye
        when "-"
          result = :nay
        when "0"
          result = :abstain
        when "P"
          result = :present
        else
          raise "unknown value #{the_value} (expected +, -, P or 0)"
        # if this is the case, we have to parse from <option key="P">Present</option>
      end
      result
    end

    def we_need_to_look_at_it(feed, govtrack_id)
      #t = Time.parse(feed.updated_time)
      # we need to look at it if the bill is of category 'passage' and we haven't already looked at it
      if feed.bill_category == 'passage'
        puts "hier #{govtrack_id}"
        Bill.where(govtrack_id: govtrack_id).first
      else
        nil
      end
    end
  end

end
