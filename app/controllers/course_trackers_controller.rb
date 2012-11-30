class CourseTrackersController < ApplicationController
  #unloadable # don't keep reloading this
  before_filter :require_admin, :except => [:index, :show] 
  
  default_search_scope :course_trackers

  def index
    # The :project_identifier parameter must exist, otherwise redirect back to projects
    if(!params[:project_identifier].nil?)
      @project = Project.find_by_identifier(params[:project_identifier])
    else
      redirect_to('/projects')
    end

    # display a project's course_trackers
    @course_trackers = CourseTracker.find(:all, :conditions => ["project_id = ?", @project.id])
  end
  
  # GET /course_trackers/1
  # GET course_tracker_url(:id => 1)
  def show
    @course_tracker = CourseTracker.find(params[:id])

    respond_to do |format|
      format.html { redirect_to(courses_url(:course_tracker_id => @course_tracker.id)) }#show.html.erb
    end
  end

  # GET /course_trackers/new
  # Get new_course_tracker_url
  def new
    @project = Project.find_by_identifier(params[:project_identifier])
    @course_tracker = CourseTracker.new
    @course_tracker.project_id = @project.id
    respond_to do |format|
        format.html #new.html.erb
    end
  end
  
  # POST /course_trackers
  # POST course_trackers_url
  def create
    @course_tracker = CourseTracker.new(params[:course_tracker])
    @project = @course_tracker.project = Project.find(params[:course_tracker][:project_id])
    

    # attempt to save the course_tracker; flash results to the user
    respond_to do |format|
      if(@course_tracker.save)
        # no errors, redirect with success message
        format.html { redirect_to(@course_tracker, :notice => "#{@course_tracker.title} has been created.") }
      else
        # validation prevented save
        format.html { render :action => "new" }
      end
    end
  end

  # GET /course_trackers/1/edit
  # GET edit_course_tracker_url(:id => 1)
  def edit
    @course_tracker = CourseTracker.find(params[:id])
    @project = @course_tracker.project
    
    respond_to do |format|
      format.html
    end
  end

  # PUT /course_trackers/1
  # PUT course_tracker_url(:id => 1)
  def update
    @course_tracker = CourseTracker.find(params[:id])
    @project = @course_tracker.project

    # attempt to update course_tracker attributes; flash results to the user
    respond_to do |format|
      if @course_tracker.update_attributes(params[:course_tracker])
        # no errors, redirect with success message
        format.html { redirect_to(course_trackers_url(:project_identifier => @project.identifier), :notice => "#{@course_tracker.title} has been updated.") }
     else
        # validation prevented update; redirect to edit form with error messages
        format.html { render :action => "edit" }
      end
    end
  end

  # DELETE /course_trackers/1
  # DELETE course_tracker_url(:id => 1)
  def destroy
    @course_tracker = CourseTracker.find(params[:id])
    @project = @course_tracker.project

    # attempt to destroy the course_tracker; flash results to the user
    @course_tracker.destroy ? flash[:notice] = "#{@course_tracker.title} has been deleted." : flash[:error] = "Error: #{@course_tracker.title} could not be deleted."
    respond_to do |format|
      format.html { redirect_to course_trackers_url(:project_identifier => @project.identifier) }
    end
  end
end
