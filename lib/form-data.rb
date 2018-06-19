require 'json'

class FormData
  # test
  #FILE_ID =  '1jma5WV28Dg8bIKkQocRx1HlVVMvnwe0nyD4c165sMcY'
  # prod
  FILE_ID = '1eLDfwgzc87hTj5ukV7LczZ8QvMBSJUtfrEFEGA9jfUo'
  def initialize(google_client)
    @client = google_client
  end

  def entity_uris
    inputs_tab = "entity_uris"
    @client.get_spreadsheet_tab_values(FILE_ID, inputs_tab)
  end

  def code_lists
    tab = "code_lists"
    @client.get_spreadsheet_tab_values(FILE_ID, tab)
  end

  def form_inputs
    inputs_tab = "inputs"
    @client.get_spreadsheet_tab_values(FILE_ID, inputs_tab)
  end

  def dynamic_subforms
    subforms_tab = "subforms"
    subforms = @client.get_spreadsheet_tab_values(FILE_ID, subforms_tab)
  end

  def form_nodes
    forms_tab = "forms_fields"
    forms = @client.get_spreadsheet_tab_values(FILE_ID, forms_tab)

    # group form fields
    form_fields = forms.reduce(Hash.new{|h, k| h[k] = [] }) do |r, e|
      r[e["id"]] << e["input-id"]
      r
    end

    # clean up
    forms = forms.map { |e|
      e["input-ids"] = form_fields[e["id"]]
      e.delete("input-id")
      e.delete("input-title")
      e
    }

    forms = forms.uniq { |e| e["id"]}
  end
end
