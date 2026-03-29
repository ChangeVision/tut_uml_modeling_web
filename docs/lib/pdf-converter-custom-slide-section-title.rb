# frozen_string_literal: false

class Section
  class PDFConverterCustomSectionTitle < (Asciidoctor::Converter.for 'pdf')
    register_for 'pdf'

    # スライドでは改ページの機会が多いので、
    # 節（セクション）の前は改ページすることに
    def convert_section(sect, _opts = {})
      unless at_page_top?
        if sect.level == 2
          start_new_page
        end
      end
      super
    end

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

    # NOTE: ページヘッダにくる章節名の長さがおかしいのを何とかする
    def ink_running_content periphery, doc, skip = [1, 1], body_start_page_number = 1
      # warn "ink_running_content #{periphery}"
      skip_pages, skip_pagenums = skip
      # NOTE: find and advance to first non-imported content page to use as model page
      return unless (content_start_page_number = state.pages[skip_pages..-1].index {|it| !it.imported_page? })
      content_start_page_number += (skip_pages + 1)
      num_pages = page_count
      prev_page_number = page_number
      go_to_page content_start_page_number

      # FIXME: probably need to treat doctypes differently
      is_book = doc.doctype == 'book'
      header = doc.header? ? doc.header : nil
      sectlevels = (@theme[%(#{periphery}_sectlevels)] || 2).to_i
      sections = doc.find_by(context: :section) {|sect| sect.level <= sectlevels && sect != header }
      toc_title = (doc.attr 'toc-title').to_s if (toc_page_nums = @toc_extent&.page_range)
      disable_on_pages = @disable_running_content[periphery]

      title_method = TitleStyles[@theme[%(#{periphery}_title_style)]]
      # FIXME: we need a proper model for all this page counting
      # FIXME: we make a big assumption that part & chapter start on new pages
      # index parts, chapters and sections by the physical page number on which they start
      part_start_pages = {}
      chapter_start_pages = {}
      section_start_pages = {}
      trailing_section_start_pages = {}
      sections.each do |sect|
        pgnum = (sect.attr 'pdf-page-start').to_i
        if is_book && ((sect_is_part = sect.sectname == 'part') || sect.level == 1)
          if sect_is_part
            part_start_pages[pgnum] ||= sect
          else
            chapter_start_pages[pgnum] ||= sect
            # FIXME: need a better way to indicate that part has ended
            part_start_pages[pgnum] = '' if sect.sectname == 'appendix' && !part_start_pages.empty?
          end
        else
          trailing_section_start_pages[pgnum] = sect
          section_start_pages[pgnum] ||= sect
        end
      end

      # index parts, chapters, and sections by the physical page number on which they appear
      parts_by_page = ::Asciidoctor::PDF::SectionInfoByPage.new title_method
      chapters_by_page = ::Asciidoctor::PDF::SectionInfoByPage.new title_method
      sections_by_page = ::Asciidoctor::PDF::SectionInfoByPage.new title_method
      # QUESTION: should the default part be the doctitle?
      last_part = nil
      # QUESTION: should we enforce that the preamble is a preface?
      last_chap = is_book ? :pre : nil
      last_sect = nil
      sect_search_threshold = 1
      (1..num_pages).each do |pgnum|
        if (part = part_start_pages[pgnum])
          last_part = part
          last_chap = nil
          last_sect = nil
        end
        if (chap = chapter_start_pages[pgnum])
          last_chap = chap
          last_sect = nil
        end
        if (sect = section_start_pages[pgnum])
          last_sect = sect
        elsif part || chap
          sect_search_threshold = pgnum
        # NOTE: we didn't find a section on this page; look back to find last section started
        elsif last_sect
          (sect_search_threshold..(pgnum - 1)).reverse_each do |prev|
            if (sect = trailing_section_start_pages[prev])
              last_sect = sect
              break
            end
          end
        end
        parts_by_page[pgnum] = last_part
        if toc_page_nums&.cover? pgnum
          if is_book
            chapters_by_page[pgnum] = toc_title
            sections_by_page[pgnum] = nil
          else
            chapters_by_page[pgnum] = nil
            sections_by_page[pgnum] = section_start_pages[pgnum] || toc_title
          end
          toc_page_nums = nil if toc_page_nums.end == pgnum
        elsif last_chap == :pre
          chapters_by_page[pgnum] = pgnum < body_start_page_number ? doc.doctitle : (doc.attr 'preface-title', 'Preface')
          sections_by_page[pgnum] = last_sect
        else
          chapters_by_page[pgnum] = last_chap
          sections_by_page[pgnum] = last_sect
        end
      end

      doctitle = resolve_doctitle doc, true
      # NOTE: set doctitle again so it's properly escaped
      doc.set_attr 'doctitle', doctitle.combined
      doc.set_attr 'document-title', doctitle.main
      doc.set_attr 'document-subtitle', doctitle.subtitle
      doc.set_attr 'page-count', (num_pages - skip_pagenums)

      pagenums_enabled = doc.attr? 'pagenums'
      periphery_layout_cache = {}
      # NOTE: Prawn fails to properly set color spaces on empty pages, but repeater relies on them
      # prefer simpler fix below call to repeat; keep this workaround in case that workaround stops working
      #(content_start_page_number..num_pages).each do |pgnum|
      #  next if (disable_on_pages.include? pgnum) || (pg = state.pages[pgnum - 1]).imported_page? || !pg.graphic_state.color_space.empty?
      #  go_to_page pgnum
      #  set_color_space :fill, (color_space graphic_state.fill_color)
      #  set_color_space :stroke, (color_space graphic_state.stroke_color)
      #end
      #go_to_page content_start_page_number if page_number != content_start_page_number
      # NOTE: this block is invoked during PDF generation, during call to #write -> #render_file and thus after #convert_document
      repeat (content_start_page_number..num_pages), dynamic: true do
        pgnum = page_number
        # NOTE: don't write on pages which are imported / inserts (otherwise we can get a corrupt PDF)
        next if page.imported_page? || (disable_on_pages.include? pgnum)
        virtual_pgnum = pgnum - skip_pagenums
        pgnum_label = (virtual_pgnum < 1 ? (RomanNumeral.new pgnum, :lower) : virtual_pgnum).to_s
        side = page_side((@folio_placement[:basis] == :physical ? pgnum : virtual_pgnum), @folio_placement[:inverted])
        doc.set_attr 'page-layout', page.layout.to_s

        # NOTE: running content is cached per page layout
        # QUESTION: should allocation be per side?
        trim_styles, colspec_dict, content_dict, stamp_names = allocate_running_content_layout doc, page, periphery, periphery_layout_cache
        # FIXME: we need to have a content setting for chapter pages
        content_by_position, colspec_by_position = content_dict[side], colspec_dict[side]

        doc.set_attr 'page-number', pgnum_label if pagenums_enabled
        # QUESTION: should the fallback value be nil instead of empty string? or should we remove attribute if no value?
        doc.set_attr 'part-title', ((part_info = parts_by_page[pgnum])[:title] || '')
        if (part_numeral = part_info[:numeral])
          doc.set_attr 'part-numeral', part_numeral
        else
          doc.remove_attr 'part-numeral'
        end
        doc.set_attr 'chapter-title', ((chap_info = chapters_by_page[pgnum])[:title] || '')
        if (chap_numeral = chap_info[:numeral])
          doc.set_attr 'chapter-numeral', chap_numeral
        else
          doc.remove_attr 'chapter-numeral'
        end
        doc.set_attr 'section-title', ((sect_info = sections_by_page[pgnum])[:title] || '')
        doc.set_attr 'section-or-chapter-title', (sect_info[:title] || chap_info[:title] || '')

        stamp stamp_names[side] if stamp_names

        theme_font periphery do
          canvas do
            bounding_box [trim_styles[:content_left][side], trim_styles[:top][side]], width: trim_styles[:content_width][side], height: trim_styles[:height] do
              if trim_styles[:column_rule_color] && (trim_column_rule_width = trim_styles[:column_rule_width]) > 0
                trim_column_rule_spacing = trim_styles[:column_rule_spacing]
              else
                trim_column_rule_width = nil
              end
              prev_position = nil
              ColumnPositions.each do |position|
                next unless (content = content_by_position[position])
                next unless (colspec = colspec_by_position[position])[:width] > 0
                left, colwidth = colspec[:x], colspec[:width]
                if trim_column_rule_width && colwidth < bounds.width
                  if (trim_column_rule = prev_position)
                    left += (trim_column_rule_spacing * 0.5)
                    colwidth -= trim_column_rule_spacing
                  else
                    colwidth -= (trim_column_rule_spacing * 0.5)
                  end
                end
                # FIXME: we need to have a content setting for chapter pages
                if ::Array === content
                  redo_with_content = nil
                  # NOTE: float ensures cursor position is restored and returns us to current page if we overrun
                  float do
                    # NOTE: bounding_box is redundant if both vertical padding and border width are 0
                    bounding_box [left, bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset]], width: colwidth, height: trim_styles[:content_height][side] do
                      # NOTE: image vposition respects padding; use negative image_vertical_align value to revert
                      image_opts = content[1].merge position: colspec[:align], vposition: trim_styles[:img_valign]
                      begin
                        image_info = image content[0], image_opts
                        if (image_link = content[2])
                          image_info = { width: image_info.scaled_width, height: image_info.scaled_height } unless image_opts[:format] == 'svg'
                          add_link_to_image image_link, image_info, image_opts
                        end
                      rescue
                        redo_with_content = image_opts[:alt]
                        log :warn, %(could not embed image in running content: #{content[0]}; #{$!.message})
                      end
                    end
                  end
                  if redo_with_content
                    content_by_position[position] = redo_with_content
                    redo
                  end
                else
                  theme_font %(#{periphery}_#{side}_#{position}) do
                    # NOTE: minor optimization
                    if content == '{page-number}'
                      content = pagenums_enabled ? pgnum_label : nil
                    else
                      content = apply_subs_discretely doc, content, drop_lines_with_unresolved_attributes: true, imagesdir: @themesdir
                      content = transform_text content, @text_transform if @text_transform
                    end
                    formatted_text_box (parse_text content, inline_format: [normalize: true]),
                                       at: [left, bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset] + ((Array trim_styles[:valign])[0] == :center ? font.descender * 0.5 : 0)],
                                       color: @font_color,
                                       width: colwidth,
                                       height: trim_styles[:prose_content_height][side],
                                       align: colspec[:align],
                                       valign: trim_styles[:valign],
                                       leading: trim_styles[:line_metrics].leading,
                                       final_gap: false,
                                       overflow: :truncate
                  end
                end
                bounding_box [colspec[:x], bounds.top - trim_styles[:padding][side][0] - trim_styles[:content_offset]], width: colspec[:width], height: trim_styles[:content_height][side] do
                  stroke_vertical_rule trim_styles[:column_rule_color], at: bounds.left, line_style: trim_styles[:column_rule_style], line_width: trim_column_rule_width
                end if trim_column_rule
                prev_position = position
              end
            end
          end
        end
      end
      # NOTE: force repeater to consult color spaces on current page instead of the page on which repeater was created
      # if this stops working, use the commented code above repeat call instead
      unless (repeater_graphic_state = repeaters[-1].instance_variable_get :@graphic_state).singleton_methods.include? :color_space
        # NOTE: must convert override method to proc since we're are changing bind argument
        repeater_graphic_state.define_singleton_method :color_space, (method :page_color_space).to_proc
      end
      go_to_page prev_page_number
      nil
    end
  end
end
