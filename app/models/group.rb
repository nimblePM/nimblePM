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

class Group < Principal
  include ::Scopes::Scoped

  has_many :group_users,
           autosave: true,
           dependent: :destroy

  has_many :users,
           through: :group_users,
           before_add: :fail_add

  acts_as_customizable

  alias_attribute(:name, :lastname)
  validates :name, presence: true
  validate :uniqueness_of_name
  validates :name, length: { maximum: 256 }

  # HACK: We want to have the :preference association on the Principal to allow
  # for eager loading preferences.
  # However, the preferences are currently very user specific.  We therefore
  # remove the methods added by
  #   has_one :preference
  # to avoid accidental assignment and usage of preferences on groups.
  undef_method :preference,
               :preference=,
               :build_preference,
               :create_preference,
               :create_preference!

  scopes :visible

  # Columns required for formatting the group's name.
  def self.columns_for_name(_formatter = nil)
    [:lastname]
  end

  def to_s
    lastname
  end

  def scim_external_id
    return nil if identity_url.blank?

    identity_url.split(":", 2).second
  end

  def scim_external_id=(external_id)
    oidc_provider = OpenIDConnect::Provider.first
    raise "There should at least one OIDC Provider for SCIM to work with" unless oidc_provider

    self.identity_url = "#{oidc_provider.slug}:#{external_id}"
    external_id
  end

  def scim_users_and_groups
    users
  end

  def scim_users_and_groups=(_array)
    # Nothing is happening here, because users should be added/removed to the group
    # through Groups::UpdateSerivce. So, it is done on a higher(controller) level.
    users
  end

  def self.scim_resource_type
    Scimitar::Resources::Group
  end

  def self.scim_attributes_map
    {
      id: :id,
      externalId: :scim_external_id,
      displayName: :name,
      members: [
        list: :scim_users_and_groups,
        using: {
          value: :id
        },
        find_with: ->(scim_list_entry) {
          id   = scim_list_entry["value"]
          type = scim_list_entry["type"] || "User" # Some online examples omit 'type' and believe 'User' will be assumed

          case type.downcase
          when "user"
            User.not_builtin.find_by(id:)
          when "group"
            # OP does not support nesting of groups but SCIM does.
            # For now raises exception in case of group as a member arrival.
            raise Scimitar::InvalidSyntaxError.new("Unsupported type #{type.inspect}")
          else
            raise Scimitar::InvalidSyntaxError.new("Unrecognised type #{type.inspect}")
          end
        }
      ]
    }
  end

  def self.scim_mutable_attributes
    # Allow mutation of everything with a write accessor
    nil
  end

  def self.scim_queryable_attributes
    {
      displayName: { column: :lastname }
    }
  end

  def self.scim_timestamps_map
    {
      created: :created_at,
      lastModified: :updated_at
    }
  end

  include Scimitar::Resources::Mixin

  private

  def uniqueness_of_name
    groups_with_name = Group.where("lastname = ? AND id <> ?", name, id || 0).count
    if groups_with_name > 0
      errors.add :name, :taken
    end
  end

  def fail_add
    fail "Do not add users through association, use `Groups::AddUsersService` instead."
  end
end
