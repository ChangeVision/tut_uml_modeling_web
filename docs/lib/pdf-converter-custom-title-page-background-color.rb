# frozen_string_literal: true

class PDFConverterCustomTitlePageBackgroundColor < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def start_title_page doc
    bg_color = doc.attr 'title-page-background-color'
    if (bg_color)
      @theme[:title_page_background_color] = bg_color
    end
    # warn @theme[:title_page_background_color]
    super
  end
end
