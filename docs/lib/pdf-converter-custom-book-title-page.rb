# frozen_string_literal: true

class PDFConverterCustomTitlePage < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def ink_title_page doc
    # タイトルページに出力する画像のファイル名（頑張ってtitle-logo-imageを参照してもよいだろう）
    # target_image_file = '../../images/ill_4c.jpg'
    target_image_file = @theme.title_page_logo_image || 'title-page-logo-image not found'
    title_text_align_str = @theme.title_page_text_align || @base_text_align # テーマの設定を反映
    # title_text_align_str = 'center' # このライブラリで設定したいなたらこっち
    title_text_align = title_text_align_str.to_sym
    move_cursor_to page_height * 0.75
    theme_font :title_page do
      # ボーダーの出力
      # stroke_horizontal_rule '2967B2', line_width: 1.5, line_style: :double
      # タイトルの出力
      move_down 10
      doctitle = doc.doctitle partition: true

      # 半角スペースがあったら分割する（長いタイトルを適当に折り返すための苦肉の回避策）
      doctitle.main.split.each do |title|
      theme_font :title_page_title do
        indent(-30, -30) do # 長いと折り返されるので（長すぎるとはみ出すかも）
          ink_prose title, align: title_text_align, color: theme.base_font_color, line_height: 1, margin: 0
        end
      end
      end
      # サブタイトルの出力
      if (subtitle = doctitle.subtitle)
        theme_font :title_page_subtitle do
          move_down 10
          ink_prose subtitle, align: title_text_align, margin: 0
          move_down 10
        end
      end
      # ボーダーの出力
      # stroke_horizontal_rule '2967B2', line_width: 1.5, line_style: :double
      # タイトルイメージの出力
      move_cursor_to page_height * 0.5
      convert ::Asciidoctor::Block.new doc, :image,
        content_model: :empty,
        attributes: { 'target' => target_image_file, 'pdfwidth' => '50mm', 'align' => title_text_align_str },
        pinned: true
      # authorsの出力
      if @theme.title_page_authors_display != 'none' && (doc.attr? 'authors')
        move_cursor_to page_height * 0.2
        # move_down @theme.title_page_authors_margin_top || 0 # テーマの設定を反映したい場合はこれ
        # move_down 40
        # テーマでtitle_page_authors_margin_left,rightを反映したいばあいはこれ
        # indent(@theme.title_page_authors_margin_left || 0), (@theme.title_page_authors_margin_right || 0) do
        indent(0, 0) do # 左右インデントはなし
          # authorsのmailとURLがあれば反映する（はずだが、試していない）
          generic_authors_content = @theme.title_page_authors_content
          authors_content = {
            name_only: @theme.title_page_authors_content_name_only || generic_authors_content,
            with_email: @theme.title_page_authors_content_with_email || generic_authors_content,
            with_url: @theme.title_page_authors_content_with_url || generic_authors_content,
          }
          authors = doc.authors.map.with_index do |author, idx|
            with_author doc, author, idx == 0 do
              author_content_key = (url = doc.attr 'url') ? ((url.start_with? 'mailto:') ? :with_email : :with_url) : :name_only
              if (author_content = authors_content[author_content_key])
                apply_subs_discretely doc, author_content, drop_lines_with_unresolved_attributes: true, imagesdir: @themesdir
              else
                doc.attr 'author'
              end
            end
          end.join @theme.title_page_authors_delimiter
          # 実際にauthorsを出力するところ
          theme_font :title_page_authors do
            ink_prose authors, align: title_text_align, margin: 0, normalize: true
          end
        end
        move_down @theme.title_page_authors_margin_bottom || 0
      end
      # revisionの出力
      unless @theme.title_page_revision_display == 'none' || (revision_info = [(doc.attr? 'revnumber') ? %(#{doc.attr 'version-label'} #{doc.attr 'revnumber'}) : nil, (doc.attr 'revdate')].compact).empty?
        # move_down @theme.title_page_revision_margin_top || 0 # テーマの設定を反映したい場合はこれ
        move_down 10
        revision_text = revision_info.join @theme.title_page_revision_delimiter
        if (revremark = doc.attr 'revremark')
          revision_text = %(#{revision_text}: #{revremark})
        end
        indent (@theme.title_page_revision_margin_left || 0), (@theme.title_page_revision_margin_right || 0) do
          theme_font :title_page_revision do
            ink_prose revision_text, align: title_text_align, margin: 0, normalize: false
          end
        end
        move_down @theme.title_page_revision_margin_bottom || 0
      end
    end
  end
end
