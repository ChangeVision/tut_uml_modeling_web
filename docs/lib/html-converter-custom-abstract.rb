# frozen_string_literal: true

module Asciidoctor
class CustomAbstractHtml5Converter < (Asciidoctor::Converter.for 'html5')
  register_for 'html5'

  register_for 'custom_abstract_html5'

  def convert_open node
    if (style = node.style) == 'abstract'
      if node.parent == node.document && node.document.doctype == 'book'
        logger.warn 'abstract block cannot be used in a document without a doctitle when doctype is book. Excluding block content.'
        ''
      else
        id_attr = node.id ? %( id="#{node.id}") : ''
        title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
        %(<div#{id_attr} class="quoteblock abstract#{(role = node.role) ? " #{role}" : ''}">
#{title_el}<blockquote>
#{node.content}
</blockquote>
</div>)
      end
    elsif style == 'partintro' && (node.level > 0 || node.parent.context != :section || node.document.doctype != 'book')
      logger.error 'partintro block can only be used when doctype is book and must be a child of a book part. Excluding block content.'
      ''
    else
      id_attr = node.id ? %( id="#{node.id}") : ''
      title_el = node.title? ? %(<div class="title">#{node.title}</div>\n) : ''
      %(<div#{id_attr} class="openblock#{style && style != 'open' ? " #{style}" : ''}#{(role = node.role) ? " #{role}" : ''}">
#{title_el}<div class="content">
#{node.content}
</div>
</div>)
    end
  end
end
end
