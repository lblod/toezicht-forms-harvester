# coding: utf-8
require './google-sheets-client'
require 'pry-byebug'
class CodelistMerger
  def initialize()
    @client = GoogleSheetsClient.new()
  end

  MAPPING_TYPE_EENHEID = {
    "GEMEENTE" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/5ab0e9b8a3b2ca7c5e000001>",
    "DISTRICT" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/5ab0e9b8a3b2ca7c5e000003>",
    "PROVINCIE" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/5ab0e9b8a3b2ca7c5e000000>",
    "OCMW" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/5ab0e9b8a3b2ca7c5e000002>",
    "OCMWV" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/cc4e2d67-603b-4784-9b61-e50bac1ec089>",
    "AGB" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/36a82ba0-7ff1-4697-a9dd-2e94df73b721>",
    "APB" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/80310756-ce0a-4a1b-9b8e-7c01b6cc7a2d>",
    "DV" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/d01bb1f6-2439-4e33-9c25-1fc295de2e71>",
    "OV" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/cd93f147-3ece-4308-acab-5c5ada3ec63d>",
    "PV" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/b156b67f-c5f4-4584-9b30-4c090be02fdc>",
    "HVZ" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/ea446861-2c51-45fa-afd3-4e4a37b71562>",
    "PZ" => "<http://data.vlaanderen.be/id/concept/BestuurseenheidClassificatieCode/a3922c6d-425b-474f-9a02-ffb71a436bfc>"
  }

  def map_permission_column_to_triple(row)
    ttl = ""
    ['GEMEENTE', 'DISTRICT', 'OCMW', 'PROVINCIE', 'OCMWV', 'AGB', 'APB', 'IGS', 'HVZ', 'PZ', 'DV', 'OV', 'PV'].each do |key|
      if (row[key] and row[key].upcase == 'X')
        ttl +="\n"
        ttl += "\# #{key}"
        ttl +="\n"
        ttl +="<#{row["conceptschemeid"].strip}>  lblodBesluit:decidableBy #{MAPPING_TYPE_EENHEID[key]}."
      end
    end
    ttl
  end

  def run()
    file_id = '1qJ-fKIZn0Ku34UqY7wN-_3xYDskWyjo5Y7HKYTujiek'
    tab = "TYPEBESLUIT"
    rows = @client.get_spreadsheet_tab_values(file_id, tab)

    ttl = "@prefix lblodBesluit: <http://lblod.data.gift/vocabularies/besluit/> . \n"
    rows.each do |row|
      ttl +="\n"
      ttl +="\n"
      ttl +="\n"
      ttl +="\n"
      ttl += "\# #{row["CODE"]}"
      ttl += map_permission_column_to_triple(row)
    end
    puts ttl
    file_path = "decidable_by.ttl"
    File.open(file_path, 'w') { |file| file.write(ttl) }
  end
end

serializer = CodelistMerger.new()
serializer.run
