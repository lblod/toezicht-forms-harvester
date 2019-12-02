require './google-sheets-client'
require './lib/form-data'
require 'pry-byebug'
require 'linkeddata'
require 'bson'
require 'digest'
require 'fileutils'
require 'digest/md5'

############################################################################
# DISCLAIMER
# So far, we have been lucky with the generation of the forms. But in fact,
# it is not correct. We will get in trouble in the following described case.
#
# The 'form-input' are not context sensitive, i.e. their behaviour does not depend
# on the form-node they are coming from.
#
# Suppose we have formNodeA and formNodeB, both containing formInputA.
# formInputA is a selectBox with option1 and option2.
# In context formNodeA, whatever option selected, no new form-node should be rendered.
# In context formNodeB, if option2 is selected formNodeC should be rendered (through a dynamic-subform)
# Current implementation will always render formNodeC if option2 is selected.
#
# So for this script the same conceptual selectBox for every form-node, a new instance should be
# created.
# This feels somewhat weird, because this selectBox always contains the same content, but is not uniquely
# identified. A little bit like an atom that reacts differently in water vs air or so.
#############################################################################
class FormSerializer
  FOAF = RDF::Vocab::FOAF
  DC = RDF::Vocab::DC
  RDFS = RDF::Vocab::RDFS
  ADMS = RDF::Vocabulary.new("http://www.w3.org/ns/adms#")
  MU = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/core/")
  EXT = RDF::Vocabulary.new("http://mu.semte.ch/vocabularies/ext/")
  SKOS = RDF::Vocab::SKOS
  SCHEMA = RDF::Vocab::SCHEMA
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
    input_state_empty = create_input_state
    form_inputs_map = create_form_inputs(input_state_empty)
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
    @graph << RDF.Statement(subject, SCHEMA.position, RDF::Literal.new(row["ID"].to_i, datatype: RDF::XSD.integer))

    if row["TYPE"] == "Nomenclature"
          @graph << RDF.Statement(subject, TOEZICHT["nomenclatureCode"], row["CODE"])
    end
    if row["TYPE"] == "DecisionType"
      ['GEMEENTE', 'DISTRICT', 'OCMW', 'PROVINCIE', 'OCMWV', 'AGB', 'APB', 'IGS', 'HVZ', 'PZ', 'DV', 'OV', 'PV'].each do |key|
        @graph << RDF.Statement(subject, EXT.decidableBy, RDF::URI(entities_map[key])) if (row[key] and row[key].upcase == 'X')
      end
    end
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, SKOS.prefLabel, row["OMSCHRIJVINGKORT"])
    @graph << RDF.Statement(subject, EXT["isActiveToezichtCodeListEntry"],  RDF::Literal.new( row["IN_USE"] == 'yes', datatype: RDF::XSD.boolean) )

    { row["ID"] => {"URI" => subject, "UUID" => uuid } }
  end

  def create_form_inputs(input_state)
    form_inputs_map = {}
    @form_inputs.each do |row|
      form_inputs_map.merge!(create_form_input(row, input_state))
    end
    form_inputs_map
  end

  def create_form_input(row, input_state)
    salt = "018547bf-c213-4a2b-953d-1f457412fdf0"
    uuid = hash(salt + ":" + row["ID"])
    subject =  RDF::URI(BASE_URI % {:resource => "form-inputs", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT.FormInput)
    @graph << RDF.Statement(subject, EXT["index"], row["INDEX"])
    @graph << RDF.Statement(subject, EXT["displayType"], row["DISPLAY-TYPE"])
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, DC.title, row["TITLE"])

    if row["OPTIONS"]
      @graph << RDF.Statement(subject, EXT.options , row["OPTIONS"])
    end

    if row["REQUIRED"] and row["REQUIRED"].strip == "TRUE"
      p "found required field"
      @graph << RDF.Statement(subject, EXT["inputStates"], input_state)
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
    salt = "fc356663-539a-427a-89d9-0a0bb22139d4"
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
    salt = "fe4b8928-8b89-46b1-9110-da95975d949c"
    uuid = hash(salt + ":" + row["ID"].to_s)
    subject =  RDF::URI(BASE_URI % {:resource => "form-nodes", :id => uuid})

    @graph << RDF.Statement(subject, RDF.type, EXT.FormNode)
    @graph << RDF.Statement(subject, MU.uuid, uuid)
    @graph << RDF.Statement(subject, EXT["typeMap"], row["TYPE-MAP"])

    row["INPUT-IDS"].each do |id|
      if form_inputs_map[id]
        @graph << RDF.Statement(subject, EXT["formInput"], form_inputs_map[id])
      else
        p "Warning form field (eigenschap) #{id} defined in form, but refering to non existant field (which could be ok)"
      end

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
