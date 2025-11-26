require 'fileutils'
require 'json'
require 'progress_bar'
require 'open3'
require 'byebug'
require 'optparse'
require 'terminal-table'
require_relative 'query.rb'


options = {}
# Load environment defaults
options[:source_client_id]  = ENV["SOURCE_CLIENT_ID"]
options[:source_secret]     = ENV["SOURCE_SECRET"]
options[:source_auth_url]   = ENV["SOURCE_AUTH_URL"]
options[:source_api_url]    = ENV["SOURCE_API_URL"]
options[:target_client_id]  = ENV["TARGET_CLIENT_ID"]
options[:target_secret]     = ENV["TARGET_SECRET"]
options[:target_auth_url]   = ENV["TARGET_AUTH_URL"]
options[:target_api_url]    = ENV["TARGET_API_URL"]


OptionParser.new do |opts|
  opts.banner = "Usage: framework.rb [options]"

  opts.on("--framework FRAMEWORK", String) do |v|
    options[:original_framework] = v
  end

  opts.on("--source-client-id ID", String, "Source API client id") do |v|
    options[:source_client_id] = v
  end unless ENV["SOURCE_CLIENT_ID"]

  opts.on("--source-secret SECRET", String, "Source API secret") do |v|
    options[:source_secret] = v
  end unless ENV["SOURCE_SECRET"]

  opts.on("--source-auth-url URL", String) { |v| options[:source_auth_url] = v }
  opts.on("--source-api-url URL", String)  { |v| options[:source_api_url]  = v }

  opts.on("--target-client-id ID", String) do |v|
    options[:target_client_id] = v
  end unless ENV["TARGET_CLIENT_ID"]

  opts.on("--target-secret SECRET", String) do |v|
    options[:target_secret] = v
  end unless ENV["TARGET_SECRET"]

  opts.on("--target-auth-url URL", String) { |v| options[:target_auth_url] = v }
  opts.on("--target-api-url URL", String)  { |v| options[:target_api_url]  = v }

  opts.on("--action [export import copy]", String) { |v| options[:action] = v.downcase.to_sym }
  opts.on("-v", "--verbose") { |v| options[:verbose] = v }
end.parse!

VERBOSE = options[:verbose]
ORIGINAL_FRAMEWORK = options[:original_framework]

required_params = [
  :original_framework,
  :action
]
required_params = required_params + [
  :source_client_id,
  :source_secret,
  :source_auth_url,
  :source_api_url
] if [:export, :copy].include?(options[:action])
required_params = required_params + [
  :target_client_id,
  :target_secret,
  :target_auth_url,
  :target_api_url,
] if [:import, :copy].include?(options[:action])

missing = required_params.select { |k| options[k].nil? }
unless missing.empty?
  puts "Missing required options: #{missing.map { |m| "--#{m.to_s.gsub('_','-')}" }.join(', ')}"
  exit 1
end

if [:export, :copy].include?(options[:action])
  base = File.join("frameworks", options[:original_framework])
  %w[. controls host_config_rules cloud_config_rules].each do |sub|
    path = (sub == '.') ? base : File.join(base, sub)
    FileUtils.mkdir_p(path)
  end
end

if !Dir.exist?("frameworks/#{options[:original_framework]}") && [:import, :copy].include?(options[:action])
  puts "Framework Missing, please run export first, or run copy"
  exit 1
end

# Script Functions below
# This method uses a standard method of calling CURL. It also correctly encapsulates quotes when passing to shell
# TODO: update all inline curl requests to use this method.
def exec_curl(url, api_token=nil, body=nil)
  headers = ["-H", "Content-Type: application/json"]
  headers += ["-H", "Authorization: Bearer #{api_token}"] if !api_token.nil?
  body_args = ["-d", body] if !body.nil?

  args = [
    "curl",
    "-s",
    "-X", "POST",
    url,
    *headers,
    *body_args
  ]

  stdout, stderr, status = Open3.capture3(*args)
  stdout
end

