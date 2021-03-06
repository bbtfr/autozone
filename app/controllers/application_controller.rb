class ApplicationController < ActionController::Base
  protect_from_forgery

  include FilterHelper
  before_filter :authenticate_account!
  before_filter :set_current_user
  before_filter :set_user_type

  def self.set_resource_class klass, options = {}
    respond_to :html
    options = options.reverse_merge(class: klass, autoload: true, title: :title)

    before_filter do
      method = "#{namespaced_name}_params"
      params[namespaced_name] &&= send(method) if respond_to?(method, true)
    end

    if options[:autoload]
      if options[:no_authorize]
        load_resource options
      else
        load_and_authorize_resource options
      end
    end

    def namespaced_name
      @namespaced_name ||= controller_path.gsub('/', '_').singularize.to_sym
    end

    def instance_name
      @instance_name ||= controller_path.split('/').last.singularize
    end

    def resource_instance
      instance_variable_get("@#{instance_name}")
    end

    def collection_instance
      instance_variable_get("@#{instance_name.to_s.pluralize}")
    end

    def resource_instance= instance
      instance_variable_set("@#{instance_name}", instance)
    end

    def collection_instance= instance
      instance_variable_set("@#{instance_name.to_s.pluralize}", instance)
    end


    if options[:singleton]

      define_method :edit do
      end

      define_method :update do
        if resource_instance.update_attributes params[namespaced_name]
          flash[:success] = i18n_message(:update_success_without_title)
          redirect_to after_update_path
        else
          render :edit
        end
      end

      define_method :after_update_path do
        { action: :show }
      end

    else # singletion

      define_method :index do
      end

      define_method :show do
      end

      unless options[:readonly]
        define_method :new do
        end

        define_method :create do
          if resource_instance.save
            flash[:success] = i18n_message(:create_success)
            redirect_to after_create_path
          else
            render :new
          end
        end

        define_method :after_create_path do
          { action: :index }
        end

        define_method :edit do
        end

        define_method :update do
          if resource_instance.update_attributes params[namespaced_name]
            flash[:success] = i18n_message(:update_success)
            redirect_to after_update_path
          else
            render :edit
          end
        end

        define_method :after_update_path do
          { action: :index }
        end
        
        define_method :destroy do
          resource_instance.destroy

          flash[:success] = i18n_message(:destroy_success)
          redirect_to :back
        end
      end

    end # singletion

    define_method :i18n_title do
      title = options[:title]
      resource = resource_instance
      resource.send(title) if resource.respond_to? title
    end

    define_method :i18n_message do |message_type|
      model = klass.model_name.i18n_key
      i18n_options = { model: I18n.t(model, scope: 'activerecord.models') }
      if options[:title]
        i18n_options[:title] = i18n_title
        I18n.t(message_type, i18n_options)
      else
        I18n.t("#{message_type}_without_title", i18n_options)
      end
    end

  end

  rescue_from CanCan::AccessDenied do |exception|
    flash[:error] = I18n.t(".access_denied")
    redirect_to :root
  end

end
