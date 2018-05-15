require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'


class GoogleSheetsClient
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  CLIENT_SECRETS_PATH = File.join('google_api_credentials' ,'client_secret.json')
  CREDENTIALS_PATH = File.join('google_api_credentials', "sheets.googleapis.com.yaml")
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

  def initialize
    credentials = authorize()
    # Initialize the API
    @service = Google::Apis::SheetsV4::SheetsService.new
    #service.client_options.application_name = APPLICATION_NAME
    @service.authorization = authorize
  end

  def authorize
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(
      client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(
        base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " +
           "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI)
    end
    credentials
  end

  def get_spreadsheet_tab_values(spreadsheet_id, tab_name)
    results = @service.get_spreadsheet_values(spreadsheet_id, tab_name)
    headers = results.values[0]
    hashed_list = []

    results.values[1..-1].each do |row|
      hashed_row = {}
      headers.each_with_index do |header, index|
        hashed_row[header.strip] = row[index]
      end
      hashed_list << hashed_row
    end
    hashed_list
  end
end