def get_api_token(auth_url, client_id, client_secret)
  JSON.parse(`curl -sS -X POST '#{auth_url}' \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "encoding: UTF-8" \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode 'client_id=#{client_id}' \
  --data-urlencode 'client_secret=#{client_secret}' \
  --data-urlencode 'audience=wiz-api'`)['access_token']
end

def write_audit_log(message, file_path = "audit.log")
  timestamp = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
  safe_message = message.to_s.gsub(/[\r\n]+/, " ")
  File.open(file_path, "a") do |file|
    file.puts("[#{timestamp}] #{safe_message}")
    puts "[#{timestamp}] #{safe_message}" if VERBOSE
  end
rescue => e
  warn "Audit log write failed: #{e.message}"
end

def count_files(directory_path)
  Dir.entries(directory_path).count { |entry| File.file?(File.join(directory_path, entry)) && !entry.start_with?('.') }
end

def get_host_config_rule(api_token, api_url, id)
  return if File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{id}")
  retry_count = 0
  while !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{id}")
    break if retry_count >=5
    sleep(2) if retry_count > 0
    retry_count = retry_count + 1
    `curl -sS -X POST #{api_url} \
    -o "frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{id}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer #{api_token}" \
    -d '{
    "variables": {"id":"#{id}"},
    "query": "query LoadHostConfigRuleForEditing($id: ID!) { hostConfigurationRule(id: $id) { ...HostConfigurationRuleDetailsFragment directOVAL }} fragment HostConfigurationRuleDetailsFragment on HostConfigurationRule { id externalId name description enabled builtin shortName hasMissingPrerequisite prerequisite matchers { ...HostConfigurationRuleMatchersFragment } targetOperatingSystems { id version displayName technology { id name icon description } } targetWorkloadTypes targetTechnologies { id version displayName technology { id name icon description } } excludedTechnologies { id version displayName technology { id name icon description } } tags { key value } severity securitySubCategories { ...SecuritySubCategoriesDetails } remediationInstructions analytics { errorCount failCount notAssessedCount passCount totalCount } projects { id name }} fragment HostConfigurationRuleMatchersFragment on HostConfigurationRuleMatchers { workloadScanner { enabled description ovalDefinition } dynamicScanner { enabled description nucleiTemplate }} fragment SecuritySubCategoriesDetails on SecuritySubCategory { description id resolutionRecommendation title category { id name framework { id name enabled } }}" }'`
  end
  if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{id}")
    write_audit_log("Unable to retrieve host config rule #{id}") 
    exit 1
  end
end

def get_cloud_config_rule(api_token, api_url, id)
  return if File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{id}")
  retry_count = 0
  while !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{id}")
    break if retry_count >=5
    sleep(2) if retry_count > 0
    retry_count = retry_count + 1
     `curl -sS -X POST #{api_url} \
      -o "frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{id}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer #{api_token}" \
      -d '{
        "variables": {"id":"#{id}"},
        "query": "query LoadCloudConfigRuleForEditing($id: ID!) { cloudConfigurationRule(id: $id) { id name description enabled opaPolicy targetNativeTypes functionAsControl builtin originalConfigurationRule { id name remediationInstructions severity description iacMatchers { id remediationInstructions } } scopeAccounts { id } scopeProject { id } securitySubCategories { id } remediationInstructions severity matcherTypes iacMatchers { id type regoCode remediationInstructions builtinId parameters { ... on CloudConfigurationRuleAdmissionControllerMatcherParameters { operation } } } tags { key value } }}" }'`
  end

   if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{id}")
    write_audit_log("Unable to retrieve cloud config rule #{id}") 
    exit 1
  end
end

def get_graph_control_rule(api_token, api_url, id)
  return if File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{id}")
  retry_count = 0
  while !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{id}")
    break if retry_count >=5
    sleep(2) if retry_count > 0
    retry_count = retry_count + 1
    `curl -sS -X POST #{api_url} \
      -o "frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{id}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer #{api_token}" \
      -d '{
    "variables": {"id":"#{id}"},
    "query": "query LoadControlForEditing($id: ID!) { control(id: $id) { originalControl { id name resolutionRecommendation severity description } id name description securitySubCategories { id } resolutionRecommendation severity query createdBy { id } scopeQuery scopeProject { id name } tagsV2 { key value } }}" }'`
  end

 if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{id}")
    write_audit_log("Unable to retrieve graph control rule #{id}") 
    exit 1
  end
