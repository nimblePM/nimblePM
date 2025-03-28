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

RSpec.describe "SCIM API Groups" do
  let(:external_user_id) { "idp_user_id_123asdqwe12345" }
  let(:external_group_id) { "idp_group_id_123asdqwe12345" }
  let(:admin) { create(:admin) }
  let(:oidc_provider) { create(:oidc_provider, slug: "keycloak", creator: admin) }
  let(:user) { create(:user, identity_url: "#{oidc_provider.slug}:#{external_user_id}") }
  let(:group) { create(:group, identity_url: "#{oidc_provider.slug}:#{external_group_id}", members: [user]) }
  let(:headers) { { "CONTENT_TYPE" => "application/scim+json", "HTTP_AUTHORIZATION" => "Bearer access_token" } }

  describe "GET /scim_v2/Groups" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      before { group }

      it do
        get "/scim_v2/Groups", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "Resources" => [{ "displayName" => group.name,
                                                        "externalId" => external_group_id,
                                                        "id" => group.id.to_s,
                                                        "members" => [{ "value" => user.id.to_s }],
                                                        "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                                    "created" => group.created_at.iso8601,
                                                                    "lastModified" => group.updated_at.iso8601,
                                                                    "resourceType" => "Group" },
                                                        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] }],
                                      "itemsPerPage" => 100,
                                      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                                      "startIndex" => 1,
                                      "totalResults" => 1 })
      end

      it "filters results" do
        filter = ERB::Util.url_encode('displayName Eq "' + group.name + '"')
        get "/scim_v2/Groups?filter=#{filter}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "Resources" => [{ "displayName" => group.name,
                                                        "externalId" => external_group_id,
                                                        "id" => group.id.to_s,
                                                        "members" => [{ "value" => user.id.to_s }],
                                                        "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                                    "created" => group.created_at.iso8601,
                                                                    "lastModified" => group.updated_at.iso8601,
                                                                    "resourceType" => "Group" },
                                                        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] }],
                                      "itemsPerPage" => 100,
                                      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
                                      "startIndex" => 1,
                                      "totalResults" => 1 })

        filter = ERB::Util.url_encode('displayName Eq "NONEXISTENT GROUP NAME"')
        get "/scim_v2/Groups?filter=#{filter}", {}, headers

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
        get "/scim_v2/Groups", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "GET /scim_v2/Groups/:id" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        group
        get "/scim_v2/Groups/#{group.id}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "displayName" => group.name,
                                      "externalId" => external_group_id,
                                      "id" => group.id.to_s,
                                      "members" => [{ "value" => user.id.to_s }],
                                      "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                  "created" => group.created_at.iso8601,
                                                  "lastModified" => group.updated_at.iso8601,
                                                  "resourceType" => "Group" },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        get "/scim_v2/Groups/#{group.id}", {}, headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "POST /scim_v2/Groups/" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        user
        request_body = { "displayName" => "Group 123",
                         "externalId" => external_group_id,
                         "members" => [{ "value" => user.id.to_s }],
                         "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] }
        post "/scim_v2/Groups/", request_body.to_json, headers

        response_body = JSON.parse(last_response.body)
        group = Group.last
        expect(Group.count).to eq(1)
        expect(response_body).to eq({ "displayName" => group.name,
                                      "externalId" => external_group_id,
                                      "id" => group.id.to_s,
                                      "members" => [{ "value" => user.id.to_s }],
                                      "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                  "created" => group.created_at.iso8601,
                                                  "lastModified" => group.updated_at.iso8601,
                                                  "resourceType" => "Group" },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        post "/scim_v2/Groups/", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end

  describe "DELETE /scim_v2/Groups/:id" do
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        group
        delete "/scim_v2/Groups/#{group.id}", "", headers

        expect(last_response.body).to eq("")
        expect(last_response).to have_http_status(204)

        get "/scim_v2/Groups/#{group.id}", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq({ "displayName" => group.name,
                                      "externalId" => external_group_id,
                                      "id" => group.id.to_s,
                                      "members" => [{ "value" => user.id.to_s }],
                                      "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                  "created" => group.created_at.iso8601,
                                                  "lastModified" => group.updated_at.iso8601,
                                                  "resourceType" => "Group" },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] })

        perform_enqueued_jobs
        assert_performed_jobs 1

        get "/scim_v2/Groups/#{group.id}", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Resource \"#{group.id}\" not found",
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
    context "with the feature flag enabled", with_flag: { scim_api: true } do
      it do
        group
        new_external_group_id = "new_idp_group_id_123asdqwe12345"
        request_body = {
          "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"],
          "active" => true,
          "externalId" => new_external_group_id,
          "displayName" => group.name,
          "members" => [
            { "value" => user.id.to_s },
            { "value" => admin.id.to_s },
          ],
          "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"]
        }

        put "/scim_v2/Groups/#{group.id}", request_body.to_json, headers

        response_body = JSON.parse(last_response.body)
        group.reload
        expect(response_body).to eq({ "displayName" => group.name,
                                      "externalId" => new_external_group_id,
                                      "id" => group.id.to_s,
                                      "members" => [
                                        { "value" => admin.id.to_s },
                                        { "value" => user.id.to_s },
                                      ],
                                      "meta" => { "location" => "http://test.host/scim_v2/Groups/#{group.id}",
                                                  "created" => group.created_at.iso8601,
                                                  "lastModified" => group.updated_at.iso8601,
                                                  "resourceType" => "Group" },
                                      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:Group"] })
      end
    end

    context "with the feature flag disabled", with_flag: { scim_api: false } do
      it do
        put "/scim_v2/Groups/123", "", headers

        response_body = JSON.parse(last_response.body)
        expect(response_body).to eq(
          { "detail" => "Requires authentication", "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
            "status" => "401" }
        )
      end
    end
  end
end
