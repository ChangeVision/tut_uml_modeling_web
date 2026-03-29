# frozen_string_literal: true
#
# Change bars
# 修正箇所の指示や確認等を挿入するのに使う
#
# [.changed]
# This line has been changed.

class PDFConverterChangeBars < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  # def convert_paragraph(node, opts={})
  #   start_cursor = cursor
  #   super
  #   if start_cursor < cursor
  #     # 残りが少なくて改ページしていた場合はたぶんページ先頭からだろう
  #     start_cursor = bounds.top - 10
  #   end
  #   if node.role? 'changed'
  #     bottom_height = @theme.prose_margin_bottom + 3
  #     # warn "#{start_cursor}, #{cursor}, #{(start_cursor - cursor - bottom_height)}"
  #     float do
  #       bounding_box [bounds.left - 10, start_cursor], width: 4, height: (start_cursor - cursor - bottom_height) do
  #         fill_bounds 'FF7F50' #'FF0000'
  #       end
  #     end
  #   end
  # end

  def convert_paragraph(node, opts={})
    if node.role? 'changed'
      opts[:changed] = true
    end
    super
  end

  def ink_prose string, opts = {}
    # warn "ink_prose #{string}", opts
    string ||= ' ' # もとはnilになることがなかった？
    top_margin = (margin = (opts.delete :margin)) || (opts.delete :margin_top) || 0
    bot_margin = margin || (opts.delete :margin_bottom) || @theme.prose_margin_bottom
    if (transform = resolve_text_transform opts)
      string = transform_text string, transform
    end
    string = hyphenate_text string, @hyphenator if (opts.delete :hyphenate) && (defined? @hyphenator)
    # NOTE: used by extensions; ensures linked text gets formatted using the link styles
    if (anchor = opts.delete :anchor)
      string = anchor == true ? %(<a>#{string}</a>) : %(<a anchor="#{anchor}">#{string}</a>)
    end
    margin_top top_margin
    # NOTE: normalize makes endlines soft (replaces "\n" with ' ')
    inline_format_opts = { normalize: (opts.delete :normalize) != false }
    if (styles = opts.delete :styles)
      inline_format_opts[:inherited] = {
        styles: styles,
        text_decoration_color: (opts.delete :text_decoration_color),
        text_decoration_width: (opts.delete :text_decoration_width),
      }.compact
    end
    if opts[:changed]
      font_color = 'dc143c'
      string = "▶ #{string}"
    else
      font_color = @font_color
    end
    result = typeset_text string, (calc_line_metrics (opts.delete :line_height) || @base_line_height), {
                            color: font_color, # @font_color,
                            inline_format: [inline_format_opts],
                            align: @base_text_align.to_sym,
                          }.merge(opts)
    margin_bottom bot_margin
    result
  end
end
