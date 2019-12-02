require 'json'

class FormData

  def initialize(google_client)
    @client = google_client
  end

  def get_type_map
    file_id = '1qhmvKNQyr0Ss4AL5qLtQDzaHRb5Z0IXj5uT-b6jeue4'
    inputs_tab = "map"
    @client.get_spreadsheet_tab_values(file_id, inputs_tab)[0]['TYPE-MAP']
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

    # initially the script only started with one subform per type besluit. They are located on another sheet.
    # let's keep them here as is.
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

    # We want to be able to also do nested subforms, so we created a new sheet for this.
    # By fear of breaking something, we add a next base index.
    # (Oh jeetje)
    base_index = subforms[-1]["ID"].to_i + 1

    # here we need only to know the specific subforms
    defined_subforms = get_subforms.uniq { |e| e["ID"]}

    defined_subforms.each_with_index do |code, index|
      subform = {}
      subform["ID"] = (base_index + index).to_s
      subform["KEY"] = code["IDENTIFIER"]
      subform["INPUT-ID"] = code["ORIG_EIGENSCHAP_ID"]
      subform["CODE-LIST-ID"] = code["EIGENSCHAPWAARDE_ID"]
      subform["MATCH-KIND"] = "uuid"
      subform["FORM"] = code["ID"]

      subforms << subform
    end

    subforms
  end

  def get_subforms
    file_id = '1RuEyRXJ4LtsW_fg3JANVD_hd4f60pxfvil2bvjkwXog'
    tab = 'mapping'
    subforms = @client.get_spreadsheet_tab_values(file_id, tab)
    salt = 'sub_form_mapping'
    subforms.each do |s|
      s["ID"] = salt + ':' + s["ID"]
    end

    # match some of the meta data of the input fields
    subforms.each do |sf|
       form_input_values = form_inputs
       type_data = form_input_values.detect {|e| e["ID"] == sf["ORIG_EIGENSCHAP_ID"]}
       if not type_data
         p "Warning code #{code} is not linked to existing input-field (which could be normal)"
         next
       end
       sf["TYPE"] = type_data["TYPE"]
       sf["ON-PATH"] = type_data["ON-PATH"]
       sf["IDENTIFIER"] = type_data["IDENTIFIER"]
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

    subform_fields = get_subforms.reduce(Hash.new{|h, k| h[k] = [] }) do |r, e|
      r[e["ID"]] << e["EIGENSCHAPID"]
      r
    end

    subforms = get_subforms.map { |e|
      e["ID"] = e["ID"]
      e["INPUT-IDS"] = subform_fields[e["ID"]]
      e
    }
    forms += subforms

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
