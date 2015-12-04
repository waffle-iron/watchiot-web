Rails.application.routes.draw do

  get 'register' => 'users#register', :as => 'register'
  get 'login' => 'users#login', :as => 'login'
  post 'login' => 'users#do_login', :as => 'do_login'
  get 'logout' => 'users#logout', :as => 'logout'
  get 'download' => 'download#index', :as => 'download'
  post 'contact' => 'home#contact', :as => 'home/contact'

  resources :users
  resources :home

  get '/:username', controller: 'dashboard', action:  'show'

  #spaces route
  post '/:username/spaces/create', controller: 'spaces', :action => 'create'
  get '/:username/spaces', controller: 'spaces', :action => 'index'
  get '/:username/:spacename', controller: 'spaces', :action => 'show'
  get '/:username/:spacename/setting', controller: 'spaces', :action => 'setting'
  get '/:username/:spacename/delete', controller: 'spaces', :action => 'delete'

  #projects route
  get '/:username/projects/setting/:projectname', controller: 'projects', :action => 'setting'
  get '/:username/projects/:projectname', controller: 'projects', :action => 'show'
  get '/:username/projects', controller: 'projects', :action => 'index'

  #chart route
  get '/:username/chart', controller: 'chart', :action => 'show'

  #setting route
  get '/:username/setting', controller: 'setting', :action => 'show'

  root 'home#index'

  # at the end of you routes.rb
  get '*a', to:  'errors#routing'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
