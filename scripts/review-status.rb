# Read-only App Store Connect review status for Tendr. Prints greppable lines
# (STATUS:, REVIEW:, ITEM:, REJECTION:) and a Markdown table for the job summary.
# Usage: ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_CONTENT=… bundle exec ruby scripts/review-status.rb
require "spaceship"

APP_ID = "6809098849"

Spaceship::ConnectAPI.auth(key_id: ENV.fetch("ASC_KEY_ID"), issuer_id: ENV.fetch("ASC_ISSUER_ID"), key: ENV.fetch("ASC_KEY_CONTENT"))
asc = Spaceship::ConnectAPI.client.tunes_request_client

response = asc.get("v1/apps/#{APP_ID}/appStoreVersions", { "filter[platform]" => "IOS", "include" => "build", "limit" => 50 }).body
builds = (response["included"] || []).select { |item| item["type"] == "builds" }.to_h { |build| [build["id"], build.dig("attributes", "version")] }
versions = response["data"].map do |version|
  attributes = version["attributes"]
  {
    id: version["id"],
    version: attributes["versionString"],
    app_store_state: attributes["appStoreState"],
    app_version_state: attributes["appVersionState"],
    build: builds[version.dig("relationships", "build", "data", "id")] || "none",
    created: attributes["createdDate"]
  }
end.sort_by { |version| version[:created].to_s }.reverse

summary = ["## Tendr review status", "", "| Version | appVersionState | appStoreState | Build |", "| --- | --- | --- | --- |"]
versions.each do |version|
  state = version[:app_version_state] || version[:app_store_state]
  puts "STATUS: #{version[:version]} #{state} (appStoreState=#{version[:app_store_state]}, appVersionState=#{version[:app_version_state]}, build=#{version[:build]})"
  summary << "| #{version[:version]} | #{version[:app_version_state]} | #{version[:app_store_state]} | #{version[:build]} |"
end

rejected = versions.any? { |version| [version[:app_store_state], version[:app_version_state]].include?("REJECTED") }
begin
  submissions = asc.get("v1/reviewSubmissions", { "filter[app]" => APP_ID, "filter[platform]" => "IOS", "limit" => 20 }).body["data"]
  latest = submissions.max_by { |submission| submission.dig("attributes", "submittedDate").to_s }
  if latest
    attributes = latest["attributes"]
    puts "REVIEW: #{attributes['state']} (submitted #{attributes['submittedDate'] || 'not yet'}, submission #{latest['id']})"
    summary += ["", "**Latest review submission:** #{attributes['state']}, submitted #{attributes['submittedDate'] || 'not yet'}"]
    items = asc.get("v1/reviewSubmissions/#{latest['id']}/items", { "include" => "appStoreVersion", "limit" => 50 }).body["data"]
    items.each do |item|
      version_id = item.dig("relationships", "appStoreVersion", "data", "id")
      label = versions.find { |version| version[:id] == version_id }&.dig(:version) || version_id || "non-version item"
      puts "ITEM: #{label} #{item.dig('attributes', 'state')}"
      summary << "- #{label}: #{item.dig('attributes', 'state')}"
      rejected ||= item.dig("attributes", "state") == "REJECTED"
    end
    rejected ||= attributes["state"] == "UNRESOLVED_ISSUES"
  else
    puts "REVIEW: none (no review submissions yet)"
    summary += ["", "**Latest review submission:** none"]
  end
rescue StandardError => error
  puts "REVIEW: unavailable (#{error.message.lines.first&.strip})"
  summary += ["", "**Latest review submission:** unavailable (#{error.message.lines.first&.strip})"]
end

if rejected
  # The App Store Connect API does not expose App Review's message text.
  puts "REJECTION: App Review reported issues. The reason text is only in App Store Connect > App Review messages (not available through the API)."
  summary += ["", "**Rejection:** see App Store Connect > App Review messages; the API does not expose the reason text."]
end

File.write(ENV["GITHUB_STEP_SUMMARY"], summary.join("\n") + "\n", mode: "a") if ENV["GITHUB_STEP_SUMMARY"]
