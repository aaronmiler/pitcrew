require "rails_helper"

RSpec.describe Advisory, type: :model do
  subject { build(:advisory) }

  it { is_expected.to validate_presence_of(:package_name) }
  it { is_expected.to validate_uniqueness_of(:source_id).scoped_to(:ecosystem, :package_name) }

  it "allows the same CVE on different packages" do
    create(:advisory, package_name: "actionpack", cve: "CVE-2026-1")

    expect(build(:advisory, package_name: "activesupport", cve: "CVE-2026-1")).to be_valid
  end

  it "rejects the same CVE twice on one package, even at the database level" do
    create(:advisory, package_name: "rack", cve: "CVE-2026-1", source_id: "CVE-2026-1")
    duplicate = build(:advisory, package_name: "rack", cve: "CVE-2026-1", source_id: "GHSA-aaaa")

    expect(duplicate).not_to be_valid
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "stores version requirements as arrays" do
    advisory = create(:advisory, patched_versions: ["~> 3.0.16", ">= 3.1.24"])

    expect(advisory.reload.patched_versions).to eq(["~> 3.0.16", ">= 3.1.24"])
  end

  describe "#identifier" do
    it "prefers the CVE, then the GHSA, then the source id" do
      expect(build(:advisory, cve: "CVE-1", ghsa: "GHSA-1").identifier).to eq("CVE-1")
      expect(build(:advisory, cve: nil, ghsa: "GHSA-1").identifier).to eq("GHSA-1")
      expect(build(:advisory, cve: nil, ghsa: nil, source_id: "OSVDB-1").identifier).to eq("OSVDB-1")
    end
  end
end
