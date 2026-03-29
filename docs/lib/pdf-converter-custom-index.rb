# frozen_string_literal: false

class Section
  class PDFConverterImageIndent < (Asciidoctor::Converter.for 'pdf')
    register_for 'pdf'

    def convert_index_term term, pagenum_sequence_style = nil
      term_fragments = term.name.fragments
      unless term.container?
        pagenum_fragment = (parse_text %(<a>#{DummyText}</a>), inline_format: true)[0]
        # if @media == 'screen' # screen以外もページにリンクを生成する
        case pagenum_sequence_style
        when 'page'
          pagenums = term.dests.uniq {|dest| dest[:page] }.map {|dest| pagenum_fragment.merge anchor: dest[:anchor], text: dest[:page] }
        when 'range'
          first_anchor_per_page = {}.tap {|accum| term.dests.each {|dest| accum[dest[:page]] ||= dest[:anchor] } }
          pagenums = (consolidate_ranges first_anchor_per_page.keys).map do |range|
            anchor = first_anchor_per_page[(range.include? '-') ? (range.partition '-')[0] : range]
            pagenum_fragment.merge text: range, anchor: anchor
          end
        else # term
          pagenums = term.dests.map {|dest| pagenum_fragment.merge text: dest[:page], anchor: dest[:anchor] }
        end
        # else
        #   pagenums = consolidate_ranges term.dests.map {|dest| dest[:page] }.uniq
        #  end
        pagenums.each do |pagenum|
          if ::String === pagenum
            term_fragments << ({ text: %(, #{pagenum}) })
          else
            term_fragments << { text: ', ' }
            term_fragments << pagenum
          end
        end
      end
      subterm_indent = @theme.description_list_description_indent
      typeset_formatted_text term_fragments, (calc_line_metrics @base_line_height), align: :left, color: @font_color, hanging_indent: subterm_indent * 2, consolidate: true
      indent subterm_indent do
        term.subterms.each do |subterm|
          convert_index_term subterm, pagenum_sequence_style
        end
      end unless term.leaf?
    end
  end
end
