# frozen_string_literal: false

class PDFConverterColophonParagraphs < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  # 奥付のパラグラフをインデントなしにしたいが、
  # 奥付のパラグラフを特定する方法がわかっていない…
  def convert_paragraph(node, opts={})
    # warn 'convert_paragraph'
    # warn "#{node}, #{opts}"
    # warn node.parent
    # warn node.parent.class
    # warn node.parent.style
    super
  end
end
