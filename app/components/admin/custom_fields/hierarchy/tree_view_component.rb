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

module Admin
  module CustomFields
    module Hierarchy
      class TreeViewComponent < ApplicationComponent
        def initialize(custom_field:, active_item:)
          super

          @custom_field = custom_field
          @active_item = active_item
        end

        def hierarchy_items
          @custom_field.hierarchy_root.children
        end

        def add_sub_tree(tree, item)
          if item.children.empty?
            tree.with_leaf(**item_options(item))
          else
            tree.with_sub_tree(expanded: true, **item_options(item)) do |sub_tree|
              item.children.each do |sub_item|
                add_sub_tree(sub_tree, sub_item)
              end
            end
          end
        end

        def item_options(item)
          {
            label: item.label,
            current: current?(item),
            tag: :a, # Todo: Check once implemented
            href: custom_field_item_path(@custom_field, @active_item) # Todo: Check once implemented
          }
        end

        def current?(item)
          item.id == @active_item.id
        end
      end
    end
  end
end
