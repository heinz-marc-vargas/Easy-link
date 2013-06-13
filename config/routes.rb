OrderConnect::Application.routes.draw do
  devise_for :users
  devise_scope :user do
     get "/logout"  => "devise/sessions#destroy"
     post "create", :to => "devise/sessions#create"
  end

  resources :docs
 
  resources :oauth, :controller => "oauth" do
    collection do
      get :callback
    end
  end
 
  resources :users, :controller => "users" do
    collection do
      post :user_create
    end
    
    member do
      get :unlock
      get :lock
      post :update
    end
  end

  resources :admins do
    collection do
      get :pendingjobs
      get :help
      get :notes
      get :processings
      get :duplicate_ops
    end

    member do
      get :deletejob
    end
  end

  resources :banktransactions, :controller => "bank_transactions" do
    collection do
      get :export_download
      get :export
      get :import_payment
      post :import_payment
      post :set_sequence
      post :update_sales_channel
      post :set_orderid
    end
  end
  
  resources :forms, :controller => "forms" do
    collection do
      get :sava_comms_form
      post :sava_comms_form
      get :westmead_comms_form
      post :westmead_comms_form
      get :attach_files
      post :attach_files
      get :delete_attachment
      get :delete_email
      get :send_all_unsent_to_sava
      get :send_all_unsent_to_westmead
    end
    
    member do
      
    end
  end

  resources :sites do
    member do
      post :update
    end
  end
  
  resources :products do
    collection do
      get :unassociated
      get :supplier
      get :show_comment_form
      get :show_note_form
      get :stocks
      post :stocks
      get :thresholds
      post :thresholds
      get :newbundle
      get :newcombi
      post :createcombi
      post :createbundle
      get :shop
      get :insert
      post :insert_product
      get :cart_middle_layer
      get :new_cart_product
      post :insert_to_middle_layer
    end
    member do
      post :set_default_supplier
      post :add_comment
      get :add_comment
      post :get_comment
      post :add_note
      post :update
      post :updatebundle
      post :updatecombi
      get :editshop
      put :updateshop
      delete :deleteshop
      get :editcart
      put :updatecart
      delete :deletecart
    end
  end

  resources :suppliers do
    member do
      post :update
    end
  end
  

  resource :audit do
    collection do
    end
    member do
    end
  end
  
  resources :shippings do
    collection do
      get :show_logs
      get :notifications
      post :send_notification
    end

    member do
      get :resend_notification
    end
  end

  resources :porders

  resources :magento_orders do
    collection do
      post :set_status
      post :populate_order_data
      get :preview_data
      post :send_to_queue
      post :upd_shipping
      get :change_supplier
    end
    
    member do
      get :orderdetails
      get :billingdetails
      get :shippingdetails
      get :edit_shipping
      post :update_shipping
      get :ajax_edit_shipping
      
    end
    
  end
  
  resources :orders do
    collection do
      get :check_custname
      get :dlwebshark
      get :websharks
      post :websharks
      get :change_supplier
      get :mark_order_as_paid
      post :send_reorders
      get :reorders
      get :shipping_notifications
      get :check_gen_xls
      get :check_shipping_xls
      post :imports
      get :imports
      get :download_import
      get :download_xls
      get :download_csv
      post :generate_spreadsheet
      post :generate_spreadsheet_mage
      get :spreadsheets
      get :check_duplicate
      get :check_qty_duplicate
      get :order_summary
      get :update_totals
      get :pending
      get :unpaid
      get :paid
      get :submitted
      get :partial
      get :shipped
      get :preview_data
      post :updatestatus
      post :send_to_queue
      get :index_datatables
    end
    
    member do
      post :undelete
      get :orderdetails
      get :billingdetails
      get :shippingdetails
      get :edit_shipping
      put :shipping
      put :upd_shipping
      get :ajax_edit_shipping
      get :split_by_qty
      post :setnotes
    end
  end
  
  resources :accounts, :controller => "accounts" do
    collection do
      get :list_sales_invoice
      post :list_sales_invoice
      get :download_generated_xls
      get :list_unmatched_payments
      post :list_unmatched_payments
      get :save_mark_as_paid
      get :list_sale_totals
      post :list_sale_totals
      get :save_visibility
      post :save_notes
    end
    
    member do
      
    end
  end

  resources :systems, :controller => "systems" do
    collection do
    end
    
    member do
      
    end
  end

  match "/links" => "dashboard#links"
  match "/profile" => "dashboard#profile"
  match "/search" => "products#search"
  root :to => "dashboard#index"

end
