# frozen_string_literal: true

module Thumbsy
  module Api
    class ApplicationController < ActionController::API
      before_action :authenticate_voter!, if: :authentication_required?
      before_action :set_current_voter

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      protected

      def authenticate_voter!
        if Thumbsy::Api.authentication_method
          instance_eval(&Thumbsy::Api.authentication_method)
        else
          head :unauthorized unless current_voter.present?
        end
      end

      def set_current_voter
        if Thumbsy::Api.current_voter_method
          @current_voter = instance_eval(&Thumbsy::Api.current_voter_method)
        elsif respond_to?(:current_user)
          @current_voter = current_user
        end
      end

      attr_reader :current_voter

      def authentication_required?
        Thumbsy::Api.require_authentication
      end

      def render_success(data = {}, status = :ok)
        render json: { success: true, data: data }, status: status
      end

      def render_error(message, status = :bad_request, errors = {})
        render json: { success: false, error: message, errors: errors }, status: status
      end

      def render_not_found(_exception)
        render_error("Resource not found", :not_found)
      end
    end
  end
end
