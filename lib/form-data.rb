require 'json'

class FormData

  def initialize(google_client)
    @client = google_client
  end

  def entity_uris
    file_id = '1WMSfiX7eubZHprsaOhYNJuUFrB9Ca4KIH9ucVUnbJxc'
    inputs_tab = "entity_uris"
    @client.get_spreadsheet_tab_values(file_id, inputs_tab)
  end

  def code_lists
    file_id = "1p4dXSoAmY8613wJiPOfrKR55sA8VPxrOexokzb7V7U8"
    tab = "EIGENSCHAPWAARDE"
    codes = @client.get_spreadsheet_tab_values(file_id, tab).sort_by {|code| code["ID"]}

    # now match the correct type
    form_input_values = form_inputs

    codes.each do |code|
      type_data = form_input_values.detect {|e| e["ID"] == code["EIGENSCHAPID"]}
      if not type_data
        p "Warning code #{code} is not linked to existing input-field (which should be normal)"
        next
      end
      code["TYPE"] = type_data["TYPE"]
      code["ON-PATH"] = type_data["ON-PATH"]
    end

    # filter out  codes with no ["TYPE"]
    codes = codes.select { |code| code["TYPE"] }

    # merge with besluit type (a little complicated procedure, since list will be used to build up subforms too)
    new_base_index = codes[-1]["ID"].to_i + 1
    file_id = '1GByfyfO2eMkuiMUi22j8Ybdqjxd8_EO8moOCdS2xAvs'
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
    file_id = '1g3eluO2ZvGDJJ0U8f-FWBT0qzYQtcmhupuG4-QjjNOI'
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
    file_id = '14Sh31npY2S2aGI1DC7Rl6of_0O-OxG2xugH63vtKSMk'
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
