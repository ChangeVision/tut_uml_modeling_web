# frozen_string_literal: true

require 'asciidoctor/converter/html5'

module Asciidoctor
class CustomVideoAudioCaptionHtml5Converter < (Asciidoctor::Converter.for 'html5')
  register_for 'html5'

  register_for 'video_audio_caption_html5'

  def convert_video(node)
    # warn 'Converting a video node...'
    node.title = %(#{node.caption} #{node.title})
    super
  end

  def convert_audio(node)
    # warn 'Converting a audio node...'
    node.title = %(#{node.caption} #{node.title})
    super
  end
end
end