end

def enable_control(api_token, api_url, id)
  payload = {
    variables: {
      controlId: id,
      patch: { enabled: true }
    },
    query: TOGGLE_CONTROL_MUTATION
  }.to_json
  exec_curl(api_url, api_token, payload)
end

# This function takes a Graph Control referenced by the source framework definition, then searches the target tenant for whether a graph control rule with the same name exists or not
# If it exists, we don't create it again. Possibly better to check against the definition itself, but this works for now. The ID of the Graph Control is returned to be added to the new
# framework definition.
def sync_graph_control(control_node, options, existing_mappings)
   if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{control_node['id']}")
     write_audit_log("Retrying to download Graph Control \"#{control_node['id']}\".")
     get_graph_control_rule(options[:source_api_token], options[:source_api_url], control_node['id']) #we shouldn't need this, but apparently some of the controls are not referenced in the top level compliance summary
     return nil if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{control_node['id']}")
  end

  # If we have an existing mapping, then let's use that, rather than making unnecessary calls
  mapped_gcr = existing_mappings[:gcr][control_node['id']]
  write_audit_log("Using existing graph control mapping for #{control_node['id']}") if !mapped_gcr.nil?
  return mapped_gcr[:to] unless mapped_gcr.nil?

  control_to_check = JSON.parse(File.read("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{control_node['id']}"))
  created_by = control_node['id'].start_with?('wc-') ? ["BUILT_IN"] : ["USER"]
  variables = {
    first: 30,
    orderBy: {
      field: "SEVERITY",
      direction: "DESC"
    },
    filterBy: {
      search: control_to_check["data"]["control"]["name"],
    createdBy: created_by
    }
  }
  body = {
    variables: variables,
    query: MANAGE_CONTROLS_QUERY
  }.to_json
  control_check = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], body))

  if control_check['data']['controls']['totalCount'] == 0 && !control_node['id'].start_with?('wc-') 
    # There's no control with this name. Yeah it's not ideal, we could look to validate rules based on the rule definition itself, maybe in future
    write_audit_log("Creating control \"#{control_to_check['data']['control']['name']}\"")
    new_control = {"input":{"description":control_to_check['data']['control']['description'],"name":control_to_check['data']['control']['name'],"query":control_to_check['data']['control']['query'],"severity":control_to_check['data']['control']['severity'],"resolutionRecommendation":control_to_check['data']['control']['resolutionRecommendation'],"scopeQuery":control_to_check['data']['control']['scopeQuery'],"projectId":"*","tags":control_to_check['data']['control']['tagsV2']}}

    body = {variables: new_control,query: CREATE_CONTROL_MUTATION}.to_json

    created_control = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], body))
    return created_control['data']['createControl']['control']['id']

  else # We should only get here if we're running this multiple times and not cleaning up, or the same control is referenced in multiple subcategories.
    write_audit_log("Skipping creation of control \"#{control_to_check['data']['control']['name']}\" as it already exists at the target")
     return control_check['data']['controls']['nodes'][0]['id']
  end
end

def enable_host_config_rule(api_token, api_url, id)
  payload = {
    variables: {
      id: id,
      enabled: true
    },
    query: UPDATE_HOST_CONFIG_RULE_MUTATION
  }.to_json
  exec_curl(api_url, api_token, payload)
end

