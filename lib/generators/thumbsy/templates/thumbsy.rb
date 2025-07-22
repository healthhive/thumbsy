# Thumbsy Configuration
# All Thumbsy and Thumbsy API settings are centralized here.

Thumbsy.configure do |config|
  config.feedback_options = %w[unclear confusing incorrect_info other]

  config.api do |api_config|
    # Uncomment and customize the following as needed:

    # Authentication settings
    # api_config.require_authentication = true

    # Example for Devise:
    # api_config.authentication_method = proc { authenticate_user! }
    # api_config.current_voter_method = proc { current_user }

    # Authorization (optional)
    # api_config.require_authorization = true
    # api_config.authorization_method = proc { |votable, voter| ... }

    # Custom voter serialization for API responses
    # api_config.voter_serializer = proc { |voter| { id: voter.id, ... } }
  end
end
