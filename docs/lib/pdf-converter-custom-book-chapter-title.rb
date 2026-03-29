# frozen_string_literal: false

class Section
  class PDFConverterCustomChapterTitle < (Asciidoctor::Converter.for 'pdf')
    register_for 'pdf'

    # 部のタイトルのカスタマイズ
    def ink_part_title(node, title, opts = {})
      # warn "custom ink_part_title #{opts}"
      opts[:outdent] = true
      super
    end

    # 章のタイトルのカスタマイズ
    def ink_chapter_title(node, title, opts = {})
      # warn 'custom ink_chapter_title'
      opts[:outdent] = true
      case node.sectname
      when 'colophon'
        # 奥付は通常の章ではないので特別扱い
        ink_heading_colophon node, title, opts
      when 'bibliography', 'index'
        # 参考文献は章を扉にしないので特別扱い
        # 索引は章を扉にしないので特別扱い
        ink_heading_bibs node, title, opts
      else
        # ほかの章一般（部と節以下このメソッドを呼ばないはず）
        # ink_general_heading node, title, opts
        ink_heading_custom_chapter node, title, opts
      end
    end

    # 一般の章
    def ink_heading_custom_chapter(node, title, opts={})
      # warn 'ink_heading_custom_chapter'

      # 章タイトルにロゴを出力
      title_start_cursor = cursor # 開始位置を保存

      # 章に使うイメージは、下記のように章ごとに指定できる
      # [image=gears.png]
      # == Chapter Title
      # この場合、次のようにして文書中の指定を参照できる
      # image_path = sect.attr 'image'
      # 加えて、文書中ではイメージのパス名は特別扱いなので、文書中の指定を参照する場合には、
      # Blockのパラメータに relative_to_imagesdir: true が必要になるのに注意
      # イメージファイルを指定するのが、テーマ参照やファイル指定の場合は、テーマファイルディレクトリからの相対になる
      # image_path = '../../logo/ill_4c.jpg'
      # テーマファイルのタイトルページのイメージを参照する
      image_path = @theme.title_page_logo_image || 'title-page-logo-image not found'
      move_cursor_to page_height - 110 # 開始位置は画像の高さとマージンから求めるべき
      # indent(-80, 0) do # outdent_section を使っても開始位置がページマージンまで戻らない
      indent(-40, 0) do # outdent_section を使っても開始位置がページマージンまで戻らない
        convert ::Asciidoctor::Block.new(node, :image,
                  content_model: :empty,
                  attributes: {
                    'target' => image_path, 'pdfwidth' => '20mm', 'align' => 'left'
                  },
                  pinned: true)
      end
      move_cursor_to title_start_cursor # 開始位置を復元

      move_down 30
      sectnum = node.sectnum
      # warn title
      if sectnum
        # 第0章とかはダミーに替える（章タイトルの位置揃えのため文字列としては残す）
        sectnum = '　' unless title.match(/^#{sectnum}/)
        title = title.gsub(DropAnchorRx, '').gsub("\u0000", '')
        outdent_section do
          theme_font :chapter do
            ink_prose sectnum, opts
          end
        end
        title.sub!(/#{sectnum}/, '')
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
      start_cursor = cursor
      start_page_number = page_number
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
        if h_category && @theme[%(#{h_category}_border_width)] && (@theme[%(#{h_category}_border_color)] || @theme.base_border_color)
          start_cursor = bounds.top unless page_number == start_page_number
          float do
            bounding_box [bounds.left, start_cursor], width: bounds.width, height: start_cursor - cursor do
              theme_fill_and_stroke_bounds h_category
            end
          end
        end
      end
      margin_bottom bot_margin

      # 章タイトルの後にくる章の本文も含めて改ページしたいときはここで改ページ
      # 各々の節の前で改ページするのとはチョット違う
      # start_new_page
    end

    # 奥付（colophon）は、記法は章と同じでも体裁は章とは異なる
    def ink_heading_colophon(_node, title, _opts = {})
      # warn 'ink_heading_colophon'
      sep = ':'
      main, _, subtitle = title.rpartition sep
      move_down 550  # 奥付にちょうといい位置まで下げる
      color = @theme['heading_h3_font_color'] # h3のフォントの色
      style = :normal # @theme['heading_h3_font_style'] # h3のフォントのスタイル
      outdent_section do
        ink_heading main, size: @theme.base_font_size * 1.4, style: style, color: color
        move_up 15
        ink_heading subtitle, size: @theme.base_font_size * 1.2, style: style, color: color
        stroke_horizontal_rule @font_color, line_width: 0.5 # , left_projection: @theme['section_indent'][0]
        move_down cursor * 0.03
      end
    end

    # 参考文献（bibliography）、索引（index）
    def ink_heading_bibs(_node, title, opts = {})
      # warn 'ink_heading_bibs'
      # outdent_section :outdent do
        opts[:align] = :left
        ink_heading title, opts
      # end
    end

    # 章タイトルの下に下線を引く（自前でやれないようなink_heading_xxx用）
    def ink_heading_border(_node, _titile, opts = {})
      # warn 'ink_heading_border'
      # warn opts
      # warn bounds.width, (bounds.top - cursor)
      h_category = %(heading_h#{opts[:level]})
      # テーマに設定がなければ実行しない
      return unless h_category &&
                    @theme[%(#{h_category}_border_width)] &&
                    (@theme[%(#{h_category}_border_color)] || @theme.base_border_color)

      start_cursor = bounds.top # unless page_number == start_page_number
      outdent_section opts.delete :outdent do
        float do
          bounding_box [bounds.left, start_cursor], width: bounds.width, height: start_cursor - cursor do
            theme_fill_and_stroke_bounds h_category
          end
        end
      end
    end

    # （節の前の）章レベルの本文が始まるまでの行間をとる
    def ink_heading_margin_bottom(_node, _titile, opts = {})
      # warn 'ink_heading_margin_bottom'
      h_category = %(heading_h#{opts[:level]})
      bot_margin = (h_category ? @theme[%(#{h_category}_margin_bottom)] : nil) || @theme.heading_margin_bottom || 40
      margin_bottom bot_margin
    end
  end
end
