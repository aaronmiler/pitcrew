module Github
  # One component on githubstatus.com (Github::Status), as a plain value. `incident_name`
  # and `incident_url` are set when an open incident lists the component.
  class ComponentStatus
    attr_reader :name, :status, :incident_name, :incident_url

    def initialize(name:, status:, incident_name: nil, incident_url: nil)
      @name = name
      @status = status
      @incident_name = incident_name
      @incident_url = incident_url
    end

    def operational?
      status == "operational"
    end
  end
end
