require 'json'

class FormData
  FILE_ID = '1eLDfwgzc87hTj5ukV7LczZ8QvMBSJUtfrEFEGA9jfUo'
  def initialize(google_client)
    @client = google_client
  end

  def form_inputs
    inputs_tab = "inputs"
    input_values_tab =  "input_values"

    inputs = @client.get_spreadsheet_tab_values(FILE_ID, inputs_tab)
    input_values = @client.get_spreadsheet_tab_values(FILE_ID, input_values_tab)

    # group possible values per input_id
    input_values = input_values.reduce(Hash.new{|h, k| h[k] = [] }) do |r, e|
      r[e["input-id"]] << e["value"]
      r
    end

    inputs = inputs.map { |e|
      if input_values[e["id"]].length > 0
        e["options"] = input_values[e["id"]].to_json
      end
      e
    }
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
