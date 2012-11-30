# Redmine's current syntax for linking to RESTful resources
ActionController::Routing::Routes.draw do |map|
  map.resources :course_trackers
  map.resources :registrants
  map.resources :courses, :collection => {:zip_some => [:get,:post], :zip_all => [:get,:post], :filter => [:get,:post], :filter_by_status => [:get,:post], :zip_filtered => [:get,:post], :zip_filtered_single => [:get,:post], :export_filtered_to_csv => [:get,:post]}
  map.resources :course_applications, :collection => {:view_table => [:get,:post], :new_referral => [:get,:post]}
  map.resources :course_attachments
  map.resources :course_custom_fields
  map.resources :course_application_referrals, :collection => {:request_referral => [:get,:post], :resend_referral => [:get,:post]}
  map.resources :course_application_materials, :collection => {:zip_files => [:get,:post]}

  # default routes
  #map.connect ':controller/:action/:id'
  #map.connect ':controller/:action/:id.:format'
end

