locals {
  output_interfaces = {}
  output_attributes = {
    project_id = var.inputs.project.attributes.project_id
    role_member_pairs = [
      for grant in google_project_iam_member.this : {
        role   = grant.role
        member = grant.member
      }
    ]
  }
}
