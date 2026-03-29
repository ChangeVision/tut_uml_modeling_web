# frozen_string_literal: true

module Asciidoctor
  class CustomTocHtml5Converter < (Asciidoctor::Converter.for 'html5')
    register_for 'html5'

    register_for 'custom_toc_html5'

    def convert_outline(node, opts = {})
      # warn 'Converting a toc outline...'
      return unless node.sections?
      sectnumlevels = opts[:sectnumlevels] || (node.document.attributes['sectnumlevels'] || 3).to_i
      toclevels = opts[:toclevels] || (node.document.attributes['toclevels'] || 2).to_i
      # warn sections = node.sections

      # FIXME top level is incorrect if a multipart book starts with a special section defined at level 0
      result = [%(<ul class="sectlevel#{sections[0].level}">)]
      sections.each do |section|
        slevel = section.level
        next if section.sectname == 'colophon' # 奥付は目次に出力しない
        next if section.sectname == 'index' # 索引は目次に出力しない

        if section.caption
          stitle = section.captioned_title
        elsif section.numbered && slevel <= sectnumlevels
          if slevel < 2 && node.document.doctype == 'book'
            case section.sectname
            when 'chapter'
              stitle =  %(#{(signifier = node.document.attributes['chapter-signifier']) ? "#{signifier} " : ''}#{section.sectnum} #{section.title})
            when 'part'
              stitle =  %(#{(signifier = node.document.attributes['part-signifier']) ? "#{signifier} " : ''}#{section.sectnum nil, ':'} #{section.title})
            else
              stitle = %(#{section.sectnum} #{section.title})
            end
          else
            stitle = %(#{section.sectnum} #{section.title})
          end
        else
          stitle = section.title
        end
        stitle = stitle.gsub DropAnchorRx, '' if stitle.include? '<a'
        if slevel < toclevels && (child_toc_level = convert_outline section, toclevels: toclevels, sectnumlevels: sectnumlevels)
          result << %(<li><a href="##{section.id}">#{stitle}</a>)
          result << child_toc_level
          result << '</li>'
        else
          result << %(<li><a href="##{section.id}">#{stitle}</a></li>)
        end
      end
      result << '</ul>'
      result.join LF
    end
  end
end
