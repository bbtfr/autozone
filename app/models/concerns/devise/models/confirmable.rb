module Devise
  module Models
    # Confirmable is responsible to verify if an account is already confirmed to
    # sign in, and to send mobiles with confirmation instructions.
    # Confirmation instructions are sent to the user mobile after creating a
    # record and when manually requested by a new confirmation instruction request.
    #
    # == Options
    #
    # Confirmable adds the following options to +devise+:
    #
    #   * +allow_unconfirmed_access_for+: the time you want to allow the user to access his account
    #     before confirming it. After this period, the user access is denied. You can
    #     use this to let your user access some features of your application without
    #     confirming the account, but blocking it after a certain period (ie 7 days).
    #     By default allow_unconfirmed_access_for is zero, it means users always have to confirm to sign in.
    #   * +reconfirmable+: requires any mobile changes to be confirmed (exactly the same way as
    #     initial account confirmation) to be applied. Requires additional unconfirmed_mobile
    #     db field to be setup (t.reconfirmable in migrations). Until confirmed new mobile is
    #     stored in unconfirmed mobile column, and copied to mobile column on successful
    #     confirmation.
    #   * +confirm_within+: the time before a sent confirmation token becomes invalid.
    #     You can use this to force the user to confirm within a set period of time.
    #
    # == Examples
    #
    #   User.find(1).confirm!      # returns true unless it's already confirmed
    #   User.find(1).confirmed?    # true/false
    #   User.find(1).send_confirmation_instructions # manually send instructions
    #
    module Confirmable
      extend ActiveSupport::Concern
      include ActionView::Helpers::DateHelper

      included do
        before_create :generate_confirmation_token, :if => :confirmation_required?
        after_create  :send_on_create_confirmation_instructions, :if => :send_confirmation_notification?
        before_update :postpone_mobile_change_until_confirmation_and_regenerate_confirmation_token, :if => :postpone_mobile_change?
        after_update  :send_reconfirmation_instructions,  :if => :reconfirmation_required?
      end

      def initialize(*args, &block)
        @bypass_confirmation_postpone = false
        @reconfirmation_required = false
        @skip_confirmation_notification = false
        @raw_confirmation_token = nil
        super
      end

      def self.required_fields(klass)
        required_methods = [:confirmation_token, :confirmed_at, :confirmation_sent_at]
        required_methods << :unconfirmed_mobile if klass.reconfirmable
        required_methods
      end

      # Confirm a user by setting it's confirmed_at to actual time. If the user
      # is already confirmed, add an error to mobile field. If the user is invalid
      # add errors
      def confirm!
        pending_any_confirmation do
          if confirmation_period_expired?
            self.errors.add(:mobile, :confirmation_period_expired,
              :period => Devise::TimeInflector.time_ago_in_words(self.class.confirm_within.ago))
            return false
          end

          self.confirmation_token = nil
          self.confirmed_at = Time.now.utc

          saved = if self.class.reconfirmable && unconfirmed_mobile.present?
            skip_reconfirmation!
            self.mobile = unconfirmed_mobile
            self.unconfirmed_mobile = nil

            # We need to validate in such cases to enforce e-mail uniqueness
            save(:validate => true)
          else
            save(:validate => false)
          end

          after_confirmation if saved
          saved
        end
      end

      # Verifies whether a user is confirmed or not
      def confirmed?
        !!confirmed_at
      end

      def pending_reconfirmation?
        self.class.reconfirmable && unconfirmed_mobile.present?
      end

      # Send confirmation instructions by mobile
      def send_confirmation_instructions
        unless @raw_confirmation_token
          generate_confirmation_token!
        end

        opts = pending_reconfirmation? ? { :to => unconfirmed_mobile } : { }
        send_devise_notification(:confirmation_instructions, @raw_confirmation_token, opts)
      end

      def send_reconfirmation_instructions
        @reconfirmation_required = false

        unless @skip_confirmation_notification
          send_confirmation_instructions
        end
      end

      # Resend confirmation token.
      # Regenerates the token if the period is expired.
      def resend_confirmation_instructions
        pending_any_confirmation do
          send_confirmation_instructions
        end
      end

      # Overwrites active_for_authentication? for confirmation
      # by verifying whether a user is active to sign in or not. If the user
      # is already confirmed, it should never be blocked. Otherwise we need to
      # calculate if the confirm time has not expired for this user.
      def active_for_authentication?
        super && (!confirmation_required? || confirmed? || confirmation_period_valid?)
      end

      # The message to be shown if the account is inactive.
      def inactive_message
        !confirmed? ? :unconfirmed : super
      end

      # If you don't want confirmation to be sent on create, neither a code
      # to be generated, call skip_confirmation!
      def skip_confirmation!
        self.confirmed_at = Time.now.utc
      end

      # Skips sending the confirmation/reconfirmation notification mobile after_create/after_update. Unlike
      # #skip_confirmation!, record still requires confirmation.
      def skip_confirmation_notification!
        @skip_confirmation_notification = true
      end

      # If you don't want reconfirmation to be sent, neither a code
      # to be generated, call skip_reconfirmation!
      def skip_reconfirmation!
        @bypass_confirmation_postpone = true
      end

      protected

        # A callback method used to deliver confirmation
        # instructions on creation. This can be overriden
        # in models to map to a nice sign up e-mail.
        def send_on_create_confirmation_instructions
          send_confirmation_instructions
        end

        # Callback to overwrite if confirmation is required or not.
        def confirmation_required?
          !confirmed?
        end

        # Checks if the confirmation for the user is within the limit time.
        # We do this by calculating if the difference between today and the
        # confirmation sent date does not exceed the confirm in time configured.
        # Confirm_within is a model configuration, must always be an integer value.
        #
        # Example:
        #
        #   # allow_unconfirmed_access_for = 1.day and confirmation_sent_at = today
        #   confirmation_period_valid?   # returns true
        #
        #   # allow_unconfirmed_access_for = 5.days and confirmation_sent_at = 4.days.ago
        #   confirmation_period_valid?   # returns true
        #
        #   # allow_unconfirmed_access_for = 5.days and confirmation_sent_at = 5.days.ago
        #   confirmation_period_valid?   # returns false
        #
        #   # allow_unconfirmed_access_for = 0.days
        #   confirmation_period_valid?   # will always return false
        #
        #   # allow_unconfirmed_access_for = nil
        #   confirmation_period_valid?   # will always return true
        #
        def confirmation_period_valid?
          self.class.allow_unconfirmed_access_for.nil? || (confirmation_sent_at && confirmation_sent_at.utc >= self.class.allow_unconfirmed_access_for.ago)
        end

        # Checks if the user confirmation happens before the token becomes invalid
        # Examples:
        #
        #   # confirm_within = 3.days and confirmation_sent_at = 2.days.ago
        #   confirmation_period_expired?  # returns false
        #
        #   # confirm_within = 3.days and confirmation_sent_at = 4.days.ago
        #   confirmation_period_expired?  # returns true
        #
        #   # confirm_within = nil
        #   confirmation_period_expired?  # will always return false
        #
        def confirmation_period_expired?
          self.class.confirm_within && (Time.now > self.confirmation_sent_at + self.class.confirm_within )
        end

        # Checks whether the record requires any confirmation.
        def pending_any_confirmation
          if (!confirmed? || pending_reconfirmation?)
            yield
          else
            self.errors.add(:mobile, :already_confirmed)
            false
          end
        end

        # Generates a new random token for confirmation, and stores
        # the time this token is being generated
        def generate_confirmation_token
          raw, enc = Devise.token_generator.generate_number(self.class, :confirmation_token)
          @raw_confirmation_token   = raw
          self.confirmation_token   = enc
          self.confirmation_sent_at = Time.now.utc
        end

        def generate_confirmation_token!
          generate_confirmation_token && save(:validate => false)
        end

        def postpone_mobile_change_until_confirmation_and_regenerate_confirmation_token
          @reconfirmation_required = true
          self.unconfirmed_mobile = self.mobile
          self.mobile = self.mobile_was
          generate_confirmation_token
        end

        def postpone_mobile_change?
          postpone = self.class.reconfirmable && mobile_changed? && !@bypass_confirmation_postpone && !self.mobile.blank?
          @bypass_confirmation_postpone = false
          postpone
        end

        def reconfirmation_required?
          self.class.reconfirmable && @reconfirmation_required && !self.mobile.blank?
        end

        def send_confirmation_notification?
          confirmation_required? && !@skip_confirmation_notification && !self.mobile.blank?
        end

        def after_confirmation
        end

      module ClassMethods
        # Attempt to find a user by its mobile. If a record is found, send new
        # confirmation instructions to it. If not, try searching for a user by unconfirmed_mobile
        # field. If no user is found, returns a new user with an mobile not found error.
        # Options must contain the user mobile
        def send_confirmation_instructions(attributes={})
          confirmable = find_by_unconfirmed_mobile_with_errors(attributes) if reconfirmable
          unless confirmable.try(:persisted?)
            confirmable = find_or_initialize_with_errors(confirmation_keys, attributes, :not_found)
          end
          confirmable.resend_confirmation_instructions if confirmable.persisted?
          confirmable
        end

        # Find a user by its confirmation token and try to confirm it.
        # If no user is found, returns a new user with an error.
        # If the user is already confirmed, create an error for the user
        # Options must have the confirmation_token
        def confirm_by_token(confirmation_token)
          original_token     = confirmation_token
          confirmation_token = Devise.token_generator.digest(self, :confirmation_token, confirmation_token)

          confirmable = find_or_initialize_with_error_by(:confirmation_token, confirmation_token)
          if !confirmable.persisted? && Devise.allow_insecure_token_lookup
            confirmable = find_or_initialize_with_error_by(:confirmation_token, original_token)
          end

          confirmable.confirm! if confirmable.persisted?
          confirmable.confirmation_token = original_token
          confirmable
        end

        # Find a record for confirmation by unconfirmed mobile field
        def find_by_unconfirmed_mobile_with_errors(attributes = {})
          unconfirmed_required_attributes = confirmation_keys.map { |k| k == :mobile ? :unconfirmed_mobile : k }
          unconfirmed_attributes = attributes.symbolize_keys
          unconfirmed_attributes[:unconfirmed_mobile] = unconfirmed_attributes.delete(:mobile)
          find_or_initialize_with_errors(unconfirmed_required_attributes, unconfirmed_attributes, :not_found)
        end

        Devise::Models.config(self, :allow_unconfirmed_access_for, :confirmation_keys, :reconfirmable, :confirm_within)
      end
    end
  end
end