# frozen_string_literal: false

class Section
  class PDFConverterCustomSectionTitle < (Asciidoctor::Converter.for 'pdf')
    register_for 'pdf'

    # ブック形式では、当座節の振舞いは標準のままとしておく
    # 変えたいときは、ここに処理を追加する
    # def convert_section sect, _opts = {}
    #   # start_new_page if sect.level == 2
    #   super
    # end

    # 節以下（章と部以外）のタイトルのカスタマイズ
    def ink_general_heading(node, title, opts = {})
      if opts[:level] > 2
        sectnum = node.sectnum.sub(/^[\s\.]+/, '')
        title = title.gsub(DropAnchorRx, '').gsub("\u0000", '')
        title = title.sub(/#{sectnum}\s+/, "#{sectnum}#{NBSP}") # .gsub(/\s+/, '&#8288;')
        if sectnum == ''
          # warn 'no hanging'
          opts = { anchor: true, normalize: false }.merge(opts)
        else
          # warn 'hanging'
          hgi = rendered_width_of_string("#{sectnum}#{NBSP}", opts)
          opts = { anchor: true, normalize: false, hanging_indent: hgi }.merge(opts)
        end
      end

      if (h_level = opts[:level])
        h_category = %(heading_h#{h_level})
      end
      unless (top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top))
        if at_page_top?
          if h_category && (top_margin = @theme[%(#{h_category}_margin_page_top)] || @theme.heading_margin_page_top) > 0
            move_down top_margin
          end
          top_margin = 0
        else
          top_margin = (h_category ? @theme[%(#{h_category}_margin_top)] : nil) || @theme.heading_margin_top
        end
      end
      bot_margin = margin || (opts.delete :margin_bottom) ||
                   (h_category ? @theme[%(#{h_category}_margin_bottom)] : nil) ||
                   @theme.heading_margin_bottom
      margin_top top_margin
      bottom_padding = (padding = @theme[%(#{h_category}_padding)]) ? padding[2] : 0
      entry_title_fragments = text_formatter.format title
      line_metrics = calc_line_metrics(1.2)
      outdent_section do
        indent(0, 0) do
          fragment_positions = []
          entry_title_fragments.each do |fragment|
            fragment_positions << (fragment_position = ::Asciidoctor::PDF::FormattedText::FragmentPositionRenderer.new)
            (fragment[:callback] ||= []) << fragment_position
          end
          typeset_formatted_text entry_title_fragments, line_metrics, { color: @font_color }.merge(opts)
        end
        move_down bottom_padding
        # ボーダーを引くならここに書く
      end
      margin_bottom bot_margin
    end
  end
end
