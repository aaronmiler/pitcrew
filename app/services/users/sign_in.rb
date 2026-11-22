module Users
  # Decides whether a GitHub identity may sign in, and returns its User (or nil).
  #
  #   1. Known github_uid: decided by that record alone. Direct users pass; org users
  #      must still be in an allowed org.
  #   2. Pending invite for this login: claim it (bind the uid).
  #   3. PITCREW_INITIAL_USER, only while no users exist at all.
  #   4. Member of an allowed org: create an org user.
  # Otherwise nil. Logins are trusted only in steps 2 and 3, because a renamed login
  # can be claimed by someone else; from then on the uid is what counts.
  class SignIn < ApplicationService
    def call(uid:, login:, name: nil, email: nil)
      @uid = Integer(uid)
      @login = login.to_s.strip

      existing = User.find_by(github_uid: @uid)
      user = existing ? (existing if still_allowed?(existing)) : (claim_invite || bootstrap || org_member)
      user&.tap { refresh_profile(it, name:, email:) }
    end

    private

    def still_allowed?(user)
      user.via_direct? || member_of_allowed_org?
    end

    def claim_invite
      invite = User.pending.find_by_login(@login)
      invite&.tap { it.update!(github_uid: @uid) }
    end

    def bootstrap
      initial = ENV["PITCREW_INITIAL_USER"].to_s.strip
      return if initial.empty? || !initial.casecmp?(@login) || User.exists?

      User.create!(github_uid: @uid, github_login: @login, access_via: "direct")
    rescue ActiveRecord::RecordNotUnique
      nil # lost a bootstrap race; the winner already exists
    end

    def org_member
      return unless member_of_allowed_org?

      User.create!(github_uid: @uid, github_login: @login, access_via: "org")
    end

    def member_of_allowed_org?
      Setting.current.allowed_orgs.any? { |org| Github::OrgMember.call(org:, login: @login) }
    end

    # Keep login/name/email current. A login clash (e.g. a stale invite for the same
    # name) mustn't block sign-in, so this is best-effort.
    def refresh_profile(user, name:, email:)
      user.update(github_login: @login, name: name.presence || user.name, email: email.presence || user.email)
    end
  end
end