# This function takes a control_node referenced by the source framework definition, then searches the short name to find the matching 
# Host Config Rule in the target tenant. The HCR ID is unique per tenant, but we can match on the externalId GUID, which is the method used.
# The ID of the host configuration rule is returned to be added to the new framework definition.
def sync_host_config_rule(control_node, options, existing_mappings)
  if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{control_node['id']}")
    write_audit_log("Retrying to download Host Config Rule \"#{control_node['id']}\".")
     get_host_config_rule(options[:source_api_token], options[:source_api_url], control_node['id']) #we shouldn't need this, but apparently some of the controls are not referenced in the top level compliance summary
     return nil if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{control_node['id']}")
  end

  # If we have an existing mapping, then let's use that, rather than making unnecessary calls
  mapped_hcr = existing_mappings[:hcr][control_node['id']]
  write_audit_log("Using existing host config rule mapping for #{control_node['id']} : #{mapped_hcr[:to]}") if !mapped_hcr.nil?
  return mapped_hcr[:to] unless mapped_hcr.nil?

  control_to_check = JSON.parse(File.read("frameworks/#{ORIGINAL_FRAMEWORK}/host_config_rules/#{control_node['id']}"))  

  variables = {
    first: 40,
    filterBy: {
      search: control_to_check['data']['hostConfigurationRule']['shortName'],
      targetWorkloadTypes: {}
    },
    orderBy: {
      field: "FAILED_CHECK_COUNT",
      direction: "DESC"
    }
  }

  body = {variables: variables, query: HOST_CONFIGURATION_QUERY}.to_json
  controls_search = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], body))
    write_audit_log("Source Host Config Rule ID #{control_node['id']} mapped to #{controls_search['data']['hostConfigurationRules']['nodes'].select{|n| n['externalId'] == control_to_check['data']['hostConfigurationRule']['externalId']}[0]['id']}, / #{controls_search['data']['hostConfigurationRules']['nodes'].select{|n| n['externalId'] == control_to_check['data']['hostConfigurationRule']['externalId']}[0]['shortName']}")
  return controls_search['data']['hostConfigurationRules']['nodes'].select{|n| n['externalId'] == control_to_check['data']['hostConfigurationRule']['externalId']}[0]['id']
end


def enable_cloud_config_rule(api_token, api_url, id)
  payload = {
    variables: {
      ruleId: id,
      patch: { enabled: true },
      override: nil
    },
    query: UPDATE_CLOUD_CONFIG_RULE_MUTATION
  }.to_json

  exec_curl(api_url, api_token, payload)
end


# This function takes a control_node referenced by the source framework definition, then searches the short name to find the matching 
# Cloud Config Rule in the target tenant. The CCR ID is unique per tenant, but we can match on the externalId GUID, which is the method used.
# The ID of the cloud configuration rule is returned to be added to the new framework definition.
def sync_cloud_config_rule(control_node, options, existing_mappings)
  if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{control_node['id']}")
    write_audit_log("Retrying to download Cloud Config Rule \"#{control_node['id']}\".")
    get_cloud_config_rule(options[:source_api_token], options[:source_api_url], control_node['id'])  #we shouldn't need this, but apparently some of the controls are not referenced in the top level compliance summary
     return nil if !File.exist?("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{control_node['id']}")
  end

  # If we have an existing mapping, then let's use that, rather than making unnecessary calls
  mapped_ccr = existing_mappings[:ccr][control_node['id']]
  write_audit_log("Using existing cloud config rule mapping for #{control_node['id']} : #{mapped_ccr[:to]}") if !mapped_ccr.nil?
  return mapped_ccr[:to] unless mapped_ccr.nil?

  control_to_check = JSON.parse(File.read("frameworks/#{ORIGINAL_FRAMEWORK}/cloud_config_rules/#{control_node['id']}"))  

  variables = {
  first: 80,
  filterBy: {
    search: control_to_check['data']['cloudConfigurationRule']['name']
  },
  orderBy: {
    field: "FAILED_CHECK_COUNT",
    direction: "DESC"
  }}

  body = {
    variables: variables,
    query: CLOUD_CONFIG_QUERY
  }.to_json

  controls_search = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], body))
  write_audit_log("Source Cloud Config Rule ID #{control_node['id']} mapped to #{controls_search['data']['cloudConfigurationRules']['nodes'].select{|n| n['name'] == control_to_check['data']['cloudConfigurationRule']['name']}[0]['id']}, / #{controls_search['data']['cloudConfigurationRules']['nodes'].select{|n| n['name'] == control_to_check['data']['cloudConfigurationRule']['name']}[0]['shortId']} / #{controls_search['data']['cloudConfigurationRules']['nodes'].select{|n| n['name'] == control_to_check['data']['cloudConfigurationRule']['name']}[0]['name']}")
  return controls_search['data']['cloudConfigurationRules']['nodes'].select{|n| n['name'] == control_to_check['data']['cloudConfigurationRule']['name']}[0]['id']
