require "rails_helper"

RSpec.describe "AdvisoryDb sync + import" do
  around { |example| Dir.mktmpdir("advisory-db") { |dir| @tmp = Pathname(dir); example.run } }

  let(:checkout) { @tmp.join("checkout") }

  def sync(origin)
    AdvisoryDb::Sync.call(path: checkout, url: origin.to_s)
  end

  describe AdvisoryDb::Sync do
    it "clones on the first run, then fast-forwards and reports both heads" do
      origin = build_advisory_origin(@tmp, only: ["gems/rack/CVE-2025-27610.yml"])

      first = sync(origin)
      expect(first[:before]).to be_nil
      expect(checkout.join("gems/rack/CVE-2025-27610.yml")).to exist

      add_advisory(origin, "gems/rack-session/CVE-2025-46336.yml")
      second = sync(origin)

      expect(second[:before]).to eq(first[:after])
      expect(second[:after]).not_to eq(first[:after])
      expect(checkout.join("gems/rack-session/CVE-2025-46336.yml")).to exist
    end
  end

  describe AdvisoryDb::Import do
    it "imports every gem advisory on the first run, normalizing ids" do
      origin = build_advisory_origin(@tmp)
      heads = sync(origin)

      AdvisoryDb::Import.call(path: checkout, **heads)

      rack = Advisory.find_by!(package_name: "rack", source_id: "CVE-2025-27610")
      expect(rack).to have_attributes(
        ecosystem: "rubygems",
        cve: "CVE-2025-27610",
        ghsa: "GHSA-7wqh-767x-r66v",
        criticality: "high",
        patched_versions: ["~> 2.2.13", "~> 3.0.14", ">= 3.1.12"],
        published_on: Date.new(2025, 3, 10)
      )
      expect(rack.source_committed_at).to be_within(1.minute).of(Time.current)
      expect(rack.first_seen_at).to be_present
      expect(Advisory.count).to eq(3)
    end

    it "imports only what changed between two heads, and returns the new ids" do
      origin = build_advisory_origin(@tmp, only: ["gems/rack/CVE-2025-27610.yml"])
      AdvisoryDb::Import.call(path: checkout, **sync(origin))

      add_advisory(origin, "gems/rack-session/CVE-2025-46336.yml")
      new_ids = AdvisoryDb::Import.call(path: checkout, **sync(origin))

      expect(Advisory.where(id: new_ids).pluck(:source_id)).to eq(["CVE-2025-46336"])
      expect(Advisory.count).to eq(2)
    end

    it "does nothing when the heads match" do
      origin = build_advisory_origin(@tmp)
      heads = sync(origin)

      expect(AdvisoryDb::Import.call(path: checkout, before: heads[:after], after: heads[:after])).to eq([])
      expect(Advisory.count).to eq(0)
    end

    it "is idempotent: re-importing keeps first_seen_at" do
      origin = build_advisory_origin(@tmp)
      heads = sync(origin)
      AdvisoryDb::Import.call(path: checkout, **heads)
      first_seen = Advisory.first.first_seen_at

      travel 1.day do
        expect(AdvisoryDb::Import.call(path: checkout, before: nil, after: heads[:after])).to eq([])
      end
      expect(Advisory.first.reload.first_seen_at).to eq(first_seen)
    end
  end
end
