require 'spec_helper'

RSpec.describe 'Project status association' do
  let!(:project) { create(:project) }
  let!(:status1) { create(:status) }
  let!(:status2) { create(:status) }

  it 'links statuses to projects' do
    project.allowed_statuses << status1
    expect(project.allowed_statuses).to include(status1)
    expect(project.allowed_statuses).not_to include(status2)
  end

  it 'filters workflow available statuses' do
    role = create(:project_role)
    user = create(:user)
    create(:member, project: project, principal: user, roles: [role])
    type = project.types.first

    create(:workflow, old_status: status1, new_status: status2, role:, type:)

    project.allowed_statuses << status2

    expect(Workflow.available_statuses(project, user)).to include(status2)

    project.allowed_statuses.delete(status2)
    expect(Workflow.available_statuses(project, user)).not_to include(status2)
  end
end
