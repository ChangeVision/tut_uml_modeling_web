# frozen_string_literal: false

class PDFConverterCustomAdmonition < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_admonition(node)
    # warn "convert_admonition: #{node}"
    type = node.attr 'name'
    label_text_align = @theme.admonition_label_text_align&.to_sym || :left
    # if (label_valign = @theme.admonition_label_vertical_align&.to_sym || :middle) == :middle
    #   label_valign = :center
    # end
    label_valign = :top
    label_width = 50.0
    label_height = 12.0
    icons = true
    cpad = expand_padding_value @theme.admonition_padding
    lpad = (lpad = @theme.admonition_label_padding) ? (expand_padding_value lpad) : cpad
    if (doc = node.document).attr? 'icons'
       # warn "has icons"
      if !(has_icon = node.attr? 'icon') && (doc.attr 'icons') == 'font'
        icons = 'font'
        icon_data = admonition_icon_data type.to_sym
        icon_size = icon_data[:size] || 24
        # label_width = label_min_width || (icon_size * 1.5)
        # warn "#{icons}, #{icon_data}, #{icon_size}"
      elsif (icon_path = has_icon || !(icon_path = (@theme[%(admonition_icon_#{type})] || {})[:image]) ?
                           (get_icon_image_path node, type) :
                           (ThemeLoader.resolve_theme_asset (apply_subs_discretely doc, icon_path, subs: [:attributes], imagesdir: @themesdir), @themesdir)) &&
            (::File.readable? icon_path)
        icons = true
      else
        log :warn, %(admonition icon image#{has_icon ? '' : ' for ' + type.upcase} not found or not readable: #{icon_path || (get_icon_image_path node, type, false)})
      end
    end

    arrange_block node do |extent|
      add_dest_for_block node if node.id
      theme_fill_and_stroke_block :admonition, extent if extent
      # pad_box [0, cpad[1], 0, lpad[3]] do
      pad_box [0, cpad[1], 0, 0] do
        # warn "cpad[1] #{cpad[1]}, lpad[3] #{lpad[3]} icon_path: #{icon_path}"
        if extent
          # label_height = extent.single_page_height || cursor
          float do
            adjusted_font_size = nil
            bounding_box [bounds.left, cursor], width: label_width, height: label_height do
              if icons
                if (::Asciidoctor::Image.format icon_path) == 'svg'
                  begin
                    # warn "position: #{label_text_align}, vposition: #{label_valign}, width: #{label_width}, height: #{label_height}"
                    svg_obj = ::Prawn::SVG::Interface.new (::File.read icon_path, mode: 'r:UTF-8'), self,
                                                          position: label_text_align,
                                                          vposition: label_valign,
                                                          width: label_width,
                                                          height: label_height,
                                                          fallback_font_name: fallback_svg_font_name,
                                                          enable_web_requests: allow_uri_read ? (method :load_open_uri).to_proc : false,
                                                          enable_file_requests_with_root: { base: (::File.dirname icon_path), root: @jail_dir },
                                                          cache_images: cache_uri
                    svg_obj.resize height: label_height if svg_obj.document.sizing.output_height > label_height
                    svg_obj.draw
                    svg_obj.document.warnings.each do |icon_warning|
                      log :warn, %(problem encountered in image: #{icon_path}; #{icon_warning})
                    end unless scratch?
                  rescue
                    log :warn, %(could not embed admonition icon image: #{icon_path}; #{$!.message})
                    icons = nil
                  end
                end
              end
            end
          end
        end
        # pad_box [cpad[0], 0, cpad[2], label_width + lpad[1] + cpad[3]], node do
        pad_box [cpad[0] + label_height, 0, cpad[2], cpad[3]], node do
          ink_caption node, category: :admonition, labeled: false if node.title?
          theme_font :admonition do
            traverse node
          end
        end
      end
    end
    theme_margin :block, :bottom, (next_enclosed_block node)
  end
end
