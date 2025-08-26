# frozen_string_literal: true

require "spec_helper"
require_module_spec_helper

module Storages
  module Adapters
    module Providers
      module Sharepoint
        module Validators
          RSpec.describe StorageConfigurationValidator, :webmock do
            let(:storage) { create(:sharepoint_storage, :sandbox, :as_automatically_managed) }
            let(:error) { Results::Error.new(code: error_code, source: self) }

            subject(:validator) { described_class.new(storage) }

            describe "success", vcr: "sharepoint/files_query_userless" do
              it "returns a GroupValidationResult" do
                results = validator.call

                expect(results).to be_a(ConnectionValidators::ValidationGroupResult)
                expect(results).to be_success
              end
            end

            describe "failure" do
              let(:files_double) { class_double(Queries::FilesQuery) }
              let(:auth_strategy) { Registry["sharepoint.authentication.userless"].call }
              let(:input_data) { Input::Files.build(folder: "/").value! }
              let(:result) { Success() }

              before do
                allow(files_double).to receive(:call).with(storage:, auth_strategy:, input_data:).and_return(result)
              end

              context "when the storage isn't configured" do
                let(:storage) { create(:sharepoint_storage) }

                it "the check fails" do
                  results = validator.call
                  expect(results[:storage_configured]).to be_a_failure
                  expect(results[:storage_configured].code).to eq(:not_configured)
                end
              end

              context "when the tenant id is wrong" do
                it "but looks like an actual valid value", vcr: "sharepoint/validation_wrong_tenant_id" do
                  storage.tenant_id = "itdoesnotexists9000.sharepoint.com"
                  results = described_class.new(storage).call

                  expect(results[:tenant_id]).to be_a_failure
                  expect(results[:tenant_id].code).to eq(:sp_tenant_id_invalid)
                end

                it "but is blatantly wrong", vcr: "sharepoint/validation_absurd_tenant_id" do
                  storage.tenant_id = "wrong"
                  results = described_class.new(storage).call

                  expect(results[:tenant_id]).to be_a_failure
                  expect(results[:tenant_id].code).to eq(:sp_tenant_id_invalid)
                end
              end

              context "when the client secret is wrong" do
                it "fails the check", vcr: "sharepoint/validation_wrong_client_secret" do
                  storage.oauth_client.client_secret = "wrong"
                  results = described_class.new(storage).call

                  expect(results[:client_secret]).to be_a_failure
                  expect(results[:client_secret].code).to eq(:client_secret_invalid)
                end
              end

              context "when the client id is wrong" do
                it "fails the check", vcr: "sharepoint/validation_wrong_client_id" do
                  storage.oauth_client.client_id = "wrong"
                  results = described_class.new(storage).call

                  expect(results[:client_id]).to be_a_failure
                  expect(results[:client_id].code).to eq(:client_id_invalid)
                end
              end
            end
          end
        end
      end
    end
  end
end
