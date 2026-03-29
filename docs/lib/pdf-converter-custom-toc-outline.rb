# frozen_string_literal: true

class PDFConverterNarrawToc < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_toc_level(entries, num_levels, dot_leader, num_front_matter_pages)
    # warn 'ink_toc_level ' + (scratch? ? '(scratch)' : '(layout)')
    # 目次から奥付を除く
    ent = entries.select { |e| e.sectname == 'colophon' }
    entries.delete(ent[0])

    # NOTE: font options aren't always reliable, so store size separately
    toc_font_info = theme_font :toc do
      { font: font, size: @font_size }
    end
    hanging_indent = @theme.toc_hanging_indent
    entries.each do |entry|
      next if (num_levels_for_entry = (entry.attr 'toclevels', num_levels).to_i) < (entry_level = entry.level + 1).pred ||
              ((entry.option? 'notitle') && entry == entry.document.last_child && entry.empty?)
      theme_font :toc, level: entry_level do
        entry_title = entry.context == :section ? entry.numbered_title : (entry.title? ? entry.title : (entry.xreftext 'basic'))
        next if entry_title.empty?
        entry_title = entry_title.gsub DropAnchorRx, '' if entry_title.include? '<a' # アンカー等を削除
        entry_title = entry_title.gsub(/\u0000/, '')  # アンカーを削除したときに何故か残る\u0000を削除する
        # 引数からはsectnumを得られない（optsもない）ので、止むを得ずこの場で想定の書式で章節名とマッチする
        values = entry_title.split(/([A-Z\d.]+|第\d+章|付録[A-Z])[[:space:]]+(.+)/)
        if values[1] # sectnumが取得できた場合は[1]に入り、ないときはnil
          sectnum = values[1]
          # 章節番号で折り返さないよう、直後のスペースをNBSPに変更する
          entry_title = entry_title.sub(/#{sectnum}\s+/, "#{sectnum}#{NBSP}")
          # ぶら下がりインデント幅を章節番号の分にする
          hanging_indent = rendered_width_of_string("#{sectnum}#{NBSP}")
        else
          hanging_indent = 0
        end
        entry_title = transform_text entry_title, @text_transform if @text_transform
        pgnum_label_placeholder_width = rendered_width_of_string '0' * @toc_max_pagenum_digits
        # NOTE: only write title (excluding dots and page number) if this is a dry run
        if scratch?
          # もし、字下げを抑制するなら、
          # これでトップレベルのインデント（section-indentの分）を相殺する
          # outdent_section do
          indent 0, pgnum_label_placeholder_width do
            # NOTE: must wrap title in empty anchor element in case links are styled with different font family / size
            ink_prose entry_title, anchor: true, normalize: false, hanging_indent: hanging_indent, normalize_line_height: true, margin: 0
          end
          # end # outdent
        else
          entry_anchor = (entry.attr 'pdf-anchor') || entry.id
          if !(physical_pgnum = entry.attr 'pdf-page-start') &&
             (target_page_ref = (get_dest entry_anchor)&.first) &&
             (target_page_idx = state.pages.index {|candidate| candidate.dictionary == target_page_ref })
            physical_pgnum = target_page_idx + 1
          end
          if physical_pgnum
            virtual_pgnum = physical_pgnum - num_front_matter_pages
            pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new physical_pgnum, :lower) : virtual_pgnum).to_s
          else
            pgnum_label = '?'
          end
          start_page_number = page_number
          start_cursor = cursor
          start_dots = nil
          entry_title_inherited = (apply_text_decoration ::Set.new, :toc, entry_level).merge anchor: entry_anchor, color: @font_color
          # NOTE: use text formatter to add anchor overlay to avoid using inline format with synthetic anchor tag
          entry_title_fragments = text_formatter.format entry_title, inherited: entry_title_inherited
          line_metrics = calc_line_metrics @base_line_height
          # もし、字下げを抑制するなら、
          # これでトップレベルのインデント（section-indentの分）を相殺する
          # outdent_section do
          indent 0, pgnum_label_placeholder_width do
            fragment_positions = []
            entry_title_fragments.each do |fragment|
              fragment_positions << (fragment_position = ::Asciidoctor::PDF::FormattedText::FragmentPositionRenderer.new)
              (fragment[:callback] ||= []) << fragment_position
            end
            typeset_formatted_text entry_title_fragments, line_metrics, hanging_indent: hanging_indent, normalize_line_height: true
            break unless (last_fragment_position = fragment_positions.select(&:page_number)[-1])
            start_dots = last_fragment_position.right + hanging_indent
            # 長い行が折り返されたときに、last_fragment_cursorの計算値がちょっとだけ小さくなってしまい、
            # ドットとページを出力する行が、最後の行にならず、1行上になってしまうため、0.1 引いて調整している
            last_fragment_cursor = last_fragment_position.top + line_metrics.padding_top - 0.1
            # warn entry_title, line_metrics.height
            # warn "l_f: #{last_fragment_cursor}, s_c: #{start_cursor}, #{start_cursor - last_fragment_cursor}, #{(start_cursor - last_fragment_cursor) > line_metrics.height}"
            start_cursor = last_fragment_cursor if last_fragment_position.page_number > start_page_number || (start_cursor - last_fragment_cursor) > line_metrics.height
          end
          # NOTE: this will leave behind a gap where this entry would have been
          break unless start_dots
          end_cursor = cursor
          move_cursor_to start_cursor
          # NOTE: we're guaranteed to be on the same page as the final line of the entry
          if dot_leader[:width] > 0 && (dot_leader[:levels] ? (dot_leader[:levels].include? entry_level.pred) : true)
            pgnum_label_width = rendered_width_of_string pgnum_label
            pgnum_label_font_settings = { color: @font_color, font: font_family, size: @font_size, styles: font_styles }
            save_font do
              # NOTE: the same font is used for dot leaders throughout toc
              set_font toc_font_info[:font], dot_leader[:font_size]
              font_style dot_leader[:font_style]
              num_dots = [((bounds.width - start_dots - dot_leader[:spacer_width] - pgnum_label_width) / dot_leader[:width]).floor, 0].max
              # FIXME: dots don't line up in columns if width of page numbers differ
              typeset_formatted_text [
                { text: dot_leader[:text] * num_dots, color: dot_leader[:font_color] },
                dot_leader[:spacer],
                ({ text: pgnum_label, anchor: entry_anchor }.merge pgnum_label_font_settings),
              ], line_metrics, align: :right
            end
          else
            typeset_formatted_text [{ text: pgnum_label, color: @font_color, anchor: entry_anchor }], line_metrics, align: :right
          end
          move_cursor_to end_cursor
          # end # outdent
        end # scratch?
      end
      indent @theme.toc_indent do
        ink_toc_level (get_entries_for_toc entry), num_levels_for_entry, dot_leader, num_front_matter_pages
      end if num_levels_for_entry >= entry_level
    end
  end

  def ink_toc *_args
    # 目次の左右インデントを与えて、幅を狭くする
    if @theme.page_layout == 'landscape'
      line_width = 550
    else
      line_width = 400
    end
    left_indent = (bounds.width - line_width) * 2 / 5
    right_indent = bounds.width - (line_width + left_indent)
    indent left_indent, right_indent do
      super
    end
  end

  def add_outline(doc, num_levels, toc_page_nums, num_front_matter_pages, has_front_cover)
    # PDFしおりのcolophonの内容を文書名から colophon-title で指定した名前に代える
    sections = doc.find_by(context: :section) { |sect| sect.sectname == 'colophon' }
    sections[0].title = doc.attr 'colophon-title' if sections && (doc.attr? 'colophon-title')
    super
  end
end
