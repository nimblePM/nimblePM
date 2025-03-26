# frozen_string_literal: true

module ScimV2
  class UsersController < Scimitar::ResourcesController
    skip_before_action :verify_authenticity_token

    rescue_from "ActiveRecord::RecordNotFound", with: :handle_resource_not_found

    def index
      query = if params[:filter].blank?
                storage_scope
              else
                attribute_map = storage_class.new.scim_queryable_attributes
                parser        = ::Scimitar::Lists::QueryParser.new(attribute_map)

                parser.parse(params[:filter])
                parser.to_activerecord_query(storage_scope)
              end

      pagination_info = scim_pagination_info(query.count)
      page_of_results = query
                          .order(id: :asc)
                          .offset(pagination_info.offset)
                          .limit(pagination_info.limit)
                          .to_a

      super(pagination_info, page_of_results) do |record|
        record.to_scim(location: url_for(action: :show, id: record.id))
      end
    end

    def show
      super do |user_id|
        user = storage_scope.find(user_id)
        user.to_scim(location: url_for(action: :show, id: user_id))
      end
    end

    def create
      super do |scim_resource|
        storage_class.transaction do
          user = storage_class.new
          user.from_scim!(scim_hash: scim_resource.as_json)
          call = Users::CreateService
                   .new(user: User.system)
                   .call(user.attributes)
                   .on_failure { |result| raise result.message }

          user = call.result
          user.to_scim(location: url_for(action: :show, id: user.id))
        end
      end
    end

    def replace
      super do |user_id, scim_resource|
        storage_class.transaction do
          user = storage_scope.find(user_id)
          user.from_scim!(scim_hash: scim_resource.as_json)
          Users::UpdateService
            .new(user: User.system, model: user)
            .call
            .on_failure { |call| raise call.message }
          user.to_scim(location: url_for(action: :show, id: user.id))
        end
      end
    end

    def update
      super do |user_id, patch_hash|
        storage_class.transaction do
          user = storage_scope.find(user_id)
          user.from_scim_patch!(patch_hash: patch_hash)
          Users::UpdateService
            .new(user: User.system, model: user)
            .call
            .on_failure { |call| raise call.message }
          user.to_scim(location: url_for(action: :show, id: user.id))
        end
      end
    end

    def destroy
      super do |user_id|
        user = storage_scope.find(user_id)
        Users::DeleteService
          .new(user: User.system, model: user)
          .call
          .on_failure { |call| raise call.message }
      end
    end

    protected

    def storage_class
      User
    end

    def storage_scope
      User.user.where.not(identity_url: [nil, ""])
    end
  end
end
