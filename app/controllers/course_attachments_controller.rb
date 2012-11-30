# TODO Implement this controller
class CourseAttachmentsController < ApplicationController
  model_object CourseAttachment
  default_search_scope :documents
  before_filter :find_project, :only => [:index, :new]
  before_filter :find_model_object, :except => [:index, :new]
  before_filter :find_project_from_association, :except => [:index, :new]

  helper :attachments
  include AttachmentsHelper

  def index
    
  end

  def show
  end

  def new
    @course_attachment = Course.find(params[:id]).course_attachments.build(params[:course_attachment])
    if request.post? and @course_attachment.save 
      attachments = Attachment.attach_files(@course_attachment, params[:attachments])
      render_attachment_warning_if_needed(@course_attachment)
      flash[:notice] = l(:notice_successful_create)
      redirect_to :action => 'index', :project_id => @course_attachment
    end
end

def add_attachment
    attachments = Attachment.attach_files(@course_attachment, params[:attachments])
    render_attachment_warning_if_needed(@course_attachment)

    Mailer.deliver_attachments_added(attachments[:files]) if attachments.present? && attachments[:files].present? && Setting.notified_events.include?('document_added')
    redirect_to :action => 'show', :id => @course_attachment
  end

  def create
    # create an attachment in its parent course
    @course = Course.find(params[:course_id])
    if(params[:form][:form_id].to_i == 2)
      @course_attachment = @course.course_attachment.new(params[:course_attachment])
    else
      @course_attachment = @course.course_attachment.find(params[:course_attachment_id])
    end
  end

  def edit
  end

  def update
  end

  def destroy
  end
end
