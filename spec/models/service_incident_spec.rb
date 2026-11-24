require "rails_helper"

RSpec.describe ServiceIncident do
  describe ".overlapping" do
    let(:now) { Time.current }

    it "includes an incident ongoing at the time" do
      incident = create(:service_incident, started_at: now - 1.hour)

      expect(described_class.overlapping(now)).to eq([incident])
    end

    it "includes one we only noticed on the next poll" do
      incident = create(:service_incident, started_at: now + 3.minutes, resolved_at: now + 1.hour)

      expect(described_class.overlapping(now)).to eq([incident])
    end

    it "includes one resolved after the time" do
      incident = create(:service_incident, started_at: now - 1.hour, resolved_at: now + 1.minute)

      expect(described_class.overlapping(now)).to eq([incident])
    end

    it "leaves out incidents resolved before, or started well after" do
      create(:service_incident, started_at: now - 2.hours, resolved_at: now - 1.hour)
      create(:service_incident, component: "Actions", started_at: now + 1.hour)

      expect(described_class.overlapping(now)).to be_empty
    end
  end

  it "allows one open row per component" do
    create(:service_incident)

    expect { create(:service_incident) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
