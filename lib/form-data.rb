require 'json'

class FormData

  def initialize(google_client)
    @client = google_client
  end

  def entity_uris
    file_id = '1MT12P1U5Dwp9mhVkJXC1oMbZhjbQdiEsyWVUZSeGTZI'
    inputs_tab = "entity_uris"
    @client.get_spreadsheet_tab_values(file_id, inputs_tab)
  end

  def code_lists
    file_id = "1mpihMEXzqGwRPsoABoAHgx01doA0IUfzmcbTxBqriAg"
    tab = "EIGENSCHAPWAARDE"
    codes = @client.get_spreadsheet_tab_values(file_id, tab).sort_by {|code| code["ID"]}

    # now match the correct type
    form_input_values = form_inputs

    codes.each do |code|
      type_data = form_input_values.detect {|e| e["ID"] == code["EIGENSCHAPID"]}
      code["TYPE"] = type_data["TYPE"]
      code["ON-PATH"] = type_data["ON-PATH"]
    end

    # merge with besluit type (a little complicated procedure, since list will be used to build up subforms too)
    new_base_index = codes[-1]["ID"].to_i + 1
    file_id = "1cDyVoLNXSX8f1Q0cUuKirRoUlHVIe5Cm2nyQudK1700"
    tab = "TYPEBESLUIT"
    @client.get_spreadsheet_tab_values(file_id, tab).each do |code|
      code["FORMID"] = code["ID"] # this number needs to be kept
      code["ID"] = code["ID"].to_i + new_base_index
      code["EIGENSCHAPID"] = 0
      code["TYPE"] = "DecisionType"
      code["ON-PATH"] = "besluit-types"
      codes << code
    end
    codes.sort {|code| code["ID"].to_i}
  end

  def form_inputs
    file_id = "1Z2ju6dME0lv73TK2aYPLh4olDzG6wKYBR5uRaaOATE8"
    inputs_tab = "EIGENSCHAP"
    @client.get_spreadsheet_tab_values(file_id, inputs_tab).select {|input| not input["IGNORE"] == "TRUE"}
  end

  def dynamic_subforms
    codes = code_lists.select {|code| code["EIGENSCHAPID"] == 0}.sort{|code| code["ID"]}
    subforms = []
    codes.each_with_index do |code, index|
      subform = {}
      subform["ID"] = index.to_s
      subform["KEY"] = "inzendingVoorToezicht.besluitType"
      subform["INPUT-ID"] = "0"
      subform["CODE-LIST-ID"] = code["ID"]
      subform["MATCH-KIND"] = "uuid"
      subform["FORM"] = code["FORMID"]

      subforms << subform
    end

    subforms
  end

  def form_nodes
    file_id = "1JjNZ9VyVTSYX7V6P2Z_JCIoDKi9aP1oW2sb7wNr3rgs"
    forms_tab = "TYPEBESLUIT_EIGENSCHAP_REL"
    forms = @client.get_spreadsheet_tab_values(file_id, forms_tab)

    # group form fields
    form_fields = forms.reduce(Hash.new{|h, k| h[k] = [] }) do |r, e|
      r[e["TYPEBESLUITID"]] << e["EIGENSCHAPID"]
      r
    end

    forms = forms.map { |e|
      e["ID"] = e["TYPEBESLUITID"]
      e["INPUT-IDS"] = form_fields[e["TYPEBESLUITID"]]
      e
    }

    forms = forms.uniq { |e| e["ID"]}
    # we need a root form
    root_form = {}
    root_form["ID"] = "-1"
    root_form["INPUT-IDS"] = ["0"]
    root_form["TYPE-MAP"] = forms[0]["TYPE-MAP"]

    forms << root_form
    forms
  end
end
