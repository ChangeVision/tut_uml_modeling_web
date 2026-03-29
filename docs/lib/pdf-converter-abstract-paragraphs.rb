# frozen_string_literal: false

class PDFConverterAbstractParagraphs < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_abstract(node)
    # warn 'convert_abstract'

    add_dest_for_block node if node.id
    outdent_section do
      pad_box @theme.abstract_padding do
        # キャプション（Abstractではセクションタイトルのように振る舞う）
        theme_font :abstract_title do
          ink_prose node.title, align: (@theme.abstract_title_text_align || @base_text_align).to_sym, margin_top: @theme.heading_margin_top, margin_bottom: @theme.heading_margin_bottom, line_height: (@theme.heading_line_height || @theme.base_line_height)
        end if node.title?

        theme_font :abstract do
          # 本文のmargin_bottomは、proseのもの（通常の本文の段落間送り）と同じにする（defaultは固定で0）
          prose_opts = { align: (@theme.abstract_text_align || @base_text_align).to_sym, hyphenate: true, margin_bottom: @theme.prose_margin_bottom }

          # 概要の1行目野出力にテーマの指定を反映する
          if (line1_font_style = @theme.abstract_first_line_font_style&.to_sym) && line1_font_style != font_style
            case line1_font_style
            when :normal
              first_line_options = { styles: [] }
            when :normal_italic
              first_line_options = { styles: [:italic] }
            else
              first_line_options = { styles: [font_style, line1_font_style] }
            end
          end
          if (line1_font_color = @theme.abstract_first_line_font_color)
            (first_line_options ||= {})[:color] = line1_font_color
          end
          if (line1_text_transform = @theme.abstract_first_line_text_transform)
            (first_line_options ||= {})[:text_transform] = line1_text_transform
          end
          prose_opts[:first_line_options] = first_line_options if first_line_options

          indent_section do # section-indentの字下げを活かす
            if node.blocks?
              node.blocks.each do |child|
                if child.context == :paragraph
                  # paragraphだったときは、
                  # 1行目のときに上記の設定を使って
                  child.document.playback_attributes child.attributes
                  convert_paragraph child, prose_opts.dup
                  # 先頭のパラグラフ以外は、1行目用の設定は使わないのでとり除く
                  prose_opts.delete :first_line_options
                else
                  # FIXME: this could do strange things if the wrong kind of content shows up
                  child.convert
                end
              end
            elsif node.content_model != :compound && (string = node.content)
              if (text_align = resolve_text_align_from_role node.roles)
                prose_opts[:align] = text_align
              end
              if IndentableTextAlignments[prose_opts[:align]] && (text_indent = @theme.prose_text_indent) > 0
                prose_opts[:indent_paragraphs] = text_indent
              end
              ink_prose string, prose_opts
            end
          end # indent_section
        end
      end
    # super
  end
end
end
