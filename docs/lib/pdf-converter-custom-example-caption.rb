# frozen_string_literal: false

# delete example's caption with 'nocaption' role.
class CustomExamplePDFConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  # def convert_example(node)
  #   warn 'Converting example node...'
  #   warn "caption: #{node.caption}, title: #{node.title}"
  #   super
  # end

  # example ブロックが [.nocaption] ならキャプションなしタイトルにする
  # ここでは、番号なしの場合用の出力を用意しているだけ
  # 採番しないようにするのは autoxref-treeprocessor.rb の処理
  def convert_example(node)
    # warn 'Converting example node...'
    # warn "caption: #{node.caption}, title: #{node.title}"
    if node.attributes.key?('role') && node.attributes['role'].include?('nocaption')
      node.caption = ''
      node.title = %(【#{node.title}】)
    end
    super
  end
end
