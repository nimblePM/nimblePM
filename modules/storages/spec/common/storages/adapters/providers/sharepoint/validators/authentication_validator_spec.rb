# frozen_string_literal: true

require "spec_helper"
require_module_spec_helper

RSpec.describe Storages::Adapters::Providers::Sharepoint::Validators::AuthenticationValidator, :webmock do
  subject(:validator) { described_class.new(storage) }

  context "when using OAuth2" do
    let(:user) { create(:user) }
    let(:storage) { create(:sharepoint_storage, :sandbox, oauth_client_token_user: user) }
    let(:error) { Storages::Adapters::Results::Error.new(code: :unauthorized, source: self) }

    before { User.current = user }

    it "has the correct key" do
      expect(described_class.key).to eq(:authentication)
    end

    it "passes when the user has a token and the request works", vcr: "sharepoint/user_query_success" do
      expect(validator.call).to be_success
    end

    it "returns a warning when there's no token for the current user" do
      User.current = create(:user)
      result = validator.call

      expect(result[:existing_token]).to be_a_warning
      expect(result[:existing_token].code).to eq(:sp_oauth_token_missing)
      expect(result[:user_bound_request]).to be_skipped
    end

    it "returns a failure if the remote call failed" do
      Storages::Adapters::Registry.stub("sharepoint.queries.user", ->(_) { Failure(error) })

      result = validator.call
      expect(result[:user_bound_request]).to be_a_failure
      expect(result[:user_bound_request].code).to eq(:sp_oauth_request_unauthorized)
    end
  end
end
