# Thumbsy API Configuration
# Configure the voting API to work with your authentication system

Thumbsy::Api.configure do |config|
  # Authentication settings
  config.require_authentication = true
  
  # Define how to authenticate users
  # Example for Devise:
  config.authentication_method = proc do
    authenticate_user! # Your authentication method
  end
  
  # Define how to get the current voter
  # Example for Devise:
  config.current_voter_method = proc do
    current_user # Your current user method
  end
  
  # Authorization (optional)
  # config.require_authorization = true
  # config.authorization_method = proc do |votable, voter|
  #   # Return true/false for permission to vote
  #   case votable.class.name
  #   when "Book"
  #     votable.published? && !votable.archived?
  #   when "Comment"
  #     votable.@book.published? && voter.can_vote?
  #   else
  #     true
  #   end
  # end
  
  # Custom voter serialization for API responses
  # config.voter_serializer = proc do |voter|
  #   {
  #     id: voter.id,
  #     name: voter.name,
  #     avatar: voter.avatar.attached? ? rails_blob_url(voter.avatar) : nil
  #   }
  # end
  
  # Vote model name (if you want to customize)
  # config.vote_model_name = "CustomVote"
end

# Examples for different authentication systems:

# JWT Authentication:
# config.authentication_method = proc do
#   token = request.headers["Authorization"]&.split(" ")&.last
#   @decoded_token = JWT.decode(token, Rails.application.secret_key_base).first
#   @current_user = User.find(@decoded_token["user_id"])
# rescue JWT::DecodeError
#   head :unauthorized
# end

# API Key Authentication:
# config.authentication_method = proc do
#   api_key = request.headers["X-API-Key"]
#   @current_user = User.find_by(api_key: api_key)
#   head :unauthorized unless @current_user
# end

# Session-based Authentication:
# config.authentication_method = proc do
#   @current_user = User.find(session[:user_id]) if session[:user_id]
#   head :unauthorized unless @current_user
# end
