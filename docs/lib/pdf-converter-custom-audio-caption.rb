# frozen_string_literal: false

class CustomAudioCaptionPDFConverter < (Asciidoctor::Converter.for 'pdf')
  register_for 'pdf'

  def convert_audio node
    # warn 'Converting audio node...'
    node.title = %(#{node.caption} #{node.title})
    ink_caption node, labeled: false, end: :top if node.title?
    add_dest_for_block node if node.id
    audio_path = node.media_uri node.attr 'target'
    play_symbol = (node.document.attr? 'icons', 'font') ? %(<font name="fas">#{(icon_font_data 'fas').unicode 'play'}</font>) : RightPointer
    ink_prose %(#{play_symbol}#{NoBreakSpace}<a href="#{audio_path}">#{audio_path}</a> <em>(audio)</em>), normalize: false, margin: 0
    theme_margin :block, :bottom, (next_enclosed_block node)
    # super
  end

end
