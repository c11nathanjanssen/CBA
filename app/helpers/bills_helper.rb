module BillsHelper

  def determine_vote(user)
    if user.nil? || !user_signed_in?
      out = "If you #{ link_to "log in", user_session_path }, you gain the right to vote"
    elsif vote = @bill.voted_on?(user) # they can't vote again
      case vote
        when :aye
          out = "You voted for this bill."
        when :nay
          out = "You voted against this bill."
        when :abstain
          out = "You abstained from voting on this bill."
        when :present
          out = "You voted Present on this bill"
        else
          raise "unknown value for vote"
      end
    elsif !user.registered?
      out = "You are logged in, but you haven't registered your district. #{ link_to "Change that", users_geocode_path}."
    else # they are registered, logged in, and haven't voted yet
      out = display_vote_options
    end
    out.html_safe
  end

  def determine_rep_vote(rep_vote, district)
    #<%= rep_vote[:rep] + "," + .to_s %>
    unless rep_vote == "no vote available"
      case rep_vote[:vote]
        when :aye
          action = "voted for this bill"
        when :nay
          action = "voted against this bill"
        when :present
          action = "voted present"
        else
          action = "abstained from voting on this bill"
      end
      out = "Your representative for #{district}, #{rep_vote[:rep]}, #{action}.".html_safe
    else
      out = "This bill has not yet been voted on."
    end
    return out
  end

  def determine_senators_votes(votes)
    if votes =~ /^Your senators have not/
      votes
    else
      "#{votes.first[:senator]} voted #{votes.first[:vote].to_s} and #{votes.last[:senator]} voted #{votes.last[:vote].to_s}."
    end
  end

  def rep_title rep
    rep.nil? ? "No rep" : rep.full_title
  end

  def display_vote_options
    content_tag :div, {:class => 'vote_container'} do
      content_tag :ul, {:id => 'vote_list'} do
        content_tag(:li, link_to("Yes", vote_on_bill_path(@bill, "aye"))) +
            content_tag(:li, link_to("No", vote_on_bill_path(@bill, "nay"))) +
            content_tag(:li, link_to("Abstain", vote_on_bill_path(@bill, "abstain"))) +
            content_tag(:li, link_to("Present", vote_on_bill_path(@bill, "present")))
      end
    end
  end

  def last_action(bill)
    action = bill.get_latest_action
    "on #{action[:date]}, #{action[:description]}"
  end

  def format_votes_inline(vote_hash)
    "#{vote_hash[:ayes]} were for, #{vote_hash[:nays]} were against, #{vote_hash[:presents]} voted present and #{vote_hash[:abstains]} abstained."
  end

  def pie_chart(tally)
    # also like Sand and Shade: 8E9E63|E6DBB0|F5EED7|C4BCA0|176573 #
    # used satisfying results by ben.eelen
    # we can also use: DB9E36
    unless tally.values.all? { |t| t==0 }
      chart_root = "http://chart.apis.google.com/chart"
      vals = {
          # what is the size of the chart?
          chs: '70x63',
          # what chart type?
          cht: 'p',
          # what are the chart colors (in the same order as the data)
          # chco=<slice_1>|<slice_2>|<slice_n>,<series_color_1>,...,<series_color_n>
          chco: '1B8598|EE6514|DEE8E8|A5B0B0',
          # Text Format with Custom Scaling
          chds: 'a',
          # the actual data
          chd: "t:#{tally[:ayes]},#{tally[:nays]},#{tally[:abstains]},#{tally[:presents]}",
          # Pie Chart Rotation | chp=<radians>
          chp: '0.0',
          #chma=<left_margin>,<right_margin>,<top_margin>,<bottom_margin>|<opt_legend_width>,<opt_legend_height>
          chma: '|2'
      }
      query = vals.map { |k, v| "#{k}=#{v}" }.join("&")
      alt_tag = tally.map { |k, v| "#{k}: #{v}" }.join(",")
      image_tag("#{chart_root}?#{query}", size: "70x63", alt: alt_tag, style: "box-shadow:none;").html_safe
      #%q{<img src="http://chart.apis.google.com/chart?chs=70x63&cht=p&chco=009900|E20000|76A4FB|990066&chds=-3.333,100&chd=t:32.787,50.82,100,42.623&chp=0.067&chma=|2" width="70" height="63" alt="" />}.html_safe
    else
      "no votes"
    end
  end
end
