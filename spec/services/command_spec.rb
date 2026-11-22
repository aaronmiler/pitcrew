require "rails_helper"

RSpec.describe Command do
  it "returns stripped stdout" do
    expect(described_class.run!("echo", "hello")).to eq("hello")
  end

  it "passes arguments without a shell" do
    expect(described_class.run!("echo", "$HOME; rm -rf /")).to eq("$HOME; rm -rf /")
  end

  it "raises with stderr, naming only the program and subcommand" do
    expect { described_class.run!("git", "nonsense-subcommand", "https://token@example.com") }
      .to raise_error(Command::Error, /\Agit nonsense-subcommand failed:/) { |e| expect(e.message).not_to include("token@") }
  end
end
