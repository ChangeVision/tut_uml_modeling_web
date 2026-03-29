# frozen_string_literal: false

# Asciidoctor 2.0 以降は、Themeファイルのroleカテゴリのleadに記載すれば反映されるので、
# この拡張は使わなくても良くなった。

class PDFConverterLeadParagraphs < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_paragraph(node, opts={})
    parse_opts = opts || { margin_bottom: 0, hyphenate: true }
    lead = (roles = node.roles).include? 'lead'
    lead = lead || node.parent.style == 'partintro' # partintroでもleadの書式を使う
    if lead
      warn font_family = @theme['lead_font_family']
      warn font_size = @theme['lead_font_size']
      warn line_height = @theme['lead_line_height']
      warn font_color = @theme['lead_font_color']
      warn font_style = @theme['lead_font_style']
      parse_opts[:color] = font_color
      parse_opts[:size] = font_size
      parse_opts[:font_family] = font_family
      parse_opts[:line_height] = line_height
      parse_opts[:font_style] = font_style
      # # ink_prose node.content, prose_opts
      super node, parse_opts
    else
      super
    end
  end
end
