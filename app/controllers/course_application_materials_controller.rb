require 'rubygems'
require 'zip/zipfilesystem'

class CourseApplicationMaterialsController < ApplicationController
  unloadable
  
  helper :attachments
  include AttachmentsHelper

  def index
    
    @course_tracker = CourseTracker.find(params[:course_tracker_id])
    if(User.current.admin?)
      if(params[:view_scope] == 'course' || (params[:registrant_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course applications for a particular course
        @course_application_materials = Course.find(params[:course_id]).course_application.course_application_materials
      elsif(params[:view_scope] == 'registrant' || (params[:course_id].nil? && params[:course_tracker_id].nil?))
        # if viewing all course applications for a particular user/registrant
        @course_application_materials = Registrant.find(params[:registrant_id]).course_application.course_application_materials
      else
        # if viewing all course applications for an course_tracker
        unless params[:zipped_file].nil?
          @zipped_file = params[:zipped_file]
        end
        @courses = CourseTracker.find(params[:course_tracker_id]).courses
        @course_application_material = Array.new
        @courses.each do |course|
          course.course_applications.each do |ja|
            @course_application_material << ja.course_application_materials
          end
        end
      end
      @course_application_material.flatten!

    elsif(User.current.logged?)
      @registrant = Registrant.find_by_email(User.current.mail)
      @course_applications = @registrant.course_applications
      @course_application_material = Array.new
      
      @course_applications.each do |ja|
        @course_application_material << ja.course_application_materials.find(:first, :include => [:attachments])
      end

      
    end
  end

  def show
  end

  def new
    @course_application_material = CourseApplication.find(params[:id]).course_application_materials.build(params[:course_application_material])
    if request.post? and @course_application_material.save 
      attachments = Attachment.attach_files(@course_application_material, params[:attachments])
      render_attachment_warning_if_needed(@course_application_material)
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :project_id => @course_application_material
    end
  end
  
  def add_attachment
    attachments = Attachment.attach_files(@course_application_material, params[:attachments])
    render_attachment_warning_if_needed(@course_application_material)

    Mailer.deliver_attachments_added(attachments[:files]) if attachments.present? && attachments[:files].present? && Setting.notified_events.include?('document_added')
    redirect_to :action => 'show', :id => @course_application_material
  end  

  def create
    # create an attachment in its parent course
    @course_application = CourseApplication.find(params[:course_application_id])
    @course_application_material = @course_application.course_application_material.find(params[:course_application_material_id])    
  end

  def edit
  end

  def update
  end

  def destroy
  end

  def zip_files
    @files = params[:files]
    @ja_materials = []
    @files.each do |f|
      @ja_materials << CourseApplicationMaterial.find(f)
    end
    filepaths = []
    @ja_materials.each do |jam|
      jam.attachments.each do |jama|
        filepaths << "#{RAILS_ROOT}/files/" + jama.disk_filename
      end  
    end  
    zip("#{RAILS_ROOT}/files/jam.zip", filepaths)
    @zipped_file = "#{RAILS_ROOT}/files/jam.zip"
    p "zipped"
    p @zipped_file
    redirect_to :action => 'index', :course_tracker_id => params[:course_tracker_id], :zipped_file => @zipped_file
  end
  
  def zip(zip_file_path, list_of_file_paths)

    @zip_file_path = zip_file_path
    list_of_file_paths = [list_of_file_paths] if list_of_file_paths.class == String
    @list_of_file_paths = list_of_file_paths

    Zip::ZipFile.open(@zip_file_path, Zip::ZipFile::CREATE) do |zipfile|
      @list_of_file_paths.each do | file_path |
        if File.exists?file_path
          file_name = File.basename( file_path )
          if zipfile.find_entry( file_name )
            zipfile.replace( file_name, file_path )
          else
            zipfile.add( file_name, file_path)
          end
        else
          puts "Warning: file #{file_path} does not exist"
        end
      end
    end
  end
end
