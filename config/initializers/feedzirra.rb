require 'sax-machine'

module Feedzirra
  module Parser

    class MemberVote
      include SAXMachine
      include FeedEntryUtilities

      element :voter, :value => :id, :as => :member_id
      element :voter, :value => :vote, :as => :member_vote

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class RollCall
      include SAXMachine
      include FeedEntryUtilities

      # top part
      element :roll, :value => :where, :as => :chamber
      element :roll, :value => :session, :as => :session
      element :category, :as => :bill_category
      element :roll, :value => :datetime, :as => :original_time
      element :roll, :value => :updated, :as => :updated_time
      element :question, :as => :the_question
      element :required, :as => :required
      # <bill session="112" type="hr" number="26"/>
      element :bill, :value => :session, :as => :congress
      element :bill, :value => :type, :as => :bill_type
      element :bill, :value => :number, :as => :bill_number
      #<option key="+">Yea</option>
      #<option key="-">Nay</option>
      #<option key="P">Present</option>
      #<option key="0">Not Voting</option>
      element :option, :as => :yea_vote, :with => {:key => "+"}
      element :option, :as => :nay_vote, :with => {:key => "-"}
      element :option, :as => :present_vote, :with => {:key => "P"}
      element :option, :as => :abstain_vote, :with => {:key => "0"}

      elements :voter, :as => :roll_call, :class => MemberVote

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class GovTrackBill
      include SAXMachine
      include FeedEntryUtilities

      element :bill, :value => :session, :as => :congress
      element :bill, :value => :type, :as => :bill_type
      element :bill, :value => :number, :as => :bill_number
      element :bill, :value => :updated, :as => :last_updated
      #element :status, :as => :bill_status

      element :state, :as => :bill_state
      element :introduced, :value => :datetime, :as => :introduced_date
      elements :title, :value => :type, :as => :titles
      element :sponsor, :value => :id, :as => :sponsor_id
      elements :cosponsor, :value => :id, :as => :cosponsor_ids
      elements :action, :value=> :datetime, :as => :bill_actions
      elements :term, :value => :name, :as => :subjects
      #elements :subjects, :value => :name, :as => :bill_subjects
      element :summary
    end

    class GovtrackResult
      include SAXMachine
      include FeedEntryUtilities

      element :congress
      element :"bill-type", :as => :bill_type
      element :"bill-number", :as => :bill_number
      element :title
      element :link
      element :"bill-status", :as => :status
    end

    class GovTrackPerson
      include SAXMachine
      include FeedEntryUtilities

      #element :person
      element :person, :value => :id, :as => :govtrack_id
      element :person, :value => :lastname, :as => :last_name
      element :person, :value => :firstname, :as => :first_name
      element :person, :value => :middlename, :as => :middle_name
      element :person, :value => :birthday, :as => :birthday
      element :person, :value => :gender, :as => :gender
      element :person, :value => :religion, :as => :religion
      element :person, :value => :pvsid, :as => :pvs_id
      element :person, :value => :osid, :as => :os_id
      element :person, :value => :bioguideid, :as => :bioguide_id
      element :person, :value => :metavidid, :as => :metavid_id
      element :person, :value => :youtubeid, :as => :youtube_id
      element :person, :value => :icpsrid, :as => :icpsrid
      element :person, :value => :name, :as => :full_name
      element :person, :value => :title, :as => :title
      element :person, :value => :state, :as => :state
      element :person, :value => :district, :as => :district
      elements :role, :value => :type, :as => :role_type
      elements :role, :value => :party, :as => :role_party
      elements :role, :value => :startdate, :as => :role_startdate

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end

    end

    class GovTrackPeople
      include SAXMachine
      include FeedEntryUtilities

      elements :person, :as => :people, :class => GovTrackPerson

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class GovTrackMember
      include SAXMachine
      include FeedEntryUtilities
      element :member, :value => :type, :as => :member_type
      element :member, :value => :id, :as => :govtrack_id

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class DistrictResult
      include SAXMachine
      include FeedEntryUtilities

      element :session, :as => :congressional_session
      element :latitude, :as => :lat
      element :longitude, :as => :lon
      element :state, :as => :us_state
      element :district, :as => :district
      elements :member, :as => :members, :class => GovTrackMember

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class GovTrackDistrict
      include SAXMachine
      include FeedUtilities

      elements :"congressional-district", :as => :districts, :class => DistrictResult

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end

    class Govtrack
      include SAXMachine
      include FeedUtilities
      elements :result, :as => :search_results, :class => GovtrackResult

      def self.able_to_parse?(xml) #:nodoc:
        1
        # xml =~ /<search-results/
      end
    end
  end
end


