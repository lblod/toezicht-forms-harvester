require './google-sheets-client'
require './lib/form-data'
require 'pry-byebug'
require 'linkeddata'
require 'bson'
require 'digest'
require 'fileutils'
require 'digest/md5'

class FormSerializer
  FOAF = RDF::Vocab::FOAF
  DC = RDF::Vocab::DC
  RDFS = RDF::Vocab::RDFS
  ADMS = RDF::Vocabulary.new("http://www.w3.org/ns/adms#")
  MU = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/core/")
  EXT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/")
  SKOS = RDF::Vocab::SKOS
  TOEZICHT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/supervision/")

  BASE_URI = 'http://data.lblod.info/%{resource}/%{id}'

  def initialize(output_folder)
    @google_client = GoogleSheetsClient.new()
    @form_data = FormData.new(@google_client)
    @graph = RDF::Graph.new
    @output_folder = output_folder
  end

  def load_form_data
    @entity_uris = @form_data.entity_uris
    @code_lists = @form_data.code_lists
    @form_inputs = @form_data.form_inputs
    @subforms = @form_data.dynamic_subforms
    @forms = @form_data.form_nodes
  end

  def serialize
    load_form_data
    entities_map = create_entities
    code_lists_map = create_code_lists(entities_map)
    write_ttl_to_file(@output_folder, 'toezicht-code-lists', @graph)
    @graph = RDF::Graph.new
    form_inputs_map = create_form_inputs
    forms_map =  create_forms(form_inputs_map)
    dynamic_subforms_map = create_dynamic_subforms(form_inputs_map, forms_map, code_lists_map)
    write_ttl_to_file(@output_folder, 'toezicht-forms', @graph)
  end

  def create_entities
    entities_map = {}
    @entity_uris.each do |row|
      key = row['LABEL']
      uri = row['URI']
      entities_map[key] = uri
    end
    entities_map
  end

  def create_input_state()
    salt = "0e1a2708-39fb-4218-b2c7-0436886e4053"
    validation_name = "empty"
    state_name = "noSend"
    uuid = hash(salt + ":" + validation_name + ":" + state_name)

    subject = RDF::URI(BASE_URI % {:resource => "input-states", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT["InputState"])
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, EXT["validationName"], validation_name)
    @graph << RDF.Statement(subject, EXT["stateName"], state_name)

    subject
  end

  def create_code_lists(entities_map)
    code_lists_map = {}
    @code_lists.each do |row|
      code_lists_map.merge!(create_code_list(entities_map, row))
    end
    code_lists_map
  end

  def create_code_list(entities_map, row)
    salt = "ded56bf0-9df7-44d6-8686-7f0dfa5fbfaa"
    uuid = hash(salt + ":" + row["TYPE"] + ":" +row["CODE"])
    subject =  RDF::URI(BASE_URI % {:resource => row["TYPE"], :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, TOEZICHT[row["TYPE"]])

    if row["TYPE"] == "Nomenclature"
          @graph << RDF.Statement(subject, TOEZICHT["nomeclatureCode"], row["CODE"])
    end
    if row["TYPE"] == "DecisionType"
      ['GEMEENTE', 'DISTRICT', 'OCMW', 'PROVINCIE', 'OCMWV', 'AGB', 'APB', 'IGS', 'HVZ', 'PZ'].each do |key|
        @graph << RDF.Statement(subject, EXT.decidableBy, RDF::URI(entities_map[key])) if (row[key] and row[key].upcase == 'X')
      end
    end
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, SKOS.prefLabel, row["OMSCHRIJVINGKORT"])

    { row["ID"] => {"URI" => subject, "UUID" => uuid } }
  end

  def create_form_inputs
    form_inputs_map = {}
    @form_inputs.each do |row|
      form_inputs_map.merge!(create_form_input(row))
    end
    form_inputs_map
  end

  def create_form_input(row)
    salt = "3aa85ccd-e17b-4a47-b9c6-19ab06efa682"
    uuid = hash(salt + ":" + row["ID"])
    subject =  RDF::URI(BASE_URI % {:resource => "form-inputs", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT.FormInput)
    @graph << RDF.Statement(subject, EXT["index"], row["INDEX"])
    @graph << RDF.Statement(subject, EXT["displayType"], row["DISPLAY-TYPE"])
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, DC.title, row["TITLE"])

    if row["OPTIONS"]
      @graph << RDF.Statement(subject, EXT.string , row["OPTIONS"])
    end

    @graph << RDF.Statement(subject, ADMS.identifier, row["IDENTIFIER"])

    { row["ID"] => subject }
  end

  def create_dynamic_subforms(form_inputs_map, forms_map, code_lists_map)
    dynamic_subforms_map = {}
    @subforms.each do |row|
      dynamic_subforms_map.merge!(create_dynamic_subform(form_inputs_map, forms_map, code_lists_map, row))
    end
    dynamic_subforms_map
  end

  def create_dynamic_subform(form_inputs_map, forms_map, code_lists_map, row)
    salt = "b86cebbe-aff5-4bc9-b290-fd0b63e5f60c"
    uuid = hash(salt + ":" + row["ID"])
    subject =  RDF::URI(BASE_URI % {:resource => "dynamic-subforms", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT.DynamicSubform)
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, EXT["matchKind"], row["MATCH-KIND"])
    @graph << RDF.Statement(subject, EXT["key"], row["KEY"])

    if row["MATCH-KIND"] == "uuid"
      @graph << RDF.Statement(subject, EXT["value"], code_lists_map[row["CODE-LIST-ID"]]["UUID"])
    else
      raise "sorry we don't support other match kinds, during import"
    end

    @graph << RDF.Statement(form_inputs_map[row["INPUT-ID"]], EXT["dynamicSubforms"], subject)

    if not forms_map[row["FORM"]]
      binding.pry
    end

    @graph << RDF.Statement(subject, EXT["hasFormNode"], forms_map[row["FORM"]])

    { row["ID"] => subject }
  end

  def create_forms(form_inputs_map)
    forms_map = {}
    @forms.each do |row|
      forms_map.merge!(create_form(form_inputs_map, row))
    end
    forms_map
  end

  def create_form(form_inputs_map, row)
    salt = "346761e7-be8e-43dc-815e-e9321d8b01b5"
    uuid = hash(salt + ":" + row["ID"].to_s)
    subject =  RDF::URI(BASE_URI % {:resource => "form-nodes", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT.FormNode)
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, EXT["typeMap"], row["TYPE-MAP"])

    row["INPUT-IDS"].each do |id|
       @graph << RDF.Statement(subject, EXT["formInput"], form_inputs_map[id])
    end

    { row["ID"] => subject }
  end

  def write_ttl_to_file(folder, file, graph, timestamp_ttl = false)
    file_path = File.join(folder, file + '.ttl')
    if timestamp_ttl
      file_path = File.join(folder, file + "_" + DateTime.now.strftime("%Y-%m-%d_%H%M%S") + ".ttl")
    end
    RDF::Writer.open(file_path) { |writer| writer << graph }
  end

  def hash(str)
    return Digest::SHA256.hexdigest str
  end
end

serializer = FormSerializer.new("output")
serializer.serialize
