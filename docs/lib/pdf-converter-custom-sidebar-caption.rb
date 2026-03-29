# frozen_string_literal: false

# Custom Converter for Sidebar
class CustomSidebarPDFConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_sidebar(node)
    # warn 'Converting sidebar node...'
    # warn node.caption, node.title
    if node.caption
      node.title = %(【#{node.caption}】 #{node.title})
    elsif node.title
      node.title = %(【#{node.title}】)
    end
    super
  end
end
