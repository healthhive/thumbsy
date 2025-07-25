# frozen_string_literal: true

Thumbsy::Engine.routes.draw do
  # Flexible routes that can be mounted anywhere
  scope ":votable_type/:votable_id" do
    post "votes/vote_up", to: "votes#vote_up"
    post "votes/vote_down", to: "votes#vote_down"
    delete "votes/remove", to: "votes#remove"
    get "votes/status", to: "votes#status"
    get "votes", to: "votes#index"

    # Alternative shorter routes
    post "vote_up", to: "votes#vote_up"
    post "vote_down", to: "votes#vote_down"
    delete "vote", to: "votes#remove"
    get "vote", to: "votes#show"
  end

  # Bulk operations (optional)
  resources :votes, only: %i[index show] do
    collection do
      get :summary
    end
  end
end
