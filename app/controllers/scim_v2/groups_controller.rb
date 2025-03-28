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

module ScimV2
  class GroupsController < Scimitar::ResourcesController
    include BaseControllerActions

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
            .call(user_ids: scim_resource.members.map(&:value))
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
