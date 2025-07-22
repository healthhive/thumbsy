# frozen_string_literal: true

module Thumbsy
  module Api
    class Engine < ::Rails::Engine
      isolate_namespace Thumbsy::Api

      # Load API routes
      config.after_initialize do
        Thumbsy::Api::Engine.routes.draw do
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
            get "vote", to: "votes#status"
          end
        end
      end
    end
  end
end
