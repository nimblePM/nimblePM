# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe "SCIM API Users" do
  let(:external_user_id) { "idp_user_id_123asdqwe12345" }
  let(:external_group_id) { "idp_group_id_123asdqwe12345" }
  let(:admin) { create(:admin) }
  let(:oidc_provider) { create(:oidc_provider, slug: "keycloak", creator: admin) }
  let(:user) { create(:user, identity_url: "#{oidc_provider.slug}:#{external_user_id}") }
  let(:group) { create(:group, identity_url: "#{oidc_provider.slug}:#{external_group_id}", members: [user]) }
  let(:headers) { { "CONTENT_TYPE" => "application/scim+json", "HTTP_AUTHORIZATION" => "Bearer access_token" } }

  describe "GET /scim_v2/Users" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      before { group }

      it do
        get "/scim_v2/Users", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq("Resources" =>
                                      [{ "active" => true,
                                         "emails" => [{ "primary" => true,
                                                        "type" => "work",
                                                        "value" => admin.mail }],
                                         "externalId" => nil,
                                         "groups" => [],
                                         "id" => admin.id.to_s,
                                         "meta" => { "created" => admin.created_at.iso8601,
                                                     "lastModified" => admin.updated_at.iso8601,
                                                     "location" => "http://test.host/scim_v2/Users/#{admin.id}",
                                                     "resourceType" => "User" },
                                         "name" => { "familyName" => admin.lastname,
                                                     "givenName" => admin.firstname },
                                         "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                         "userName" => admin.login },
                                       { "active" => true,
                                         "emails" => [{ "primary" => true,
                                                        "type" => "work",
                                                        "value" => user.mail }],
                                         "externalId" => external_user_id,
                                         "groups" => [{ "value" => group.id.to_s }],
                                         "id" => user.id.to_s,
                                         "meta" => { "created" => user.created_at.iso8601,
                                                     "lastModified" => user.updated_at.iso8601,
                                                     "location" => "http://test.host/scim_v2/Users/#{user.id}",
                                                     "resourceType" => "User" },
                                         "name" => { "familyName" => user.lastname,
                                                     "givenName" => user.firstname },
                                         "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                         "userName" => user.login },
                                      ],
                                    "itemsPerPage" => 100,
                                    "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                                    "startIndex" => 1,
                                    "totalResults" => 2)
      end

      it "filters results" do
        filter_with_existing_rows = ERB::Util.url_encode('familyName Eq "' + user.lastname + '"')
        get "/scim_v2/Users?filter=#{filter_with_existing_rows}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq("Resources" => [{ "active" => true,
                                                      "emails" => [{ "primary" => true,
                                                                     "type" => "work",
                                                                     "value" => user.mail }],
                                                      "externalId" => external_user_id,
                                                      "groups" => [{ "value" => group.id.to_s }],
                                                      "id" => user.id.to_s,
                                                      "meta" => { "created" => user.created_at.iso8601,
                                                                  "lastModified" => user.updated_at.iso8601,
                                                                  "location" => "http://test.host/scim_v2/Users/#{user.id}",
                                                                  "resourceType" => "User" },
                                                      "name" => { "familyName" => user.lastname,
                                                                  "givenName" => user.firstname },
                                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                                      "userName" => user.login }],
                                    "itemsPerPage" => 100,
                                    "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                                    "startIndex" => 1,
                                    "totalResults" => 1)

        filter_with_nonexisting_rows = ERB::Util.url_encode('familyName Eq "NONEXISTENT USER LASTNAME"')
        get "/scim_v2/Users?filter=#{filter_with_nonexisting_rows}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({"Resources" => [],
                                     "itemsPerPage" => 100,
                                     "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                                     "startIndex" => 1,
                                     "totalResults" => 0})
      end

    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        get "/scim_v2/Users", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "GET /scim_v2/Users/:id" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        group
        get "/scim_v2/Users/#{user.id}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "active" => true,
                                      "emails" => [{ "primary" => true,
                                                     "type" => "work",
                                                     "value" => user.mail }],
                                      "externalId" => external_user_id,
                                      "groups" => [{ "value" => group.id.to_s }],
                                      "id" => user.id.to_s,
                                      "meta" => { "created" => user.created_at.iso8601,
                                                  "lastModified" => user.updated_at.iso8601,
                                                  "location" => "http://test.host/scim_v2/Users/#{user.id}",
                                                  "resourceType" => "User" },
                                      "name" => { "familyName" => user.lastname,
                                                  "givenName" => user.firstname },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                      "userName" => user.login })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        get "/scim_v2/Users/#{user.id}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "POST /scim_v2/Users/" do
    before { oidc_provider }

    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        request_body = {
          "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
          "externalId" => external_user_id,
          "userName" => "jdoe",
          "name" => {
            "givenName" => "John",
            "familyName" => "Doe"
          },
          "active" => true,
          "emails" => [
            {
              "value" => "jdoe@example.com",
              "type" => "work",
              "primary" => true
            }
          ]
        }
        post "/scim_v2/Users/", request_body.to_json, headers

        response_body = JSON.parse(last_response.body)
        created_user = User.find_by(login: "jdoe")
        expect(response_body).to eq({ "active" => true,
                                      "emails" => [{ "primary" => true,
                                                     "type" => "work",
                                                     "value" => "jdoe@example.com" }],
                                      "externalId" => external_user_id,
                                      "groups" => [],
                                      "id" => created_user.id.to_s,
                                      "meta" => { "created" => created_user.created_at.iso8601,
                                                  "lastModified" => created_user.updated_at.iso8601,
                                                  "location" => "http://test.host/scim_v2/Users/#{created_user.id}",
                                                  "resourceType" => "User" },
                                      "name" => { "familyName" => "Doe",
                                                  "givenName" => "John" },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                      "userName" => "jdoe" })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        post "/scim_v2/Users/", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "DELETE /scim_v2/Users/:id" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        group

        delete "/scim_v2/Users/#{user.id}", "", headers

        expect(last_response.body).to eq("")
        expect(last_response).to have_http_status(204)

        get "/scim_v2/Users/#{user.id}", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "active" => false,
                                      "emails" => [{ "primary" => true,
                                                     "type" => "work",
                                                     "value" => user.mail }],
                                      "externalId" => external_user_id,
                                      "groups" => [{ "value" => group.id.to_s }],
                                      "id" => user.id.to_s,
                                      "meta" => { "created" => user.created_at.iso8601,
                                                  "lastModified" => user.updated_at.iso8601,
                                                  "location" => "http://test.host/scim_v2/Users/#{user.id}",
                                                  "resourceType" => "User" },
                                      "name" => { "familyName" => user.lastname,
                                                  "givenName" => user.firstname },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                      "userName" => user.login })

        perform_enqueued_jobs
        assert_performed_jobs 1

        get "/scim_v2/Users/#{user.id}", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Resource \"#{user.id}\" not found",
            "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "404" }
        )
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        delete "/scim_v2/Users/123", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "PUT /scim_v2/Users/:id" do
    before { group }

    context "with the feature flag enabled", with_flag: { scim_api: true } do
      let(:new_external_user_id) { "new_idp_user_id_123asdqwe12345" }

      it do
        request_body = {
          "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
          "externalId" => new_external_user_id,
          "userName" => "jdoe",
          "name" => {
            "givenName" => "John",
            "familyName" => "Doe"
          },
          "active" => true,
          "emails" => [
            {
              "value" => "jdoe@example.com",
              "type" => "work",
              "primary" => true
            }
          ]
        }

        put "/scim_v2/Users/#{user.id}", request_body.to_json, headers

        response_body = JSON.parse(last_response.body)
        user.reload
        expect(response_body).to eq({ "active" => true,
                                      "emails" => [{ "primary" => true,
                                                     "type" => "work",
                                                     "value" => request_body["emails"].first["value"] }],
                                      "externalId" => new_external_user_id,
                                      "groups" => [{ "value" => group.id.to_s }],
                                      "id" => user.id.to_s,
                                      "meta" => { "created" => user.created_at.iso8601,
                                                  "lastModified" => user.updated_at.iso8601,
                                                  "location" => "http://test.host/scim_v2/Users/#{user.id}",
                                                  "resourceType" => "User" },
                                      "name" => { "familyName" => request_body["name"]["familyName"],
                                                  "givenName" => request_body["name"]["givenName"] },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
                                      "userName" => request_body["userName"] })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        headers = { "CONTENT_TYPE" => "application/scim+json", "HTTP_AUTHORIZATION" => "Bearer access_token" }
        put "/scim_v2/Users/123", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end
end
