# frozen_string_literal: true

# -- copyright
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
# ++

class WorkPackages::DatePickerController < ApplicationController
  include OpTurbo::ComponentStream

  ERROR_PRONE_ATTRIBUTES = %i[start_date
                              due_date
                              duration].freeze

  layout false

  before_action :find_work_package, except: %i[new create]
  authorization_checked! :show, :update, :edit, :new, :create

  attr_accessor :work_package

  def show
    set_date_attributes_to_work_package

    respond_to do |format|
      format.html do
        render :show,
               locals: { work_package:, schedule_manually:, params: params.merge(date_mode: date_mode).permit! },
               layout: false
      end

      format.turbo_stream do
        replace_via_turbo_stream(
          component: datepicker_modal_component
        )
        render turbo_stream: turbo_streams
      end
    end
  end

  def new
    make_fake_initial_work_package
    set_date_attributes_to_work_package

    respond_to do |format|
      format.turbo_stream do
        replace_via_turbo_stream(
          component: datepicker_modal_component
        )
        render turbo_stream: turbo_streams
      end
      format.html do
        render datepicker_modal_component, status: :ok
      end
    end
  end

  def edit
    set_date_attributes_to_work_package

    respond_to do |format|
      format.turbo_stream do
        replace_via_turbo_stream(
          component: datepicker_modal_component
        )
        render turbo_stream: turbo_streams
      end
      # TODO: preserve context for selecting start and end date on the datepicker.
      format.html do
        render :show,
               locals: { work_package:, schedule_manually:, params: params.merge(date_mode: date_mode).permit! },
               layout: false
      end
    end
  end

  def create
    make_fake_initial_work_package
    service_call = set_date_attributes_to_work_package

    if service_call.errors
                   .map(&:attribute)
                   .intersect?(ERROR_PRONE_ATTRIBUTES)
      respond_to do |format|
        format.turbo_stream do
          # Bundle 422 status code into stream response so
          # Angular has context as to the success or failure of
          # the request in order to fetch the new set of Work Package
          # attributes in the ancestry solely on success.
          render turbo_stream: [
            turbo_stream.morph("wp-datepicker-dialog--content", datepicker_modal_component)
          ], status: :unprocessable_entity
        end
      end
    else
      render json: {
        startDate: @work_package.start_date,
        dueDate: @work_package.due_date,
        duration: @work_package.duration,
        scheduleManually: @work_package.schedule_manually,
        includeNonWorkingDays: if @work_package.ignore_non_working_days.nil?
                                 false
                               else
                                 @work_package.ignore_non_working_days
                               end
      }
    end
  end

  def update
    service_call = WorkPackages::UpdateService
                     .new(user: current_user,
                          model: @work_package)
                     .call(work_package_datepicker_params)

    unless service_call.success?
      update_via_turbo_stream(
        component: datepicker_modal_component,
        method: "morph"
      )
    end

    # Bundle 422 status code into stream response so
    # Angular has context as to the success or failure of
    # the request in order to fetch the new set of Work Package
    # attributes in the ancestry solely on success.
    respond_to_with_turbo_streams(status: service_call.success? ? :ok : :unprocessable_entity)
  end

  private

  def datepicker_modal_component
    WorkPackages::DatePicker::DialogContentComponent.new(work_package: @work_package,
                                                         schedule_manually:,
                                                         focused_field:,
                                                         triggering_field: params[:triggering_field],
                                                         touched_field_map:,
                                                         date_mode:)
  end

  def focused_field
    return params[:focused_field] if params[:focused_field].present?

    trigger = params[:field]

    # Decide which field to focus next
    case trigger
    when "work_package[start_date]"
      handle_focus_order_for_fields(:start_date, :due_date)
    when "work_package[duration]"
      :duration
    when "work_package[due_date]"
      handle_focus_order_for_fields(:due_date, :start_date)
    else
      :start_date
    end
  end

  def find_work_package
    @work_package = WorkPackage.visible.find(params[:work_package_id])
  end

  def touched_field_map
    if params[:work_package]
      params.require(:work_package)
            .slice("schedule_manually_touched",
                   "ignore_non_working_days_touched",
                   "start_date_touched",
                   "due_date_touched",
                   "duration_touched")
            .transform_values { _1 == "true" }
            .permit!
    else
      {}
    end
  end

  def schedule_manually
    find_if_present(params[:schedule_manually]) ||
      find_if_present(params.dig(:work_package, :schedule_manually)) ||
      work_package.schedule_manually
  end

  def date_mode
    # Once in range mode, always in range mode
    return params[:date_mode] if params[:date_mode].present? && params[:date_mode] == "range"

    if work_package.start_date.nil? || work_package.due_date.nil?
      "single"
    else
      "range"
    end
  end

  def find_if_present(value)
    value.presence
  end

  def work_package_datepicker_params
    if params[:work_package]
      handle_milestone_dates
      handle_form_cleared

      params.require(:work_package)
            .slice(*allowed_touched_params)
            .merge(schedule_manually:, date_mode:, triggering_field: params[:triggering_field])
            .permit!
    end
  end

  def allowed_touched_params
    allowed_params.filter { touched?(_1) }
  end

  def allowed_params
    %i[schedule_manually ignore_non_working_days start_date due_date duration]
  end

  def touched?(field)
    touched_field_map[:"#{field}_touched"]
  end

  def make_fake_initial_work_package
    initial_params = params.require(:work_package)
                       .require(:initial)
                       .permit(:start_date, :due_date, :duration, :ignore_non_working_days)
    @work_package = WorkPackage.new(initial_params)
    @work_package.clear_changes_information
  end

  def set_date_attributes_to_work_package
    wp_params = work_package_datepicker_params
    if wp_params["schedule_manually"] == "false"
      wp_params = wp_params.without("start_date", "due_date")
    end

    if wp_params.present?
      WorkPackages::SetAttributesService
        .new(user: current_user,
             model: @work_package,
             contract_class: WorkPackages::CreateContract)
        .call(wp_params)
    end
  end

  def handle_milestone_dates
    if work_package.is_milestone?
      # Set the dueDate as the SetAttributesService will otherwise throw an error because the fields do not match
      params.require(:work_package)[:due_date] = params.require(:work_package)[:start_date]
      params.require(:work_package)[:due_date_touched] = "true"
    end
  end

  def handle_form_cleared
    touched_params = params.require(:work_package).slice(*allowed_touched_params)

    if two_fields_cleared?(touched_params)
      # If two fields are already manually cleared, we assume that the user wants to clear the whole form
      params_array = %i[start_date due_date duration]

      params_array.each do |param|
        if touched_params[param].nil?
          params.require(:work_package)[param] = ""
          params.require(:work_package)["#{param}_touched"] = "true"
        end
      end
    end
  end

  def two_fields_cleared?(wp_params)
    start_date = wp_params[:start_date]
    due_date = wp_params[:due_date]
    duration = wp_params[:duration]

    # Check which params are set to an empty string
    empty_params = [start_date, due_date, duration].select { |param| param == "" }
    # Check which param was not touched
    missing_param = [start_date, due_date, duration].select(&:nil?)

    # If two values are deleted and one is untouched, return tru
    empty_params.length == 2 && missing_param.length == 1
  end

  def handle_focus_order_for_fields(trigger_field, alternative_field)
    if !!params[:work_package][:"#{trigger_field}_touched"] && params[:work_package][:"#{trigger_field}"].blank?
      # Special case, when deleting a value: we want to keep the focus on that field instead of moving to the next field
      trigger_field
    else
      alternative_field
    end
  end
end
