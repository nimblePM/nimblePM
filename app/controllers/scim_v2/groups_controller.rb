# frozen_string_literal: true

module ScimV2
  class GroupsController < Scimitar::ResourcesController
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
      super do |group_id|
        group = storage_scope.find(group_id)
        group.to_scim(location: url_for(action: :show, id: group_id))
      end
    end

    def create
      super do |scim_resource|
        storage_class.transaction do
          group = storage_class.new
          group.from_scim!(scim_hash: scim_resource.as_json)
          call = Groups::CreateService
                   .new(user: User.system)
                   .call(group.attributes)
                   .on_failure { |result| raise result.message }
          group = call.result
          Groups::AddUsersService
            .new(group, current_user: User.system)
            .call(ids: scim_resource.members.map(&:value), send_notifications: false)
            .on_failure { |call| raise call.message }

          group.to_scim(location: url_for(action: :show, id: group.id))
        end
      end
    end

    def replace
      super do |group_id, scim_resource|
        storage_class.transaction do
          group = storage_scope.find(group_id)
          group.from_scim!(scim_hash: scim_resource.as_json)
          Groups::UpdateService
            .new(user: User.system, model: group)
            .call
            .on_failure { |call| raise call.message }
          group.to_scim(location: url_for(action: :show, id: group.id))
        end
      end
    end

    def update
      super do |group_id, patch_hash|
        storage_class.transaction do
          group = storage_scope.find(group_id)
          group.from_scim_patch!(patch_hash: patch_hash)
          Groups::UpdateService
            .new(user: User.system, model: group)
            .call
            .on_failure { |call| raise call.message }
          group.to_scim(location: url_for(action: :show, id: group.id))
        end
      end
    end

    def destroy
      super do |group_id|
        group = storage_scope.find(group_id)
        Groups::DeleteService
          .new(user: User.system, model: group)
          .call
          .on_failure { |call| raise call.message }
      end
    end

    protected

    def storage_class
      Group
    end

    def storage_scope
      Group.all
    end
  end
end
