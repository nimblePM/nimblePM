class CreateProjectsStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :projects_statuses, id: false do |t|
      t.integer :project_id, null: false, default: 0
      t.integer :status_id, null: false, default: 0
    end

    add_index :projects_statuses, :project_id, name: :projects_statuses_project_id
    add_index :projects_statuses, %i[project_id status_id], name: :projects_statuses_unique, unique: true
  end
end
