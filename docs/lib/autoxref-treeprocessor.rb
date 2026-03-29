# frozen_string_literal: true

# autoxref-treeprocessor.rb: Automatic cross-reference generator.
# original version Copyright (c) 2016 Takahiro Yoshimura <altakey@gmail.com>
# All rights reserved.
# A treeprocessor that allows refering sections and titled
# images/listings/tables with their reference number (e.g. Figure
# <chapter number>.1, <chapter number>.2, ... for images).

require 'asciidoctor/extensions'

include Asciidoctor

Extensions.register do
  treeprocessor AutoXrefTreeprocessor
end

class AutoXrefTreeprocessor < Extensions::Treeprocessor
  def process(document)
    # The initial value of the chapter counter.
    initial_chapter = attr_of(document, 'autoxref-chapter') { 1 }

    # The section level we should treat as chapters.
    chapter_section_level = (document.attr 'autoxref-chaptersectlevel', 2).to_i

    # Captions should we use.
    captions = {
      chapter: (document.attr 'autoxref-chapcaption', 'Chapter %s'),
      section: (document.attr 'autoxref-sectcaption', 'Section %s.%d'),
      image: (document.attr 'autoxref-imagecaption', 'Figure %s.%d'),
      listing: (document.attr 'autoxref-listingcaption', 'Listing %s.%d'),
      table: (document.attr 'autoxref-tablecaption', 'Table %s.%d'),
      example: (document.attr 'autoxref-examplecaption', 'Example %s.%d'),
      sidebar: (document.attr 'autoxref-sidebarcaption', 'Sidebar %s'),
      video: (document.attr 'autoxref-videocaption', 'Video %s.%d'),
      audio: (document.attr 'autoxref-audiocaption', 'Audio %s.%d')
    }

    # Reference number counter.  Reference numbers are reset by chapters.
    counter = {
      chapter: initial_chapter, section: 1, image: 1,
      listing: 1, table: 1, example: 1, sidebar: 1,
      video: 1, audio: 1
    }

    document.find_by(context: :section) do |chapter|
      next unless chapter.level == chapter_section_level - 1

      # chap_num = chapter.sectnum_org.to_i # 編集後のchapterの番号（これだと付録がだめ）
      chap_num_str = chapter.sectnum_org.chop # 編集後のchapterの番号（1, 2, 3, ... A, B, ...）
      chap = attr_of(chapter, 'autoxref-chapter') { get_and_tally_counter_of(:chapter, counter) }
      # warn "== chapter: #{chapter.title}, chap: #{chap}, chap_num_str: #{chap_num_str}, level: #{chapter.level}"

      # chapterが変わったときは、sidebar（コラム）以外のリストや図の通番を1にリセットする
      counter.update({ section: 1, image: 1, listing: 1,
                       table: 1, example: 1, video: 1, audio: 1 })

      # 当面、本文の節や項は、1.2節など「節」はつけない（参照する側はいる・いらないがありそう）
      # %i[section image listing table example sidebar video audio].each do |type|

      # chapterの中の画像やリスト等について、採番対象の要素を見つけて採番する
      %i[image listing table example sidebar video audio].each do |type|
        chapter.find_by(context: type).each do |el|

          # キャプションがついている要素だけ採番する
          next unless el.title

          next if el.level < chapter_section_level

          # warn "el.attributes: #{el.attributes}]"
          # [.nocaption] のときは、採番しない。
          next if el.attributes.key?('role') && el.attributes['role'].include?('nocaption')

          values = [chap_num_str, get_and_tally_counter_of(type, counter)]

          # 書式の取得（書き換えるので複製している）
          fmt = captions[type].dup
          # 付録等のために、書式の指定が %d になっていても、%sでいく
          fmt.gsub!("%d", '%s')
          # warn type.class, fmt, values
          if type == :sidebar
            # コラム（sidebar）だけは全体の通番だけで章をつけないので
            refid = fmt % values[1]
          else
            refid = fmt % values
          end
          # warn refid
          el.attributes['caption'] = refid # replaced_caption
          document.references[:ids][el.attributes['id']] = refid
          # warn el.caption, refid
          el.caption = "#{refid} "
        end
      end
    end
  end

  # Gets and increments the value for the given type in the given
  # counter.
  def get_and_tally_counter_of(type, counter)
    t = counter[type]
    counter[type] = counter[type] + 1
    t
  end

  # Retrieves the associated value for the given key.
  # Lazily retrieve default value if no attr is set on the given key.
  def attr_of(target, key, &default)
    (target.attr key, :none).to_i
  rescue NoMethodError
    if default.nil?
      0
    else
      default.call
    end
  end
end
