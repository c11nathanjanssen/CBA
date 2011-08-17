class PolcoGroupsController < ApplicationController
  # GET /polco_groups
  # GET /polco_groups.xml
  def index
    @polco_groups = PolcoGroup.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @polco_groups }
    end
  end

  # GET /polco_groups/1
  # GET /polco_groups/1.xml
  def show
    @polco_group = PolcoGroup.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @polco_group }
    end
  end

  # GET /polco_groups/new
  # GET /polco_groups/new.xml
  def new
    @polco_group = PolcoGroup.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @polco_group }
    end
  end

  # GET /polco_groups/1/edit
  def edit
    @polco_group = PolcoGroup.find(params[:id])
  end

  # POST /polco_groups
  # POST /polco_groups.xml
  def create
    @polco_group = PolcoGroup.new(params[:polco_group])

    respond_to do |format|
      if @polco_group.save
        format.html { redirect_to(@polco_group, :notice => 'PolcoGroup was successfully created.') }
        format.xml  { render :xml => @polco_group, :status => :created, :location => @polco_group }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @polco_group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /polco_groups/1
  # PUT /polco_groups/1.xml
  def update
    @polco_group = PolcoGroup.find(params[:id])

    respond_to do |format|
      if @polco_group.update_attributes(params[:group])
        format.html { redirect_to(@polco_group, :notice => 'PolcoGroup was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @polco_group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /polco_groups/1
  # DELETE /polco_groups/1.xml
  def destroy
    @polco_group = PolcoGroup.find(params[:id])
    @polco_group.destroy

    respond_to do |format|
      format.html { redirect_to(polco_groups_url) }
      format.xml  { head :ok }
    end
  end
end