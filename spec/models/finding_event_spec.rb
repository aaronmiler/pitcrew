require "rails_helper"

RSpec.describe FindingEvent, type: :model do
  it { is_expected.to belong_to(:finding) }

  it "can't be changed once written" do
    event = create(:finding_event)

    expect { event.update!(kind: "resolved") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "defaults metadata to an empty hash" do
    expect(create(:finding_event).metadata).to eq({})
  end
end