end

options[:source_api_token] = get_api_token(options[:source_auth_url],options[:source_client_id], options[:source_secret])
options[:target_api_token] = get_api_token(options[:target_auth_url],options[:target_client_id], options[:target_secret])

# Get the original framework from the source that we'll recreate on the target
write_audit_log("Retriving original framework")
payload = {variables: { id: options[:original_framework] },query: LOAD_SECURITY_FRAMEWORK_QUERY}.to_json
original_framework = JSON.parse(exec_curl(options[:source_api_url], options[:source_api_token], payload))

# Export all the controls, host config and cloud config rules (don't need the built-in ones, but we will check, and ensure the names match, or create them later if required)
if [:export, :copy].include?(options[:action])
  write_audit_log("Retrieving Source Graph Controls")
  bar = ProgressBar.new(original_framework['data']['securityFramework']['controls']['nodes'].count, :bar, :rate, :eta) unless VERBOSE
  original_framework['data']['securityFramework']['controls']['nodes'].each do |control|
    write_audit_log("Retriving graph control #{control['id']}")
    get_graph_control_rule(options[:source_api_token], options[:source_api_url], control['id'])
    bar.increment! unless VERBOSE
  end

  write_audit_log("Retrieving Source Cloud Config Rules")
  bar = ProgressBar.new(original_framework['data']['securityFramework']['cloudConfigurationRules']['nodes'].count, :bar, :rate, :eta) unless VERBOSE
  original_framework['data']['securityFramework']['cloudConfigurationRules']['nodes'].each do |cloud_control|
    write_audit_log("Retriving cloud config rule #{cloud_control['id']}")
    get_cloud_config_rule(options[:source_api_token],options[:source_api_url], cloud_control['id'])
    bar.increment! unless VERBOSE
  end

  write_audit_log("Retrieving Source Host Config Rules")
  bar = ProgressBar.new(original_framework['data']['securityFramework']['hostConfigurationRules']['nodes'].count, :bar, :rate, :eta) unless VERBOSE
  original_framework['data']['securityFramework']['hostConfigurationRules']['nodes'].each do |host_control|
    write_audit_log("Retriving host config rule #{host_control['id']}")
    get_host_config_rule(options[:source_api_token],options[:source_api_url], host_control['id'])
    bar.increment! unless VERBOSE
  end
end

