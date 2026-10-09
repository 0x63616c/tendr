# Exercise the real lane with recorded actions: no Apple access or signing changes.
ENV["ASC_BETA_FEEDBACK_EMAIL"] = "ci@example.invalid"
ENV["ASC_KEY_ID"] = "test-key"
ENV["ASC_ISSUER_ID"] = "test-issuer"
ENV["ASC_KEY_CONTENT"] = "test-only"
ENV.delete("ASC_KEY_PATH")
ENV["RUNNER_TEMP"] = File.expand_path("../build", __dir__)

module UI
  def self.user_error!(message)
    raise message
  end

  def self.important(*); end
  def self.message(*); end
  def self.success(*); end
end

class ReleaseCheck
  attr_reader :calls
  attr_accessor :fail_tests, :fail_provisioning

  def initialize
    @calls = []
    fastfile = File.expand_path("../fastlane/Fastfile", __dir__)
    instance_eval(File.read(fastfile), fastfile)
  end

  def default_platform(*); end
  def desc(*); end
  def platform(*)
    yield
  end
  def lane(name, &block)
    define_singleton_method(name, &block)
  end
  alias private_lane lane

  def sh(*args)
    @calls << [:sh, args]
    raise "test failure" if fail_tests
  end

  def app_store_connect_api_key(**args)
    args
  end

  def latest_testflight_build_number(**args)
    @calls << [:latest, args]
    17
  end

  def build_app(**args)
    @calls << [:build, args]
  end

  def get_provisioning_profile(**args)
    @calls << [:profile, args]
    raise "provisioning failure" if fail_provisioning
    "12345678-1234-1234-1234-123456789ABC"
  end

  def upload_to_testflight(**args)
    @calls << [:upload, args]
  end

  def deliver(**args)
    @calls << [:deliver, args]
  end
end

module Spaceship
  module ConnectAPI
    App = Struct.new(:id) do
      def self.find(bundle_id)
        new("app-for-#{bundle_id}")
      end
    end
  end
end

check = ReleaseCheck.new
ENV.delete("TENDR_PROFILE_UUID")
ENV.delete("GITHUB_ACTIONS")
check.beta({})
raise "release order" unless check.calls.map(&:first) == [:sh, :latest, :build, :upload]
build = check.calls.assoc(:build).last
raise "local signing changed" unless build[:export_xcargs] == "-allowProvisioningUpdates" && build[:export_options].empty?
raise "next build number" unless build[:xcargs].include?("CURRENT_PROJECT_VERSION=18")
upload = check.calls.assoc(:upload).last
raise "distribution" unless upload[:groups] == ["Owner Preview"] && upload[:skip_waiting_for_build_processing] == false && upload[:build_number] == "18"

check.calls.clear
ENV["GITHUB_ACTIONS"] = "true"
check.fail_provisioning = true
begin
  check.beta({})
  raise "ignored provisioning failure"
rescue RuntimeError => error
  raise unless error.message == "provisioning failure"
end
raise "uploaded without signing" if check.calls.assoc(:upload)

check.calls.clear
check.fail_provisioning = false
ENV["TENDR_PROFILE_UUID"] = "unusable-xcode-managed-profile"
check.beta({})
profile = check.calls.assoc(:profile).last
raise "wrong profile selection" unless profile[:provisioning_name] == "Tendr CI App Store" && profile[:ignore_profiles_with_different_name] && profile[:api_key][:key_id] == "test-key"
raise "release order" unless check.calls.map(&:first) == [:sh, :latest, :profile, :build, :upload]
profile_uuid = "12345678-1234-1234-1234-123456789ABC"
build = check.calls.assoc(:build).last
raise "CI archive signing" unless build[:xcargs].include?("CODE_SIGN_STYLE=Manual") && build[:xcargs].include?("PROVISIONING_PROFILE_SPECIFIER=#{profile_uuid}")
raise "CI export signing" unless build[:export_options][:provisioningProfiles] == { "com.calumwebb.still" => profile_uuid } && build[:export_xcargs].empty?

check.calls.clear
check.fail_tests = true
begin
  check.beta({})
  raise "ignored failing tests"
rescue RuntimeError => error
  raise unless error.message == "test failure"
end
raise "released after failing tests" unless check.calls.map(&:first) == [:sh]

# App Store listing: upload metadata, price, attach a build, and never submit.
check.calls.clear
check.define_singleton_method(:ensure_free_pricing) { |options| @calls << [:pricing, options] }
check.define_singleton_method(:attach_latest_build) { |options| @calls << [:attach, options] }
if Dir[File.expand_path("../fastlane/screenshots/en-US/*.png", __dir__)].empty?
  begin
    check.metadata({})
    raise "metadata ran without screenshots"
  rescue RuntimeError => error
    raise unless error.message.start_with?("No screenshots")
  end
  raise "uploaded without screenshots" if check.calls.assoc(:deliver)
end
check.calls.clear
check.metadata({ skip_screenshots: true, build: "42" })
raise "metadata order" unless check.calls.map(&:first) == [:deliver, :pricing, :attach]
listing = check.calls.assoc(:deliver).last
raise "metadata must never submit" unless listing[:submit_for_review] == false && listing[:skip_binary_upload] && listing[:force] && listing[:automatic_release] == false
raise "metadata version" unless listing[:app_version] == "1.0.0" && listing[:app_identifier] == "com.calumwebb.still"
raise "attach build" unless check.calls.assoc(:attach).last[:build] == "42" && check.calls.assoc(:attach).last[:version] == "1.0.0"

# Listing limits App Store Connect enforces.
metadata = File.expand_path("../fastlane/metadata", __dir__)
limits = { "name" => 30, "subtitle" => 30, "keywords" => 100, "promotional_text" => 170, "description" => 4000, "release_notes" => 4000 }
limits.each do |field, limit|
  text = File.read(File.join(metadata, "en-US", "#{field}.txt")).strip
  raise "#{field} is empty" if text.empty?
  raise "#{field} is #{text.length} characters (limit #{limit})" if text.length > limit
end
raise "keywords must be comma separated without spaces" if File.read(File.join(metadata, "en-US", "keywords.txt")).strip.match?(/,\s/)
listing_text = Dir[File.join(metadata, "**", "*.txt")].map { |path| File.read(path) }.join("\n")
banned = /ozempic|wegovy|mounjaro|zepbound|semaglutide|tirzepatide|glp-?1|dosage calculator|cure|treats? obesity/i
raise "listing mentions #{listing_text[banned]}" if listing_text.match?(banned)
%w[privacy_url support_url].each do |field|
  raise "#{field} must be https" unless File.read(File.join(metadata, "en-US", "#{field}.txt")).strip.start_with?("https://")
end
puts "Release checks passed (local signing, CI signing, next build, distribution, failure gates, App Store listing)."
