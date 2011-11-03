class BillsController < ApplicationController
  load_and_authorize_resource :except => [:results, :e_ballot, :show_bill_text, :vote_on_bill, :senate_bills, :process_page, :district_results]
  # public can access?

  # GET /bills
  # GET /bills.xml
  def index
    @bills = Bill.all.paginate(:page => params[:page], :per_page => 20)
    #@bills = Bill.all.select{|b| b.activity?}.paginate(:page => params[:page], :per_page => 20)

    respond_to do |format|
      format.html # index.haml
      format.xml { render :xml => @bills }
    end
  end

  def show_bill_text
    # assuming load_and_authorize_resource doesn't populate this
    @bill = Bill.find(params[:id])
  end

  def vote_on_bill
    @bill = Bill.find(params[:id])
    current_user.vote_on(@bill, params[:value].to_sym)
    # need redirect
    redirect_to(@bill)
  end

  # GET /bills/1
  # GET /bills/1.xml
  def show
    #modified by nate
    @districts = PolcoGroup.districts.where(:vote_count.gt => 0).desc(:member_count).paginate(:page => params[:page], :per_page => 10)
    @user = current_user
    # need to remove extra data
    @PolcoGroups=@user.non_district_groups_for_bill(@bill).paginate(:page => params[:page], :per_page => 10)
    #@PolcoGroups=@user.all_groups_for_bill(@bill).paginate(:page => params[:page], :per_page => 10)
    @rolled = (@bill.member_votes.size > 0)

    respond_to do |format|
      format.html # show.haml
      format.xml { render :xml => @bill }
    end
  end

  # GET /bills/new
  # GET /bills/new.xml
  def new
    #@bill = Bill.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml { render :xml => @bill }
    end
  end

  # GET /bills/1/edit
  def edit
    #@bill = Bill.find(params[:id])
  end

  # POST /bills
  # POST /bills.xml
  def create
    #@bill = Bill.new(params[:bill])
    # BILL is a content item, so we need to take
    # care of the title property which must be unique

    respond_to do |format|
      if @bill.save
        format.html { redirect_to(@bill, :notice => 'Bill was successfully created.') }
        format.xml { render :xml => @bill, :status => :created, :location => @bill }
      else
        format.html { render :action => "new" }
        format.xml { render :xml => @bill.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /bills/1
  # PUT /bills/1.xml
  def update
    #@bill = Bill.find(params[:id])

    respond_to do |format|
      if @bill.update_attributes(params[:bill])
        format.html { redirect_to(@bill, :notice => 'Bill was successfully updated.') }
        format.xml { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml { render :xml => @bill.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /bills/1
  # DELETE /bills/1.xml
  def destroy
    #@bill = Bill.find(params[:id])
    @bill.destroy

    respond_to do |format|
      format.html { redirect_to(bills_url) }
      format.xml { head :ok }
    end
  end

  def e_ballot
    # need to update for non-logged in users
    @chamber = params[:chamber] || "house"
    # want to filter down ["h", "s", "sr", "hc", "hj", "hr", "sc", "sj"]
    if params[:bill_type] # we want to filter down bills by type
      @bill_type = params[:bill_type]
    else
      # let's set a default if none is specified
      @chamber == "house" ? @bill_type = "h" : @bill_type = "s"
    end
    if @user = current_user
      user_voted_bills = Vote.where(user_id: current_user.id).desc(:created_at).map { |v| v.bill }.uniq
      if @chamber == "house"
        #@filter_options = ["h", "hc", "hj", "hr"]
        # TODO -- sorted by the number of votes provided to that bill -- lower priority
        @voted_bills = user_voted_bills.select { |b| b.bill_type != "hr" && b.chamber = :house } # also shown which result you like there
        @unvoted_bills = Bill.house_bills.desc(:created_at).all.to_a - @voted_bills
      else # it is a senate bill ballot
        #@filter_options = ["s", "sr", "sc", "sj"]
        @voted_bills = user_voted_bills.select { |b| b.bill_type != "sr" && b.chamber = :senate }
        @unvoted_bills = Bill.senate_bills.desc(:created_at).all.to_a - @voted_bills
      end
    else
      if @chamber == "house"
        @filter_options = ["h", "hc", "hj", "hr"]
        @voted_bills = nil
        @unvoted_bills = nil
      else # it is a senate bill ballot
        @filter_options = ["s", "sr", "sc", "sj"]
        # sorted by the number of votes provided to that bill -- lower priority
        # Bill.senate_bills.where(bill_type: @bill_type).paginate(:page => params[:page], :per_page => 10)
        # ^^ can expand to eballot
        @voted_bills = nil
        @unvoted_bills = nil
      end
    end

    # need to consider chamber!!
    if params[:id]
      @bill = Bill.find(params[:id])
    else # we have to take the first bill on the page since the user didn't specify the page
      @bill = (@chamber == "house" ? Bill.house_bills.where(bill_type: @bill_type).first : Bill.senate_bills.where(bill_type: @bill_type).first)
    end
    @legislator = @bill.sponsor unless @bill.nil?
  end

  def senate_bills
    @bills = Bill.senate_bills
  end

  def process_page
    user = current_user
    bill = Bill.find(params[:bill_id])
    # error checking here
    if params[:vote]
      case params[:vote]
        when "For"
          vote = :aye
        when "Against"
          vote = :nay
        when "Abstain"
          vote = :abstain
        when "Present"
          vote = :present
      end
      comment = Comment.new
      comment.comment = params[:comment].empty? ? "no comment" : params[:comment]
      comment.name = user.name
      comment.email = user.email
      bill.comments << comment # TODO need markup stuff . . .
      user.vote_on(bill, vote)
      bill.save! # <-- the key line
      redirect_to e_ballot_path(params[:chamber], params[:bill_type], bill.id)
    else
      flash[:notice] = "Oops, you forgot to vote"
      redirect_to :back
    end
  end

  def district_results
    @districts = PolcoGroup.districts.desc(:member_count).paginate(:page => params[:page], :per_page => 10)
    @bills = Bill.house_roll_called_bills.all.paginate(:page => params[:page], :per_page => 10)
    #@comments = Bill.comments.sort_by{|c| c.}

    respond_to do |format|
      format.html # district_results.haml
      format.xml { render :xml => @bills }
    end
  end

  def results
    # this is where the code gets prepared for the chamber results view
    #this page presents one table outlining the bills the user has cast an eballot on.

    # the bills in the table are ordered by most recent at the top
    #for each bill, the table shows the bill's official title, 
    # the user's vote, the user's district's tally on that bill,
    # the rep's vote on that bill and the overall bill result.
    #in addition there's a column for the user's comment on that bill.
    # if the user posted a comment on that bill, an expandable arrow appears
    # in that column. when the arrow in that column is selected it opens the user's post's
    # page in new tab (or window) in the browser.
    # future case
    # but can also be ordered by popularity, number of votes, number of comments, number of votes by district members,
    # or searchable.
    @user = current_user

    if params[:chamber] == "house"
      @chamber = "house"
      @bills = @user.bills_voted_on(:house).paginate(:page => params[:page], :per_page => 10)
    else
      @chamber = "senate"
      @pg_state = PolcoGroup.where(name: @user.us_state, type: :state).first
      @bills = @user.bills_voted_on(:senate).paginate(:page => params[:page], :per_page => 10)
    end
    #@bills = Bill.house_bills.paginate(:page => params[:page], :per_page => 10)
  end

end
