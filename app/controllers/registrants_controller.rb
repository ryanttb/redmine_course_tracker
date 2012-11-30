class RegistrantsController < ApplicationController
  unloadable # don't keep reloading this

  default_search_scope :registrants
  
  helper :sort
  include SortHelper

  def index
    sort_init 'last_name', 'asc'
    sort_update %w(first_name last_name)
    
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @registrants = Registrant.find(:all, :order => sort_clause)
  end
  
  def show 
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @registrant = Registrant.find(params[:id])
    @course_applications = @registrant.course_applications
    
    sort_init 'created_at', 'desc'
    sort_update 'last_name' => "#{Registrant.table_name}.last_name",
                'id' => "#{CourseApplication.table_name}.id",
                'submission_status' => "#{CourseApplication.table_name}.submission_status",
                'acceptance_status' => "#{CourseApplication.table_name}.acceptance_status",
                'created_at' => "#{CourseApplication.table_name}.created_at"
                
	  unless User.current.admin? || @registrant.email == User.current.mail
		  redirect_to('/') and return
	  end

    respond_to do |format|
      format.html #show.html.erb
    end
  end

  def new
    # make a new registrant
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    unless params[:course_id].nil?
      @course = Course.find(params[:course_id])
    end  
    @registrant = @course_tracker.registrants.new

    respond_to do |format|
      format.html #new.html.erb
    end
  end

  def edit
    # find the registrant for editing
    @course_tracker = CourseTracker.find(params[:course_tracker_id]) 
    @registrant = Registrant.find(params[:id])
    unless User.current.admin?
      @user = User.current
    else
      @user = User.find(:first, :conditions => {:mail => @registrant.email})
    end  
	unless User.current.admin? || @registrant.email == User.current.mail
		redirect_to('/') and return
	end
  end
  
  def create
    # create an registrant and attach it to its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @registrant = @course_tracker.registrants.new(params[:registrant])
    unless params[:course_id].nil?
      @course = Course.find(params[:course_id])
    end
    @user = User.current 
    
    # attempt to save, and flash the result to the user
    respond_to do |format|
      if(@registrant.save)
        debugger
        # no errors, redirect with success message
        unless @course.nil?
          format.html { redirect_to(new_course_application_url(:course_tracker_id => @course_tracker.id, :course_id => @course.id, :user_id => @registrant.id)) }
        else
          format.html { redirect_to(registrant_url(@registrant, :course_tracker_id => @course_tracker.id)) }
        end    
      else
        # validation prevented save
        format.html { render :action => "new" }
      end
    end
  end

  def update
    # find the registrant via its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    params[:registrant].delete(:course_tracker_id)
    @registrant = Registrant.find(params[:id])
    @user = User.current

	unless User.current.admin? || @registrant.email == User.current.mail
		redirect_to('/') and return
	end
    
    # attempt to update attributes, and flash the result to the user
    respond_to do |format|
      if(@registrant.update_attributes(params[:registrant]))
        # successfully updated; redirect and indicate success to user
        format.html{ redirect_to(registrant_url(@registrant,:course_tracker_id => @course_tracker.id, :notice => "#{@registrant.first_name} #{@registrant.last_name}\'s record has been updated."))}
      else
        # update failed; go back to edit form
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    # find the registrant via its parent course_tracker
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    @registrant = Registrant.find(params[:id])

	unless User.current.admin? || @registrant.email == User.current.mail
		redirect_to('/') and return
	end

    # attempt to destroy the registrant (ouch), and flash the result to the user
    @registrant.destroy ? flash[:notice] = "#{@registrant.first_name} #{@registrant.last_name}\'s record has been deleted." : flash[:error] = "Error: #{@registrant.first_name} #{@registrant.last_name}\'s record could not be deleted."
    
    respond_to do |format|
      format.html { redirect_to(registrants_url(:course_tracker_id => @course_tracker.id)) }
    end
  end
end
