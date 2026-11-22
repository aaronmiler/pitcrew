class AdvisoryDatesJob < ApplicationJob
  def perform(advisory_id)
    Github::AdvisoryDates.call(advisory: Advisory.find(advisory_id))
  end
end
