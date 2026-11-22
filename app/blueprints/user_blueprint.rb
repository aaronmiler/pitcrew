class UserBlueprint < Blueprinter::Base
  identifier :id
  fields :github_login, :name, :email, :access_via, :created_at
  field(:pending) { |user| user.pending? }
end