if [:import, :copy].include?(options[:action])
  mappings = {gcr:{}, ccr:{}, hcr: {}}
  new_categories = [] 
  bar = ProgressBar.new(original_framework['data']['securityFramework']['categories'].count, :bar, :rate, :eta) unless VERBOSE
  original_framework['data']['securityFramework']['categories'].each do |category|
    new_category = {"id":nil,"name":category['name'],"description":category['description'],"subCategories":[]}

    category['subCategories'].each do |sub_category|
      write_audit_log("Evaluating #{category['name']} - #{sub_category['title']}")
      graph_controls_to_add = []
      cloud_controls_to_add = []
      host_controls_to_add = []

      # Lets check graph controls
    
      sub_category['controls']['nodes'].each do |control_node|
        if control_node['id'].start_with?('wc') 
          graph_controls_to_add << control_node['id']
          mappings[:gcr][control_node['id']] = {to: control_node['id']}
          enable_control(options[:target_api_token], options[:target_api_url], control_node['id'])
        else # If we have any controls which are custom (not starting with 'wc') then we need to add them 
          gcr_to_sync = sync_graph_control(control_node, options, mappings)
          mappings[:gcr][control_node['id']] = {to: gcr_to_sync}
          graph_controls_to_add << gcr_to_sync unless gcr_to_sync.nil?
          enable_control(options[:target_api_token], options[:target_api_url], gcr_to_sync)
        end
      end

      # Let's check Host Config Rules
      sub_category['hostConfigurationRules']['nodes'].each do |control_node|
        mapped_config_rule = sync_host_config_rule(control_node, options, mappings) 
        mappings[:hcr][control_node['id']] = {to: mapped_config_rule} unless mapped_config_rule.nil?
        host_controls_to_add << mapped_config_rule unless mapped_config_rule.nil?
        enable_host_config_rule(options[:target_api_token], options[:target_api_url], mapped_config_rule)
      end

      # Let's check Cloud Config Rules
      sub_category['cloudConfigurationRules']['nodes'].each do |control_node|
        mapped_config_rule = sync_cloud_config_rule(control_node, options, mappings) 
        mappings[:ccr][control_node['id']] = {to: mapped_config_rule} unless mapped_config_rule.nil?
        cloud_controls_to_add << mapped_config_rule unless mapped_config_rule.nil?
        enable_cloud_config_rule(options[:target_api_token], options[:target_api_url], mapped_config_rule)
      end

      new_category[:subCategories] << {"id":nil,"title":sub_category['title'],"description":sub_category['description'],"controls":graph_controls_to_add,"cloudConfigurationRules":cloud_controls_to_add,"hostConfigurationRules":host_controls_to_add,"tags":[]}
    end
    new_categories << new_category
    bar.increment! unless VERBOSE
  end


  new_framework = {"input":{"name":original_framework['data']['securityFramework']['name'],"description":original_framework['data']['securityFramework']['description'],"categories":new_categories}}

  payload = {variables: new_framework,query: CREATE_SECURITY_FRAMEWORK_MUTATION}.to_json
  new_framework_id = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], payload))['data']['createSecurityFramework']['framework']['id']
  sleep(10) # Wait for the backend to register the new object
  payload = {variables: { id: new_framework_id },query: LOAD_SECURITY_FRAMEWORK_QUERY}.to_json
  created_framework = JSON.parse(exec_curl(options[:target_api_url], options[:target_api_token], payload))
  
  # This is now where we need to add a re-push of the policy because in some tenants some controls will not be added (seems to be a sync issue)
  categories_to_patch = []  
  created_framework['data']['securityFramework']['categories'].each do |category|
  sub_categories_to_patch = []
  category['subCategories'].each do |sub_category|
      sub_categories_to_patch <<  {
        id: sub_category['id'],
        title: sub_category['title'],
        description: sub_category['description'],
        tags: [],
        controls: sub_category['controls']['nodes'] = (new_framework[:input][:categories].select{|cat| cat[:name] == category['name']}[0][:subCategories].select{|sub_cat| sub_cat[:title] == sub_category['title']}[0][:controls]),
        cloudConfigurationRules: (new_framework[:input][:categories].select{|cat| cat[:name] == category['name']}[0][:subCategories].select{|sub_cat| sub_cat[:title] == sub_category['title']}[0][:cloudConfigurationRules]),
        hostConfigurationRules: (new_framework[:input][:categories].select{|cat| cat[:name] == category['name']}[0][:subCategories].select{|sub_cat| sub_cat[:title] == sub_category['title']}[0][:hostConfigurationRules])
      }
    end
    categories_to_patch << {id: category['id'], name: category['name'],  description: "", subCategories: sub_categories_to_patch}
  end

  to_update = {id: new_framework_id, patch: {categories: categories_to_patch}, patchOptions: {unassignPoliciesOnAllEmptySubCategories: true}}
  payload = {variables: { input: to_update }, query: UPDATE_SECURITY_FRAMEWORK_MUTATION}.to_json
  exec_curl(options[:target_api_url], options[:target_api_token], payload)


  write_audit_log("Validating New Framework")

  (original_framework['data']['securityFramework']['controls']['nodes'] - created_framework['data']['securityFramework']['controls']['nodes']).select{|gc| gc['id'].start_with?('wc')}.each do |not_copied|
    write_audit_log("Graph Control \"#{JSON.parse(File.read("frameworks/#{ORIGINAL_FRAMEWORK}/controls/#{not_copied['id']}"))['data']['control']['originalControl']['name']}\" not copied to target, please check.")
  end
end

write_audit_log("Script Execution Complete - Framework #{options[:action]} success!")
