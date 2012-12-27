TechJobs::Application.routes.draw do

  devise_for :students, :controllers => { :sessions => "students/sessions" }

  devise_for :employers, :controllers => { :registrations => "employers/registrations",
                                           :sessions => "employers/sessions",
                                           :passwords => "employers/passwords" }

  resources :postings
  resources :students
  resources :employers

  root :to => "postings#index"

end
