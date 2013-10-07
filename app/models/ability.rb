class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    
    user ||= Accounts::User.new # guest user (not logged in)
    case user.user_type
    when :superadmin
      can :manage, :all

    when :admin
      can :use, Admins::AdminsController
      can :use, Admins::UsersController
      can :use, Admins::DealersController

      can :manage, Accounts::Admin, id: user.id
      can :manage, [Accounts::Dealer, Accounts::Provider, Accounts::User]
      
      # no one can destroy superadmin
      cannot :manage, Accounts::Admin, id: 1

    when :guest

    when :provider
      can :use, SettingsController
      can :use, Users::InverseFriendsController

      can :use, Bcst::DashboardsController
      # if user.accepted?
        can :use, Bcst::HostsController
        can :use, Bcst::ProgrammesController
        can :use, Bcst::ProgrammeListsController
        can :use, Bcst::CommentsController
        can :use, Bcst::ExposuresController
        can :use, Bcst::TrafficReportsController
      # end

    when :dealer
      can :use, SettingsController
      can :use, Users::InverseFriendsController
      can :use, Users::ReviewsController

      can :use, Tips::DashboardsController
      # if user.accepted?
        can :use, Tips::CleaningsController
        can :use, Tips::MendingsController
        can :use, Tips::ActivitiesController
        can :use, Tips::BulkPurchasingsController
      # end
      
    when :user
      can :destroy, [Posts::Post, Share::Comment], user_id: user.id
      can :destroy, [Bcst::Exposure, Bcst::TrafficReport], user_id: user.id
      can :update, Tips::Order, user_id: user.id
      can :update, Posts::Club, president_id: user.id
      
    end
    
    # The first argument to `can` is the action you are giving the user 
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. 
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
