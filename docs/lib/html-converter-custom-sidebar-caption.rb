# frozen_string_literal: true

require 'asciidoctor/converter/html5'

module Asciidoctor
class CustomSidebarCaptionHtml5Converter < (Asciidoctor::Converter.for 'html5')
  register_for 'html5'

  register_for 'sidebar_caption_html5'

  def convert_sidebar(node)
    # warn 'Converting a sidebar node...'
    if node.caption
      node.title = %(【#{node.caption}】 #{node.title})
    elsif node.title
      node.title = %(【#{node.title}】)
    end
    super
  end
end
end
